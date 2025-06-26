// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {TokenStore} from "./TokenStore.sol";
import {AttributionHook} from "./hooks/AttributionHook.sol";

/// @title Flywheel
///
/// @notice Main contract for managing advertising campaigns and attribution
///
/// @dev Handles campaign lifecycle, attribution, and token distribution
contract Flywheel {
    /// @notice Possible states a campaign can be in
    enum CampaignStatus {
        NONE, // Campaign does not exist
        CREATED, // Initial state when campaign is first created
        READY, // Advertiser signals that campaign is ready for attributor to open
        OPEN, // Campaign is live and can accept attribution
        PAUSED, // Campaign is temporarily paused
        CLOSED, // Campaign is no longer live but can still accept lagging attribution
        FINALIZED // Campaign attribution is complete

    }

    /// @notice Campaign information structure
    ///
    /// @param status Current status of the campaign
    /// @param advertiser Address of the campaign advertiser
    /// @param attributor Address of the attribution provider
    /// @param hook Address of the attribution hook contract
    /// @param attributionDeadline Timestamp after which no more attribution can occur (set on close)
    struct CampaignInfo {
        CampaignStatus status;
        address advertiser;
        address attributor;
        address hook;
        uint48 attributionDeadline; // set on close
    }

    /// @notice Payout structure for attribution rewards
    ///
    /// @param recipient Address receiving the payout
    /// @param amount Amount of tokens to be paid out
    struct Payout {
        address recipient;
        uint256 amount;
    }

    /// @notice Maximum fee basis points (100%)
    uint16 public constant MAX_FEE_BPS = 10_000; // 100%

    /// @notice Buffer time after campaign close before finalization is allowed
    uint256 public constant FINALIZATION_BUFFER = 7 days;

    /// @notice Protocol fee in basis points
    uint16 public immutable protocolFeeBps;

    /// @notice Address that receives protocol fees
    address public immutable protocolFeeRecipient;

    /// @notice Implementation address for TokenStore contracts
    address public immutable tokenStoreImpl;

    /// @notice Mapping from campaign address to campaign information
    mapping(address campaign => CampaignInfo) public campaigns;

    /// @notice Mapping from token address to recipient address to balance amount
    mapping(address token => mapping(address recipient => uint256 balance)) public balances;

    /// @notice Emitted when a new campaign is created
    ///
    /// @param campaign Address of the created campaign
    /// @param advertiser Address of the campaign advertiser
    /// @param attributor Address of the attribution provider
    /// @param hook Address of the attribution hook contract
    event CampaignCreated(address indexed campaign, address advertiser, address attributor, address hook);

    /// @notice Emitted when a campaign status is updated
    ///
    /// @param campaign Address of the campaign
    /// @param sender Address that triggered the status change
    /// @param oldStatus Previous status of the campaign
    /// @param newStatus New status of the campaign
    event CampaignStatusUpdated(
        address indexed campaign, address sender, CampaignStatus oldStatus, CampaignStatus newStatus
    );

    /// @notice Emitted when a payout is attributed to a recipient

    /// @param campaign Address of the campaign
    /// @param recipient Address receiving the payout
    /// @param token Address of the payout token
    /// @param amount Amount of tokens attributed
    event PayoutAttributed(address indexed campaign, address token, address recipient, uint256 amount);

    /// @notice Emitted when accumulated balance is distributed to a recipient
    ///
    /// @param recipient Address receiving the distribution
    /// @param token Address of the distributed token
    /// @param amount Amount of tokens distributed
    event PayoutDistributed(address indexed token, address recipient, uint256 amount);

    /// @notice Emitted when advertiser withdraws remaining tokens from a finalized campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the withdrawn token
    /// @param amount Amount of tokens withdrawn
    event RemainderWithdrawn(address indexed campaign, address token, uint256 amount);

    /// @notice Thrown when protocol fee is set to maximum or higher
    error ZeroProtocolFee();

    /// @notice Thrown when protocol fee recipient address is zero
    error ZeroProtocolFeeRecipient();

    /// @notice Thrown when caller doesn't have required permissions
    error Unauthorized();

    /// @notice Thrown when campaign is in invalid status for operation
    error InvalidCampaignStatus();

    /// @notice Constructor for the Flywheel contract
    ///
    /// @param protocolFeeBps_ Protocol fee in basis points (must be less than MAX_FEE_BPS)
    /// @param protocolFeeRecipient_ Address that will receive protocol fees
    ///
    /// @dev Deploys a new TokenStore implementation for cloning
    constructor(uint16 protocolFeeBps_, address protocolFeeRecipient_) {
        if (protocolFeeBps_ >= MAX_FEE_BPS) revert ZeroProtocolFee();
        if (protocolFeeRecipient_ == address(0)) revert ZeroProtocolFeeRecipient();

        protocolFeeBps = protocolFeeBps_;
        protocolFeeRecipient = protocolFeeRecipient_;
        tokenStoreImpl = address(new TokenStore());
    }

    /// @notice Creates a new campaign
    ///
    /// @param attributor Address of the attribution provider
    /// @param hook Address of the attribution hook contract
    /// @param initData Initialization data for the hook
    ///
    /// @return campaign Address of the newly created campaign
    ///
    /// @dev Clones a new TokenStore contract for the campaign
    function createCampaign(address attributor, address hook, bytes calldata initData)
        external
        returns (address campaign)
    {
        campaign = Clones.clone(tokenStoreImpl);
        campaigns[campaign] = CampaignInfo({
            status: CampaignStatus.CREATED,
            advertiser: msg.sender,
            attributor: attributor,
            hook: hook,
            attributionDeadline: 0
        });
        emit CampaignCreated(campaign, msg.sender, attributor, hook);
        AttributionHook(hook).createCampaign(campaign, initData);
    }

    /// @notice Opens a campaign for attribution
    ///
    /// @param campaign Address of the campaign to open
    ///
    /// @dev Only advertiser can move from CREATED to READY, only attributor can move from READY to OPEN
    function openCampaign(address campaign) external {
        CampaignStatus oldStatus = campaigns[campaign].status;
        CampaignStatus newStatus;
        if (_isAdvertiser(campaign) && oldStatus == CampaignStatus.CREATED) {
            newStatus = CampaignStatus.READY;
        } else if (_isAttributor(campaign) && oldStatus == CampaignStatus.READY) {
            newStatus = CampaignStatus.OPEN;
        } else {
            revert InvalidCampaignStatus();
        }
        campaigns[campaign].status = newStatus;
        emit CampaignStatusUpdated(campaign, msg.sender, oldStatus, newStatus);
    }

    /// @notice Pauses an open campaign
    ///
    /// @param campaign Address of the campaign to pause
    ///
    /// @dev Only advertiser or attributor can pause an OPEN campaign
    function pauseCampaign(address campaign) external {
        if (!(_isAdvertiser(campaign) || _isAttributor(campaign))) revert Unauthorized();
        if (campaigns[campaign].status != CampaignStatus.OPEN) revert InvalidCampaignStatus();
        campaigns[campaign].status = CampaignStatus.PAUSED;
        emit CampaignStatusUpdated(campaign, msg.sender, CampaignStatus.OPEN, CampaignStatus.PAUSED);
    }

    /// @notice Unpauses a paused campaign
    ///
    /// @param campaign Address of the campaign to unpause
    ///
    /// @dev Only advertiser or attributor can unpause a PAUSED campaign
    function unpauseCampaign(address campaign) external {
        if (!(_isAdvertiser(campaign) || _isAttributor(campaign))) revert Unauthorized();
        if (campaigns[campaign].status != CampaignStatus.PAUSED) revert InvalidCampaignStatus();
        campaigns[campaign].status = CampaignStatus.OPEN;
        emit CampaignStatusUpdated(campaign, msg.sender, CampaignStatus.PAUSED, CampaignStatus.OPEN);
    }

    /// @notice Closes a campaign and sets attribution deadline
    ///
    /// @param campaign Address of the campaign to close
    ///
    /// @dev Only advertiser can close a READY, OPEN, or PAUSED campaign
    function closeCampaign(address campaign) external {
        if (!_isAdvertiser(campaign)) revert Unauthorized();
        CampaignStatus status = campaigns[campaign].status;
        if (status != CampaignStatus.READY && status != CampaignStatus.OPEN && status != CampaignStatus.PAUSED) {
            revert InvalidCampaignStatus();
        }
        campaigns[campaign].status = CampaignStatus.CLOSED;
        campaigns[campaign].attributionDeadline = uint48(block.timestamp + FINALIZATION_BUFFER);
        emit CampaignStatusUpdated(campaign, msg.sender, status, CampaignStatus.CLOSED);
    }

    /// @notice Finalizes a campaign
    ///
    /// @param campaign Address of the campaign to finalize
    ///
    /// @dev Advertiser can finalize CREATED, READY, or CLOSED campaigns after deadline. Attributor can finalize any non-FINALIZED campaign.
    function finalizeCampaign(address campaign) external {
        CampaignStatus oldStatus = campaigns[campaign].status;
        if (_isAdvertiser(campaign)) {
            bool attributionDeadlinePassed = block.timestamp > campaigns[campaign].attributionDeadline;
            if (
                oldStatus != CampaignStatus.CREATED && oldStatus != CampaignStatus.READY
                    && !(oldStatus == CampaignStatus.CLOSED && attributionDeadlinePassed)
            ) {
                revert InvalidCampaignStatus();
            }
        } else if (_isAttributor(campaign)) {
            if (oldStatus == CampaignStatus.FINALIZED) revert InvalidCampaignStatus();
        } else {
            revert Unauthorized();
        }
        campaigns[campaign].status = CampaignStatus.FINALIZED;
        emit CampaignStatusUpdated(campaign, msg.sender, oldStatus, CampaignStatus.FINALIZED);
    }

    /// @notice Processes attribution for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param payoutToken Address of the token to be distributed
    /// @param attributionData Encoded attribution data for the hook
    ///
    /// @dev Only attributor can call on OPEN campaigns. Calculates protocol fees and updates balances.
    function attribute(address campaign, address payoutToken, bytes calldata attributionData) external {
        // Check campaign is open
        if (campaigns[campaign].status != CampaignStatus.OPEN) revert InvalidCampaignStatus();

        // Check sender is attributor
        if (!_isAttributor(campaign)) revert Unauthorized();

        Payout[] memory payouts =
            AttributionHook(campaigns[campaign].hook).attribute(campaign, payoutToken, attributionData);

        // Add payouts to balances
        uint256 totalPayouts = 0;
        for (uint256 i = 0; i < payouts.length; i++) {
            address recipient = payouts[i].recipient;
            uint256 amount = payouts[i].amount;
            balances[payoutToken][recipient] += amount;
            totalPayouts += amount;
            emit PayoutAttributed(campaign, payoutToken, recipient, amount);
        }

        // Add protocol fee to balances
        uint256 protocolFee = (totalPayouts * protocolFeeBps) / MAX_FEE_BPS;
        balances[payoutToken][protocolFeeRecipient] += protocolFee;
        emit PayoutAttributed(campaign, payoutToken, protocolFeeRecipient, protocolFee);

        // Transfer tokens to recipient, attributor, and protocol
        TokenStore(campaign).sendTokens(payoutToken, address(this), totalPayouts + protocolFee);
    }

    /// @notice Distributes accumulated balance to a recipient
    ///
    /// @param token Address of the token to distribute
    /// @param recipient Address of the recipient
    ///
    /// @dev Transfers the full balance for the token-recipient pair and resets it to zero
    function distribute(address token, address recipient) external {
        uint256 balance = balances[token][recipient];
        delete balances[token][recipient];
        SafeERC20.safeTransfer(IERC20(token), recipient, balance);
        emit PayoutDistributed(token, recipient, balance);
    }

    /// @notice Allows advertiser to withdraw remaining tokens from a finalized campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the token to withdraw
    ///
    /// @dev Only advertiser can withdraw from FINALIZED campaigns
    function withdraw(address campaign, address token) external {
        // Check sender is advertiser
        if (!_isAdvertiser(campaign)) revert Unauthorized();

        // Check campaign is finalized
        if (campaigns[campaign].status != CampaignStatus.FINALIZED) revert InvalidCampaignStatus();

        // Sweep remaining tokens from campaign to advertiser
        uint256 balance = IERC20(token).balanceOf(campaign);
        TokenStore(campaign).sendTokens(token, msg.sender, balance);
        emit RemainderWithdrawn(campaign, token, balance);
    }

    /// @notice Returns the URI for a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return uri The URI for the campaign
    function campaignURI(address campaign) external view returns (string memory uri) {
        return AttributionHook(campaigns[campaign].hook).campaignURI(campaign);
    }

    /// @notice Checks if the caller is the advertiser of a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return True if caller is the advertiser, false otherwise
    function _isAdvertiser(address campaign) internal view returns (bool) {
        return msg.sender == campaigns[campaign].advertiser;
    }

    /// @notice Checks if the caller is the attributor of a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return True if caller is the attributor, false otherwise
    function _isAttributor(address campaign) internal view returns (bool) {
        return msg.sender == campaigns[campaign].attributor;
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {TokenStore} from "./TokenStore.sol";
import {CampaignHooks} from "./CampaignHooks.sol";

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
        OPEN, // Campaign is live and can accept attribution
        PAUSED, // Campaign is temporarily paused
        CLOSED, // Campaign is no longer live but can still accept lagging attribution
        FINALIZED // Campaign attribution is complete

    }

    /// @notice Campaign information structure
    ///
    /// @param status Current status of the campaign
    /// @param sponsor Address of the campaign sponsor
    /// @param attributor Address of the attribution provider
    /// @param hooks Address of the campaign hooks contract
    /// @param attributionDeadline Timestamp after which no more attribution can occur (set on close)
    struct CampaignInfo {
        CampaignStatus status;
        address sponsor;
        address attributor;
        address hooks;
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

    /// @notice Buffer time after campaign close before finalization is allowed
    uint256 public constant FINALIZATION_BUFFER = 7 days;

    /// @notice Implementation address for TokenStore contracts
    address public immutable tokenStoreImpl;

    /// @notice Mapping from campaign address to campaign information
    mapping(address campaign => CampaignInfo) public campaigns;

    /// @notice Mapping from token address to recipient address to balance amount
    mapping(address token => mapping(address recipient => uint256 balance)) public balances;

    /// @notice Collectible attributor fees
    mapping(address token => mapping(address attributor => uint256 amount)) public fees;

    /// @notice Emitted when a new campaign is created
    ///
    /// @param campaign Address of the created campaign
    /// @param sponsor Address of the campaign sponsor
    /// @param attributor Address of the attribution provider
    /// @param hooks Address of the campaign hooks contract
    event CampaignCreated(address indexed campaign, address sponsor, address attributor, address hooks);

    /// @notice Emitted when a campaign status is updated
    ///
    /// @param campaign Address of the campaign
    /// @param sender Address that triggered the status change
    /// @param oldStatus Previous status of the campaign
    /// @param newStatus New status of the campaign
    event CampaignStatusUpdated(
        address indexed campaign, address sender, CampaignStatus oldStatus, CampaignStatus newStatus
    );

    /// @notice Emitted when a campaign is updated
    ///
    /// @param campaign Address of the campaign
    /// @param uri The URI for the campaign
    event CampaignMetadataUpdated(address indexed campaign, string uri);

    /// @notice Emitted when a payout is attributed to a recipient

    /// @param campaign Address of the campaign
    /// @param recipient Address receiving the payout
    /// @param token Address of the payout token
    /// @param amount Amount of tokens attributed
    event PayoutAllocated(address indexed campaign, address token, address recipient, uint256 amount);

    /// @notice Emitted when a fee is attributed to a recipient
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the payout token
    /// @param attributor Address of the attributor
    /// @param amount Amount of tokens attributed
    event FeeAllocated(address indexed campaign, address token, address attributor, uint256 amount);

    /// @notice Emitted when accumulated balance is distributed to a recipient
    ///
    /// @param recipient Address receiving the distribution
    /// @param token Address of the distributed token
    /// @param amount Amount of tokens distributed
    event PayoutsDistributed(address token, address recipient, uint256 amount);

    /// @notice Emitted when accumulated fees are collected
    ///
    /// @param token Address of the collected token
    /// @param amount Amount of tokens collected
    event FeesCollected(address token, address attributor, uint256 amount);

    /// @notice Emitted when sponsor withdraws remaining tokens from a finalized campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the withdrawn token
    /// @param amount Amount of tokens withdrawn
    event RemainderWithdrawn(address indexed campaign, address token, uint256 amount);

    /// @notice Thrown when caller doesn't have required permissions
    error Unauthorized();

    /// @notice Thrown when campaign is in invalid status for operation
    error InvalidCampaignStatus();

    /// @notice Constructor for the Flywheel contract
    ///
    /// @dev Deploys a new TokenStore implementation for cloning
    constructor() {
        tokenStoreImpl = address(new TokenStore());
    }

    /// @notice Creates a new campaign
    ///
    /// @param attributor Address of the attribution provider
    /// @param hooks Address of the campaign hooks contract
    /// @param initData Initialization data for the hooks
    ///
    /// @return campaign Address of the newly created campaign
    ///
    /// @dev Clones a new TokenStore contract for the campaign
    function createCampaign(address attributor, address hooks, bytes calldata initData)
        external
        returns (address campaign)
    {
        campaign = Clones.clone(tokenStoreImpl);
        campaigns[campaign] = CampaignInfo({
            status: CampaignStatus.CREATED,
            sponsor: msg.sender,
            attributor: attributor,
            hooks: hooks,
            attributionDeadline: 0
        });
        emit CampaignCreated(campaign, msg.sender, attributor, hooks);
        CampaignHooks(hooks).createCampaign(campaign, initData);
    }

    /// @notice Opens a campaign for attribution
    ///
    /// @param campaign Address of the campaign to open
    ///
    /// @dev Only attributor can move from CREATED to OPEN
    function openCampaign(address campaign) external {
        if (!_isAttributor(campaign)) revert Unauthorized();
        if (campaigns[campaign].status != CampaignStatus.CREATED) revert InvalidCampaignStatus();
        campaigns[campaign].status = CampaignStatus.OPEN;
        emit CampaignStatusUpdated(campaign, msg.sender, CampaignStatus.CREATED, CampaignStatus.OPEN);
    }

    /// @notice Pauses an open campaign
    ///
    /// @param campaign Address of the campaign to pause
    ///
    /// @dev Only sponsor or attributor can pause an OPEN campaign
    function pauseCampaign(address campaign) external {
        if (!(_isSponsor(campaign) || _isAttributor(campaign))) revert Unauthorized();
        if (campaigns[campaign].status != CampaignStatus.OPEN) revert InvalidCampaignStatus();
        campaigns[campaign].status = CampaignStatus.PAUSED;
        emit CampaignStatusUpdated(campaign, msg.sender, CampaignStatus.OPEN, CampaignStatus.PAUSED);
    }

    /// @notice Unpauses a paused campaign
    ///
    /// @param campaign Address of the campaign to unpause
    ///
    /// @dev Only sponsor or attributor can unpause a PAUSED campaign
    function unpauseCampaign(address campaign) external {
        if (!(_isSponsor(campaign) || _isAttributor(campaign))) revert Unauthorized();
        if (campaigns[campaign].status != CampaignStatus.PAUSED) revert InvalidCampaignStatus();
        campaigns[campaign].status = CampaignStatus.OPEN;
        emit CampaignStatusUpdated(campaign, msg.sender, CampaignStatus.PAUSED, CampaignStatus.OPEN);
    }

    /// @notice Closes a campaign and sets attribution deadline
    ///
    /// @param campaign Address of the campaign to close
    ///
    /// @dev Only sponsor can close a OPEN or PAUSED campaign
    function closeCampaign(address campaign) external {
        if (!_isSponsor(campaign)) revert Unauthorized();
        CampaignStatus status = campaigns[campaign].status;
        if (status != CampaignStatus.OPEN && status != CampaignStatus.PAUSED) revert InvalidCampaignStatus();
        campaigns[campaign].status = CampaignStatus.CLOSED;
        campaigns[campaign].attributionDeadline = uint48(block.timestamp + FINALIZATION_BUFFER);
        emit CampaignStatusUpdated(campaign, msg.sender, status, CampaignStatus.CLOSED);
    }

    /// @notice Finalizes a campaign
    ///
    /// @param campaign Address of the campaign to finalize
    ///
    /// @dev Sponsor can finalize CREATED or CLOSED campaigns after deadline. Attributor can finalize any non-FINALIZED campaign.
    function finalizeCampaign(address campaign) external {
        CampaignStatus oldStatus = campaigns[campaign].status;
        if (_isSponsor(campaign)) {
            bool attributionDeadlinePassed = block.timestamp > campaigns[campaign].attributionDeadline;
            if (
                oldStatus != CampaignStatus.CREATED
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

    /// @notice Updates the metadata for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param data The data for the campaign
    ///
    /// @dev Only callable by the sponsor of a FINALIZED campaign
    /// @dev Indexers should update their metadata cache for this campaign by fetching the campaignURI
    function updateMetadata(address campaign, bytes calldata data) external {
        if (campaigns[campaign].status != CampaignStatus.FINALIZED) revert InvalidCampaignStatus();
        CampaignHooks(campaigns[campaign].hooks).updateMetadata(msg.sender, campaign, data);
        emit CampaignMetadataUpdated(campaign, campaignURI(campaign));
    }

    /// @notice Processes attribution for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param payoutToken Address of the token to be distributed
    /// @param attributionData Encoded attribution data for the hooks
    ///
    /// @dev Only attributor can call on OPEN, PAUSED, or CLOSED campaigns. Calculates protocol fees and updates balances.
    function attribute(address campaign, address payoutToken, bytes calldata attributionData) external {
        // Check campaign allows attribution (OPEN, PAUSED, or CLOSED)
        CampaignStatus status = campaigns[campaign].status;
        if (status != CampaignStatus.OPEN && status != CampaignStatus.PAUSED && status != CampaignStatus.CLOSED) {
            revert InvalidCampaignStatus();
        }

        // Check sender is attributor
        address attributor = campaigns[campaign].attributor;
        if (msg.sender != attributor) revert Unauthorized();

        (Payout[] memory payouts, uint256 attributionFee) =
            CampaignHooks(campaigns[campaign].hooks).attribute(campaign, attributor, payoutToken, attributionData);

        // Add payouts to balances
        uint256 totalPayouts = 0;
        for (uint256 i = 0; i < payouts.length; i++) {
            address recipient = payouts[i].recipient;
            uint256 amount = payouts[i].amount;
            balances[payoutToken][recipient] += amount;
            totalPayouts += amount;
            emit PayoutAllocated(campaign, payoutToken, recipient, amount);
        }

        // Add attributor fee to balances
        fees[payoutToken][attributor] += attributionFee;
        emit FeeAllocated(campaign, payoutToken, attributor, attributionFee);

        // Transfer tokens to flywheel to reserve for payouts and fees
        TokenStore(campaign).sendTokens(payoutToken, address(this), totalPayouts + attributionFee);
    }

    /// @notice Distributes accumulated balance to a recipient
    ///
    /// @param token Address of the token to distribute
    /// @param recipient Address of the recipient
    ///
    /// @dev Transfers the full balance for the token-recipient pair and resets it to zero
    function distributePayouts(address token, address recipient) external {
        uint256 balance = balances[token][recipient];
        delete balances[token][recipient];
        SafeERC20.safeTransfer(IERC20(token), recipient, balance);
        emit PayoutsDistributed(token, recipient, balance);
    }

    /// @notice Collects fees from a campaign
    ///
    /// @param token Address of the token to collect fees from
    /// @param recipient Address of the recipient to collect fees to
    ///
    /// @dev Only attributor can collect fees
    function collectFees(address token, address recipient) external {
        address attributor = msg.sender;
        uint256 amount = fees[token][attributor];
        delete fees[token][attributor];
        SafeERC20.safeTransfer(IERC20(token), recipient, amount);
        emit FeesCollected(token, attributor, amount);
    }

    /// @notice Allows sponsor to withdraw remaining tokens from a finalized campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the token to withdraw
    ///
    /// @dev Only sponsor can withdraw from FINALIZED campaigns
    function withdrawRemainder(address campaign, address token) external {
        // Check sender is sponsor
        if (!_isSponsor(campaign)) revert Unauthorized();

        // Check campaign is finalized
        if (campaigns[campaign].status != CampaignStatus.FINALIZED) revert InvalidCampaignStatus();

        // Sweep remaining tokens from campaign to sponsor
        uint256 balance = IERC20(token).balanceOf(campaign);
        TokenStore(campaign).sendTokens(token, msg.sender, balance);
        emit RemainderWithdrawn(campaign, token, balance);
    }

    /// @notice Returns the URI for a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return uri The URI for the campaign
    function campaignURI(address campaign) public view returns (string memory uri) {
        return CampaignHooks(campaigns[campaign].hooks).campaignURI(campaign);
    }

    /// @notice Returns the provider of a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return attributor The attributor of the campaign
    function campaignAttributor(address campaign) public view returns (address) {
        return campaigns[campaign].attributor;
    }

    /// @notice Checks if the caller is the sponsor of a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return True if caller is the sponsor, false otherwise
    function _isSponsor(address campaign) internal view returns (bool) {
        return msg.sender == campaigns[campaign].sponsor;
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

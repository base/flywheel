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
    /// @param hook Address of the attribution hook contract
    /// @param attributionDeadline Timestamp after which no more attribution can occur (set on close)
    struct CampaignInfo {
        CampaignStatus status;
        address sponsor;
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
    /// @param hook Address of the attribution hook contract
    event CampaignCreated(address indexed campaign, address sponsor, address attributor, address hook);

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
            sponsor: msg.sender,
            attributor: attributor,
            hook: hook,
            attributionDeadline: 0
        });
        emit CampaignCreated(campaign, msg.sender, attributor, hook);
        AttributionHook(hook).createCampaign(campaign, initData);
    }

    /// @notice Updates the status of a campaign
    ///
    /// @param campaign Address of the campaign to update
    /// @param newStatus New status to set for the campaign
    ///
    /// @dev Status transitions are strictly controlled based on current status and caller role
    function updateCampaignStatus(address campaign, CampaignStatus newStatus) external {
        bool isSponsor = _isSponsor(campaign);
        bool isAttributor = _isAttributor(campaign);

        if (!isSponsor && !isAttributor) revert Unauthorized();

        CampaignStatus currentStatus = campaigns[campaign].status;

        // Prevent invalid transitions
        if (currentStatus == CampaignStatus.NONE || newStatus == CampaignStatus.NONE || currentStatus == newStatus) {
            revert InvalidCampaignStatus();
        }

        // Validate specific transitions based on roles and current status
        if (newStatus == CampaignStatus.CREATED) {
            // Cannot transition back to CREATED
            revert InvalidCampaignStatus();
        } else if (newStatus == CampaignStatus.OPEN) {
            if (currentStatus == CampaignStatus.CREATED) {
                // Only attributor can open a created campaign
                if (!isAttributor) revert Unauthorized();
            } else if (currentStatus == CampaignStatus.PAUSED) {
                // Both sponsor and attributor can unpause
                // No additional checks needed
            } else {
                revert InvalidCampaignStatus();
            }
        } else if (newStatus == CampaignStatus.PAUSED) {
            // Both sponsor and attributor can pause, only from OPEN
            if (currentStatus != CampaignStatus.OPEN) revert InvalidCampaignStatus();
        } else if (newStatus == CampaignStatus.CLOSED) {
            // Only sponsor can close, from OPEN or PAUSED
            if (!isSponsor) revert Unauthorized();
            if (currentStatus != CampaignStatus.OPEN && currentStatus != CampaignStatus.PAUSED) {
                revert InvalidCampaignStatus();
            }
            // Set attribution deadline when closing
            campaigns[campaign].attributionDeadline =
                uint48(block.timestamp + AttributionHook(campaigns[campaign].hook).finalizationBufferDefault());
        } else if (newStatus == CampaignStatus.FINALIZED) {
            if (isSponsor) {
                // Sponsor can finalize CREATED or CLOSED campaigns (after deadline)
                if (currentStatus == CampaignStatus.CREATED) {
                    // Allow sponsor to finalize created campaigns
                } else if (currentStatus == CampaignStatus.CLOSED) {
                    // Check if attribution deadline has passed
                    if (block.timestamp <= campaigns[campaign].attributionDeadline) {
                        revert InvalidCampaignStatus();
                    }
                } else {
                    revert InvalidCampaignStatus();
                }
            } else if (isAttributor) {
                // Attributor can finalize any campaign except already finalized
                if (currentStatus == CampaignStatus.FINALIZED) {
                    revert InvalidCampaignStatus();
                }
            }
        }

        campaigns[campaign].status = newStatus;
        emit CampaignStatusUpdated(campaign, msg.sender, currentStatus, newStatus);
    }

    /// @notice Processes attribution for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param payoutToken Address of the token to be distributed
    /// @param attributionData Encoded attribution data for the hook
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
            AttributionHook(campaigns[campaign].hook).attribute(campaign, attributor, payoutToken, attributionData);

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
    function campaignURI(address campaign) external view returns (string memory uri) {
        return AttributionHook(campaigns[campaign].hook).campaignURI(campaign);
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

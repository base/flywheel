// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {TokenStore} from "./TokenStore.sol";
import {AttributionHook} from "./hooks/AttributionHook.sol";
import {CampaignHook} from "./hooks/CampaignHook.sol";

/// @title Flywheel
///
/// @notice Main contract for managing advertising campaigns and attribution
///
/// @dev Handles campaign lifecycle, attribution, and token distribution
contract Flywheel {
    /// @notice Campaign information structure
    ///
    /// @param sponsor Address of the campaign sponsor
    /// @param attributor Address of the attribution provider
    /// @param hook Address of the attribution hook contract
    /// @param campaignHook Address of the campaign status hook contract
    struct CampaignInfo {
        address sponsor;
        address attributor;
        address hook;
        address campaignHook;
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
    /// @param campaignHook Address of the campaign status hook contract
    event CampaignCreated(
        address indexed campaign, address sponsor, address attributor, address hook, address campaignHook
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
    /// @param campaignHook Address of the campaign status hook contract
    /// @param initData Initialization data for the hooks
    ///
    /// @return campaign Address of the newly created campaign
    ///
    /// @dev Clones a new TokenStore contract for the campaign
    function createCampaign(address attributor, address hook, address campaignHook, bytes calldata initData)
        external
        returns (address campaign)
    {
        campaign = Clones.clone(tokenStoreImpl);
        campaigns[campaign] =
            CampaignInfo({sponsor: msg.sender, attributor: attributor, hook: hook, campaignHook: campaignHook});
        emit CampaignCreated(campaign, msg.sender, attributor, hook, campaignHook);

        // Initialize both hooks
        CampaignHook(campaignHook).createCampaign(campaign, "");
        AttributionHook(hook).createCampaign(campaign, initData);
    }

    /// @notice Updates the status of a campaign
    ///
    /// @param campaign Address of the campaign to update
    /// @param newStatus New status to set for the campaign
    ///
    /// @dev Status transitions are delegated to the campaign hook
    function updateCampaignStatus(address campaign, CampaignHook.CampaignStatus newStatus) external {
        CampaignInfo storage campaignInfo = campaigns[campaign];
        CampaignHook(campaignInfo.campaignHook).updateStatus(
            campaign, newStatus, msg.sender, campaignInfo.sponsor, campaignInfo.attributor
        );
    }

    /// @notice Processes attribution for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param payoutToken Address of the token to be distributed
    /// @param attributionData Encoded attribution data for the hook
    ///
    /// @dev Only attributor can call on campaigns that allow attribution. Calculates protocol fees and updates balances.
    function attribute(address campaign, address payoutToken, bytes calldata attributionData) external {
        CampaignInfo storage campaignInfo = campaigns[campaign];

        // Check campaign allows attribution via campaign hook
        if (!CampaignHook(campaignInfo.campaignHook).canAttribute(campaign)) {
            revert InvalidCampaignStatus();
        }

        // Check sender is attributor
        if (msg.sender != campaignInfo.attributor) revert Unauthorized();

        (Payout[] memory payouts, uint256 attributionFee) = AttributionHook(campaignInfo.hook).attribute(
            campaign, campaignInfo.attributor, payoutToken, attributionData
        );

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
        fees[payoutToken][campaignInfo.attributor] += attributionFee;
        emit FeeAllocated(campaign, payoutToken, campaignInfo.attributor, attributionFee);

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
        CampaignInfo storage campaignInfo = campaigns[campaign];

        // Check sender is sponsor
        if (msg.sender != campaignInfo.sponsor) revert Unauthorized();

        // Check campaign is finalized
        CampaignHook.CampaignStatus status = CampaignHook(campaignInfo.campaignHook).getStatus(campaign);
        if (status != CampaignHook.CampaignStatus.FINALIZED) revert InvalidCampaignStatus();

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
}

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

/**
 * Notes:
 * - enforces that rewards for a given payment can never total to more than the payment's captured amount (does this with marginal enforcement)
 * - allows for proper refund accounting in a refund operator contracts
 *
 * Open questions:
 * - should payouts be restricted to single payout only i.e. to the payer of the payment?
 * - should allocation and distribution be enabled instead of just one-shot rewards?
 *     (this would be a convenience purely for the campaign managers -- they can always deallocate if a payment was voided or relcaimed)
 *     (calls to onDistribute would just perform the same accounting that's happening in onReward)
 * - do we want to add a helper function for creating the hookdata for a single payout?
 * - are we sure about the refund math possible in the refund operator? (arbitrary sequences of captures, rewards, and refunds)
 */

/// @title CashbackRewards
///
/// @notice Campaign Hooks for cashback rewards controlled by a campaign manager
contract CashbackRewards is CampaignHooks {
    /// @notice The escrow contract to track payment states
    AuthCaptureEscrow public immutable escrow;

    /// @notice Managers of the campaigns
    mapping(address campaign => address manager) public managers;

    /// @notice Tracks total rewards distributed per payment per campaign
    mapping(bytes32 paymentHash => mapping(address campaign => uint256 amount)) public rewardsDistributed;

    /// @notice Tracks which campaigns have contributed to each payment (for refund purposes)
    mapping(bytes32 paymentHash => address[] campaigns) public paymentContributors;

    /// @notice Thrown when the sender is not the manager of the campaign
    error Unauthorized();

    /// @notice Thrown when payout recipient doesn't match the payment's payer
    error PayoutRecipientMismatch(address recipient, address expectedPayer);

    constructor(address flywheel_, address escrow_) CampaignHooks(flywheel_) {
        escrow = escrow_;
    }

    /// @inheritdoc CampaignHooks
    function onCreateCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {
        managers[campaign] = abi.decode(hookData, (address));
    }

    /// @inheritdoc CampaignHooks
    function onUpdateStatus(
        address sender,
        address campaign,
        Flywheel.CampaignStatus oldStatus,
        Flywheel.CampaignStatus newStatus,
        bytes calldata hookData
    ) external override onlyFlywheel {
        if (sender != managers[campaign]) revert Unauthorized();
    }

    /// @inheritdoc CampaignHooks
    /// @dev Expects hookData to contain abi.encode(paymentInfo, payouts)
    /// @dev Validates that all payout recipients match the payment's payer (security critical!)
    function onReward(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        if (sender != managers[campaign]) revert Unauthorized();

        // Decode the PaymentInfo and payouts from hookData
        AuthCaptureEscrow.PaymentInfo memory paymentInfo;
        (paymentInfo, payouts) = abi.decode(hookData, (AuthCaptureEscrow.PaymentInfo, Flywheel.Payout[]));

        // Security: Validate all payout recipients match the payment's payer
        // This prevents gaming the system by paying yourself while claiming to reward the real payer
        for (uint256 i = 0; i < payouts.length; i++) {
            if (payouts[i].recipient != paymentInfo.payer) {
                revert PayoutRecipientMismatch(payouts[i].recipient, paymentInfo.payer);
            }
        }

        // Calculate the payment hash from the PaymentInfo
        // This ensures we're tracking contributions to real payments
        bytes32 paymentInfoHash = escrow.getHash(paymentInfo);

        // Track this campaign as a contributor if it's the first time
        if (rewardsDistributed[paymentInfoHash][campaign] == 0) {
            paymentContributors[paymentInfoHash].push(campaign);
        }

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < payouts.length; i++) {
            totalAmount += payouts[i].amount;
        }

        AuthCaptureEscrow.PaymentState memory paymentState = escrow.paymentState(paymentInfoHash);
        uint256 netCaptured = paymentState.refundableAmount;
        uint256 alreadyRewarded = rewardsDistributed[paymentInfoHash][campaign];

        if (alreadyRewarded + totalAmount > netCaptured) {
            revert ExceedsNetCaptured(totalAmount, netCaptured - alreadyRewarded);
        }

        // Track total rewards distributed for this payment from this campaign
        rewardsDistributed[paymentInfoHash][campaign] += totalAmount;

        return (payouts, 0); // No fee charged
    }

    /// @inheritdoc CampaignHooks
    function onWithdrawFunds(address sender, address campaign, address token, uint256 amount, bytes calldata hookData)
        external
        override
        onlyFlywheel
    {
        if (sender != managers[campaign]) revert Unauthorized();
    }

    /// @notice Get the list of campaigns that contributed rewards for a specific payment
    /// @param paymentInfoHash The hash of the payment info
    /// @return campaigns Array of campaign addresses that contributed
    function getPaymentContributors(bytes32 paymentInfoHash) external view returns (address[] memory campaigns) {
        return paymentContributors[paymentInfoHash];
    }

    /// @notice Get contribution details for a payment (useful for refund calculations)
    /// @param paymentInfoHash The hash of the payment info
    /// @return contributors Array of campaign addresses
    /// @return amounts Array of amounts contributed by each campaign (same index as contributors)
    function getPaymentContributionDetails(bytes32 paymentInfoHash)
        external
        view
        returns (address[] memory contributors, uint256[] memory amounts)
    {
        contributors = paymentContributors[paymentInfoHash];
        amounts = new uint256[](contributors.length);

        for (uint256 i = 0; i < contributors.length; i++) {
            amounts[i] = rewardsDistributed[paymentInfoHash][contributors[i]];
        }
    }
}

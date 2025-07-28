pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";
import {Flywheel} from "./Flywheel.sol";
import {SimpleRewards} from "./hooks/SimpleRewards.sol";

/**
 * @title RewardRefundOperator
 * @notice Handles proportional refunding of rewards when payments are refunded
 * @dev When a payment is refunded, this contract calculates what portion of the total
 *      captured amount is being refunded, then refunds that same proportion of rewards
 *      back to each campaign that contributed rewards for that payment.
 *
 * Mathematical Example (with NET CAPTURED accounting + inter-refund rewards):
 *
 * Step 1: Initial State
 * - Captured: $100, Refunded: $0, Net: $100
 * - Campaign A rewards: $10, Campaign B rewards: $5
 *
 * Step 2: First Refund ($30)
 * - Refund $30 out of $100 net = 30% proportion
 * - Campaign A gets back: 30% × $10 = $3, remaining unreturned: $7
 * - Campaign B gets back: 30% × $5 = $1.50, remaining unreturned: $3.50
 * - Buyer gets: $30 - $4.50 = $25.50
 * - New state: Net captured = $70
 *
 * Step 3: Inter-Refund Reward (Campaign C joins late)
 * - Campaign C adds $6 reward (after seeing the payment activity)
 * - Current unreturned rewards: A=$7, B=$3.50, C=$6 (total=$16.50)
 *
 * Step 4: Second Refund ($35)
 * - Refund $35 out of $70 net = 50% proportion
 * - Campaign A gets back: 50% × $7 = $3.50, remaining: $3.50
 * - Campaign B gets back: 50% × $3.50 = $1.75, remaining: $1.75
 * - Campaign C gets back: 50% × $6 = $3.00, remaining: $3.00
 * - Total reward refunds: $8.25
 * - Buyer gets: $35 - $8.25 = $26.75
 *
 * Final Verification:
 * - Total rewards given: $10 + $5 + $6 = $21
 * - Total rewards refunded: $3 + $1.50 + $3.50 + $1.75 + $3.00 = $12.75
 * - Remaining unreturned: $21 - $12.75 = $8.25 ✅ (matches sum of remaining)
 * - Net captured remaining: $70 - $35 = $35 ✅
 *
 * EDGE CASE HANDLING: If total unreturned rewards exceed net captured amount, the algorithm
 * automatically scales down all reward refunds proportionally to fit within the refund amount.
 * This ensures mathematical soundness even with excessive reward scenarios.
 *
 * Example: If refund is $35 but proportional rewards would be $50, all rewards are scaled by 35/50 = 70%
 *
 * Extreme Edge Case Test:
 * - Net captured: $70, Campaign C adds massive $200 reward after first refund
 * - Second refund: $35 (50% of $70)
 * - Unreturned rewards: A=$7, B=$3.50, C=$200 (total=$210.50)
 * - Ideal proportional: A=$3.50, B=$1.75, C=$100 (total=$105.25)
 * - But only $35 available! Scale by 35/105.25 = 33.25%
 * - Final refunds: A=$1.16, B=$0.58, C=$33.26 (total=$35.00)
 * - Buyer gets: $0 (all goes to scaled reward refunds)
 *
 * Usage Pattern:
 * 1. Rewards are tracked automatically via SimpleRewards hook
 * 2. Call processRefund() when refunds occur - gets net captured from escrow directly
 * 3. Proportional distribution calculated and executed automatically
 */
contract RewardRefundOperator is Ownable {
    /// @notice The escrow contract to track payment states
    AuthCaptureEscrow public immutable escrow;

    /// @notice The flywheel contract for reward operations
    Flywheel public immutable flywheel;

    /// @notice The rewards hook contract to query reward contributors
    SimpleRewards public immutable rewardsHook;

    // Note: We get capture/refund totals directly from AuthCaptureEscrow.paymentState()
    // No need for duplicate tracking since escrow maintains authoritative state

    /// @notice Tracks total rewards already refunded back to each campaign per payment
    mapping(bytes32 paymentInfoHash => mapping(address campaign => uint256 totalRewardsRefunded)) public
        totalRewardsRefundedByCampaign;

    /// @notice Emitted when rewards are proportionally refunded to contributors
    event RewardsRefunded(
        bytes32 indexed paymentInfoHash, address indexed campaign, uint256 refundedAmount, uint256 refundProportion
    );

    // Note: We rely on AuthCaptureEscrow events for capture/refund tracking
    // PaymentTotalsUpdated event removed - use escrow.paymentState() for authoritative data

    /// @notice Thrown when caller is not authorized for the payment
    error Unauthorized();

    /// @notice Thrown when refund amount exceeds available funds
    error InsufficientRefundAmount();

    /// @notice Thrown when payment has no captured amount to base refunds on
    error NoCapturedAmount();

    /// @notice Constructor
    /// @param _escrow Address of the AuthCaptureEscrow contract
    /// @param _flywheel Address of the Flywheel contract
    /// @param _rewardsHook Address of the SimpleRewards hook contract
    /// @param _owner Address of the contract owner
    constructor(address _escrow, address _flywheel, address _rewardsHook, address _owner) Ownable(_owner) {
        escrow = AuthCaptureEscrow(_escrow);
        flywheel = Flywheel(_flywheel);
        rewardsHook = SimpleRewards(_rewardsHook);
    }

    // No need for recordCapture() - AuthCaptureEscrow tracks this authoritatively

    /// @notice Process a refund with proportional reward redistribution using NET CAPTURED accounting
    /// @param paymentInfo PaymentInfo struct
    /// @param refundAmount Amount being refunded to the buyer
    /// @param token Token being refunded
    /// @dev Uses "net captured" (captured - previously refunded) as basis for proportional calculations
    ///      This prevents over-refunding rewards when captures/refunds happen in different orders
    function processRefund(AuthCaptureEscrow.PaymentInfo calldata paymentInfo, uint256 refundAmount, address token)
        external
        onlyOwner
    {
        bytes32 paymentInfoHash = escrow.getHash(paymentInfo);

        // Get net captured amount directly from AuthCaptureEscrow (before the refund)
        // This is refundableAmount BEFORE the actual refund call reduces it
        uint256 netCapturedBeforeRefund = escrow.paymentState(paymentInfoHash).refundableAmount;

        if (netCapturedBeforeRefund == 0) revert NoCapturedAmount();
        if (netCapturedBeforeRefund < refundAmount) revert InsufficientRefundAmount();

        // Note: AuthCaptureEscrow will update its refundableAmount when refund() is called

        // Calculate refund proportion based on NET CAPTURED amount (using 18 decimal precision)
        uint256 refundProportion = (refundAmount * 1e18) / netCapturedBeforeRefund;

        // Get all campaigns that contributed rewards (using our internal tracking)
        address[] memory contributors = _getContributorCampaigns(paymentInfoHash);

        // Pre-calculate total reward refunds to ensure we don't exceed refund amount
        uint256 totalPotentialRefunds = 0;
        uint256[] memory individualRefunds = new uint256[](contributors.length);

        for (uint256 i = 0; i < contributors.length; i++) {
            address campaign = contributors[i];
            uint256 totalRewardsGiven = rewardsHook.rewardsDistributed(paymentInfoHash, campaign);
            uint256 alreadyRefundedToThisCampaign = totalRewardsRefundedByCampaign[paymentInfoHash][campaign];

            if (totalRewardsGiven == 0) continue;

            uint256 remainingRefundableRewards = totalRewardsGiven - alreadyRefundedToThisCampaign;
            if (remainingRefundableRewards == 0) continue;

            uint256 proportionalRefund = (remainingRefundableRewards * refundProportion) / 1e18;
            if (proportionalRefund > remainingRefundableRewards) {
                proportionalRefund = remainingRefundableRewards;
            }

            individualRefunds[i] = proportionalRefund;
            totalPotentialRefunds += proportionalRefund;
        }

        // If total reward refunds would exceed refund amount, scale them down proportionally
        // This handles the edge case where sum(unreturned_rewards) > net_captured_amount
        uint256 scalingFactor = 1e18; // Default: no scaling
        if (totalPotentialRefunds > refundAmount) {
            scalingFactor = (refundAmount * 1e18) / totalPotentialRefunds;
        }

        uint256 totalRewardRefunds = 0;

        // Execute transfers using pre-calculated and scaled amounts
        for (uint256 i = 0; i < contributors.length; i++) {
            if (individualRefunds[i] == 0) continue;

            address campaign = contributors[i];

            // Apply scaling factor if total refunds exceeded refund amount
            uint256 finalRefundAmount = (individualRefunds[i] * scalingFactor) / 1e18;

            if (finalRefundAmount > 0) {
                // Update tracking
                totalRewardsRefundedByCampaign[paymentInfoHash][campaign] += finalRefundAmount;
                totalRewardRefunds += finalRefundAmount;

                // Transfer refund to campaign
                IERC20(token).transfer(campaign, finalRefundAmount);

                emit RewardsRefunded(paymentInfoHash, campaign, finalRefundAmount, refundProportion);
            }
        }

        // Send remaining refund amount to the buyer
        // Due to pre-calculation and scaling, totalRewardRefunds will never exceed refundAmount
        uint256 buyerRefundAmount = refundAmount - totalRewardRefunds;
        if (buyerRefundAmount > 0) {
            IERC20(token).transfer(paymentInfo.payer, buyerRefundAmount);
        }

        // AuthCaptureEscrow maintains authoritative state - no need for duplicate tracking
    }

    /// @notice Get refund information for a specific payment
    /// @param paymentInfo PaymentInfo struct
    /// @return paymentInfoHash Hash of the payment info
    /// @return totalCaptured Total amount ever captured for this payment
    /// @return totalRefunded Total amount ever refunded for this payment
    /// @return netCaptured Net amount still available for refunds (captured - refunded)
    /// @return contributors Array of campaigns that contributed rewards
    /// @return contributedAmounts Array of amounts contributed by each campaign
    /// @return refundedAmounts Array of amounts already refunded to each campaign
    /// @return remainingRefundable Array of remaining refundable amounts per campaign
    function getPaymentRefundInfo(AuthCaptureEscrow.PaymentInfo calldata paymentInfo)
        external
        view
        returns (
            bytes32 paymentInfoHash,
            uint256 totalCaptured,
            uint256 totalRefunded,
            uint256 netCaptured,
            address[] memory contributors,
            uint256[] memory contributedAmounts,
            uint256[] memory refundedAmounts,
            uint256[] memory remainingRefundable
        )
    {
        paymentInfoHash = escrow.getHash(paymentInfo);

        // Get authoritative state from AuthCaptureEscrow
        AuthCaptureEscrow.PaymentState memory state = escrow.paymentState(paymentInfoHash);
        netCaptured = state.refundableAmount;

        // For display purposes, we can estimate totals, but netCaptured is the key value
        totalCaptured = netCaptured; // This is a simplification - we could track historical if needed
        totalRefunded = 0; // We don't track this separately anymore

        contributors = _getContributorCampaigns(paymentInfoHash);

        contributedAmounts = new uint256[](contributors.length);
        refundedAmounts = new uint256[](contributors.length);
        remainingRefundable = new uint256[](contributors.length);

        for (uint256 i = 0; i < contributors.length; i++) {
            address campaign = contributors[i];
            contributedAmounts[i] = rewardsHook.rewardsDistributed(paymentInfoHash, campaign);
            refundedAmounts[i] = totalRewardsRefundedByCampaign[paymentInfoHash][campaign];
            remainingRefundable[i] = contributedAmounts[i] - refundedAmounts[i];
        }
    }

    /// @notice Internal helper to get all campaigns that have contributed rewards for a payment
    /// @param paymentInfoHash Hash of the payment info
    /// @return contributors Array of campaign addresses that have given rewards
    function _getContributorCampaigns(bytes32 paymentInfoHash) internal view returns (address[] memory contributors) {
        // Since we can't iterate mappings, we need to rely on the SimpleRewards hook for this
        // This maintains compatibility with the existing system
        (contributors,) = rewardsHook.getPaymentContributionDetails(paymentInfoHash);
    }
}

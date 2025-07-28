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
 * Mathematical Example (with NET CAPTURED accounting):
 * - Payment: $100 captured, $30 previously refunded → Net: $70
 * - Campaign A contributed $10 rewards (already got $3 back), remaining: $7
 * - Campaign B contributed $5 rewards (already got $1.50 back), remaining: $3.50
 * - If $35 is being refunded (50% of $70 net captured):
 *   - Campaign A gets back: 50% × $7 = $3.50
 *   - Campaign B gets back: 50% × $3.50 = $1.75
 *   - Buyer gets: $35 - $5.25 = $29.75
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

        uint256 totalRewardRefunds = 0;

        // Process proportional refunds to each reward contributor
        for (uint256 i = 0; i < contributors.length; i++) {
            address campaign = contributors[i];
            uint256 totalRewardsGiven = rewardsHook.rewardsDistributed(paymentInfoHash, campaign);
            uint256 alreadyRefundedToThisCampaign = totalRewardsRefundedByCampaign[paymentInfoHash][campaign];

            if (totalRewardsGiven == 0) continue;

            // Calculate REMAINING rewards this campaign is owed refunds for
            uint256 remainingRefundableRewards = totalRewardsGiven - alreadyRefundedToThisCampaign;

            if (remainingRefundableRewards == 0) continue;

            // Calculate proportional refund amount for this campaign based on remaining rewards
            uint256 proportionalRefund = (remainingRefundableRewards * refundProportion) / 1e18;

            // Ensure we don't over-refund due to rounding
            if (proportionalRefund > remainingRefundableRewards) {
                proportionalRefund = remainingRefundableRewards;
            }

            if (proportionalRefund > 0) {
                // Update tracking
                totalRewardsRefundedByCampaign[paymentInfoHash][campaign] += proportionalRefund;
                totalRewardRefunds += proportionalRefund;

                // Transfer refund to campaign
                IERC20(token).transfer(campaign, proportionalRefund);

                emit RewardsRefunded(paymentInfoHash, campaign, proportionalRefund, refundProportion);
            }
        }

        // Send remaining refund amount to the buyer
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

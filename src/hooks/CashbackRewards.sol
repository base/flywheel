// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";
import {SimpleRewards} from "./SimpleRewards.sol";

/// @title CashbackRewards
///
/// @notice Reward buyers for their purchases made with the Commerce Payments Protocol (https://github.com/base/commerce-payments)
///
/// @dev Rewards must be made in the same token as the original payment token (cashback)
/// @dev Rewards can be made in any amount (supports %, fixed, etc.)
/// @dev Maximum reward percentage can be optionally configured per campaign
/// @dev Rewards can be made on any payment (supports custom filtering for platforms, wallets, merchants, etc.)
///
/// @author Coinbase
contract CashbackRewards is SimpleRewards {
    /// @notice Operation types for reward validation
    enum RewardOperation {
        REWARD,
        ALLOCATE,
        DEALLOCATE,
        DISTRIBUTE
    }

    /// @notice Tracks rewards info per payment per campaign
    struct RewardState {
        /// @dev Amount of reward allocated for this payment
        uint120 allocated;
        /// @dev Amount of reward distributed for this payment
        uint120 distributed;
    }

    /// @notice A struct for a payment reward
    struct PaymentReward {
        /// @dev The payment to reward
        AuthCaptureEscrow.PaymentInfo paymentInfo;
        /// @dev The reward payout amount
        uint120 payoutAmount;
    }

    /// @notice The divisor for max reward basis points (10_000 = 100%)
    uint256 public constant BASIS_POINTS_100_PERCENT = 10_000;

    /// @notice The escrow contract to track payment states and calculate payment hash
    AuthCaptureEscrow public immutable escrow;

    /// @notice Tracks an optional maximum reward percentage per campaign in basis points (10_000 = 100%)
    mapping(address campaign => uint256 maxRewardBasisPoints) public maxRewardBasisPoints;

    /// @notice Tracks rewards info per campaign per payment
    mapping(address campaign => mapping(bytes32 paymentHash => RewardState rewardState)) public rewards;

    /// @notice Thrown when the allocated amount is less than the amount being deallocated or distributed
    error InsufficientAllocation(uint120 amount, uint120 allocated);

    /// @notice Thrown when the payment amount is invalid
    error ZeroPayoutAmount();

    /// @notice Thrown when the payment token does not match the campaign token
    error TokenMismatch();

    /// @notice Thrown when the payment has not been collected
    error PaymentNotCollected();

    /// @notice Thrown when the reward amount exceeds the maximum allowed percentage
    error RewardExceedsMaxPercentage(
        bytes32 paymentInfoHash, uint120 maxAllowedRewardAmount, uint120 excessRewardAmount
    );

    /// @notice Constructor
    ///
    /// @param flywheel_ The Flywheel core protocol contract address
    /// @param escrow_ The AuthCaptureEscrow contract address
    constructor(address flywheel_, address escrow_) SimpleRewards(flywheel_) {
        escrow = AuthCaptureEscrow(escrow_);
    }

    /// @inheritdoc CampaignHooks
    function onCreateCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {
        (address owner, address manager, string memory uri, uint16 maxRewardBasisPoints_) =
            abi.decode(hookData, (address, address, string, uint16));
        owners[campaign] = owner;
        managers[campaign] = manager;
        campaignURI[campaign] = uri;
        maxRewardBasisPoints[campaign] = uint256(maxRewardBasisPoints_);
        emit CampaignCreated(campaign, owner, manager, uri);
    }

    /// @inheritdoc CampaignHooks
    function onReward(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        PaymentReward[] memory paymentRewards = abi.decode(hookData, (PaymentReward[]));
        uint256 len = paymentRewards.length;
        payouts = new Flywheel.Payout[](len);

        // For each payment reward, distribute the payout amount
        for (uint256 i = 0; i < len; i++) {
            bytes32 paymentInfoHash = _validatePaymentReward(paymentRewards[i], campaign, token, RewardOperation.REWARD);
            payouts[i] = _preparePayout(paymentRewards[i], paymentInfoHash);

            // Add the payout amount to the distributed amount
            rewards[campaign][paymentInfoHash].distributed += paymentRewards[i].payoutAmount;
        }
    }

    /// @inheritdoc CampaignHooks
    function onAllocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        PaymentReward[] memory paymentRewards = abi.decode(hookData, (PaymentReward[]));
        uint256 len = paymentRewards.length;
        payouts = new Flywheel.Payout[](len);

        // For each payment reward, allocate the payout amount
        for (uint256 i = 0; i < len; i++) {
            bytes32 paymentInfoHash =
                _validatePaymentReward(paymentRewards[i], campaign, token, RewardOperation.ALLOCATE);
            payouts[i] = _preparePayout(paymentRewards[i], paymentInfoHash);

            // Add the payout amount to the allocated amount
            rewards[campaign][paymentInfoHash].allocated += paymentRewards[i].payoutAmount;
        }
    }

    /// @inheritdoc CampaignHooks
    function onDeallocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts)
    {
        PaymentReward[] memory paymentRewards = abi.decode(hookData, (PaymentReward[]));
        uint256 len = paymentRewards.length;
        payouts = new Flywheel.Payout[](len);

        // For each payment reward, deduct the payout amount (or the entire remaining allocated amount if payout amount is 0) from allocated
        for (uint256 i = 0; i < len; i++) {
            PaymentReward memory paymentReward = paymentRewards[i];

            // Basic validation (payment collected, token match) - skip percentage validation for deallocate
            bytes32 paymentInfoHash = _validatePaymentReward(paymentReward, campaign, token, RewardOperation.DEALLOCATE);

            // Determine correct deallocation amount (special case of max uint120 means deallocate all allocated)
            uint120 allocated = rewards[campaign][paymentInfoHash].allocated;
            uint120 payoutAmount = paymentReward.payoutAmount;
            if (payoutAmount == type(uint120).max) payoutAmount = allocated;

            // Check sufficient allocation
            if (allocated < payoutAmount) revert InsufficientAllocation(payoutAmount, allocated);

            // Deduct the payout amount from allocated
            rewards[campaign][paymentInfoHash].allocated = allocated - payoutAmount;

            // Prepare the payout and assign the correct payout amount in case of max uint120
            payouts[i] = _preparePayout(paymentReward, paymentInfoHash);
            payouts[i].amount = payoutAmount;
        }
    }

    /// @inheritdoc CampaignHooks
    function onDistribute(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        PaymentReward[] memory paymentRewards = abi.decode(hookData, (PaymentReward[]));
        uint256 len = paymentRewards.length;
        payouts = new Flywheel.Payout[](len);

        // For each payment reward, shift the payout amount from allocated to distributed
        for (uint256 i = 0; i < len; i++) {
            bytes32 paymentInfoHash =
                _validatePaymentReward(paymentRewards[i], campaign, token, RewardOperation.DISTRIBUTE);
            payouts[i] = _preparePayout(paymentRewards[i], paymentInfoHash);
            uint120 payoutAmount = paymentRewards[i].payoutAmount;

            // Check sufficient allocation
            uint120 allocated = rewards[campaign][paymentInfoHash].allocated;
            if (allocated < payoutAmount) revert InsufficientAllocation(payoutAmount, allocated);

            // Shift the payout amount from allocated to distributed
            rewards[campaign][paymentInfoHash].allocated = allocated - payoutAmount;
            rewards[campaign][paymentInfoHash].distributed += payoutAmount;
        }
    }

    /// @dev Validates a payment reward and returns the payment info hash
    ///
    /// @param paymentReward The payment reward
    /// @param campaign The campaign address
    /// @param token The campaign token
    /// @param operation The type of operation being performed
    function _validatePaymentReward(
        PaymentReward memory paymentReward,
        address campaign,
        address token,
        RewardOperation operation
    ) internal view returns (bytes32 paymentInfoHash) {
        // Check payout amount non-zero
        if (paymentReward.payoutAmount == 0) revert ZeroPayoutAmount();

        // Check the token matches the payment token
        if (paymentReward.paymentInfo.token != token) revert TokenMismatch();

        // Check payment has been collected
        paymentInfoHash = escrow.getHash(paymentReward.paymentInfo);
        (bool hasCollectedPayment, uint120 capturableAmount, uint120 refundableAmount) =
            escrow.paymentState(paymentInfoHash);
        if (!hasCollectedPayment) revert PaymentNotCollected();

        // Early return if deallocating, skips percentage validation
        if (operation == RewardOperation.DEALLOCATE) return paymentInfoHash;

        // Early return if no max reward percentage is configured
        uint256 maxRewardBps = maxRewardBasisPoints[campaign];
        if (maxRewardBps == 0) return paymentInfoHash;

        // Payment amount is the captured amount that has not been refunded i.e. "refundable" amount
        uint120 paymentAmount = refundableAmount;
        uint120 previouslyRewardedAmount = rewards[campaign][paymentInfoHash].distributed;

        // If allocating, add the pre-capture and pre-distribution amounts too to prevent allocating more than the max allowed reward for this payment
        if (operation == RewardOperation.ALLOCATE) {
            paymentAmount += capturableAmount;
            previouslyRewardedAmount += rewards[campaign][paymentInfoHash].allocated;
        }

        // Check total reward amount doesn't exceed the max allowed reward for this payment
        uint120 totalRewardAmount = previouslyRewardedAmount + paymentReward.payoutAmount;
        uint120 maxAllowedRewardAmount = uint120(paymentAmount * maxRewardBps / BASIS_POINTS_100_PERCENT);
        if (totalRewardAmount > maxAllowedRewardAmount) {
            revert RewardExceedsMaxPercentage(
                paymentInfoHash, maxAllowedRewardAmount, totalRewardAmount - maxAllowedRewardAmount
            );
        }
    }

    /// @dev Prepares a Flywheel.Payout for a given payment reward
    ///
    /// @param paymentReward The payment reward
    ///
    /// @return payout The Flywheel.Payout
    function _preparePayout(PaymentReward memory paymentReward, bytes32 paymentInfoHash)
        internal
        pure
        returns (Flywheel.Payout memory payout)
    {
        return Flywheel.Payout({
            recipient: paymentReward.paymentInfo.payer,
            amount: paymentReward.payoutAmount,
            extraData: abi.encodePacked(paymentInfoHash)
        });
    }
}

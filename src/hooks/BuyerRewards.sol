// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";
import {SimpleRewards} from "./SimpleRewards.sol";

/// @title BuyerRewards
///
/// @notice Reward buyers for their purchases made with the Commerce Payments Protocol (https://github.com/base/commerce-payments)
///
/// @dev Rewards must be made in the same token as the original payment token (cashback)
/// @dev Rewards can be made in any amount (supports %, fixed, etc.)
/// @dev Rewards can be made on any payment (supports custom filtering for platforms, wallets, merchants, etc.)
///
/// @author Coinbase
contract BuyerRewards is SimpleRewards {
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

    /// @notice The escrow contract to track payment states and calculate payment hash
    AuthCaptureEscrow public immutable escrow;

    /// @notice Tracks an optional maximum reward percentage per campaign in basis points (10000 = 100%)
    mapping(address campaign => uint16 maxRewardPercentage) public maxRewardPercentage;

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
    error RewardExceedsMaxPercentage(uint120 payoutAmount, uint120 maxAllowedAmount);

    /// @notice Operation types for reward validation
    enum RewardOperation {
        REWARD,
        ALLOCATE,
        DISTRIBUTE,
        DEALLOCATE
    }

    /// @notice Constructor
    ///
    /// @param flywheel_ The Flywheel core protocol contract address
    /// @param escrow_ The AuthCaptureEscrow contract address
    constructor(address flywheel_, address escrow_) SimpleRewards(flywheel_) {
        escrow = AuthCaptureEscrow(escrow_);
    }

    /// @notice Creates a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param hookData Data for the campaign hook
    ///
    /// @dev Only callable by the flywheel contract
    /// @inheritdoc CampaignHooks
    function onCreateCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {
        (address owner, address manager, string memory uri, uint16 maxRewardPercentage_) =
            abi.decode(hookData, (address, address, string, uint16));
        owners[campaign] = owner;
        managers[campaign] = manager;
        campaignURI[campaign] = uri;
        maxRewardPercentage[campaign] = maxRewardPercentage_;
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

            payouts[i] = Flywheel.Payout({
                recipient: paymentReward.paymentInfo.payer,
                amount: payoutAmount,
                extraData: abi.encodePacked(paymentInfoHash)
            });

            // Check sufficient allocation
            if (allocated < payoutAmount) revert InsufficientAllocation(payoutAmount, allocated);

            // Deduct the payout amount from allocated
            rewards[campaign][paymentInfoHash].allocated = allocated - payoutAmount;
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

        // Get payment state - single call for efficiency
        paymentInfoHash = escrow.getHash(paymentReward.paymentInfo);
        (bool hasCollectedPayment, uint120 capturableAmount, uint120 refundableAmount) =
            escrow.paymentState(paymentInfoHash);
        if (!hasCollectedPayment) revert PaymentNotCollected();

        // Check reward operation doesn't violate max reward percentage if configured

        // Skip percentage validation for deallocate operations
        if (operation == RewardOperation.DEALLOCATE) return paymentInfoHash;

        uint16 maxPercentage = maxRewardPercentage[campaign];
        if (maxPercentage == 0) return paymentInfoHash; // No limit configured

        // Determine the base amount for percentage calculation based on operation
        uint120 baseAmount;
        uint120 cumulativeRewardAmount;
        if (operation == RewardOperation.ALLOCATE) {
            // For allocation, use total payment amount (capturable + refundable)
            baseAmount = capturableAmount + refundableAmount;
            cumulativeRewardAmount =
                rewards[campaign][paymentInfoHash].allocated + rewards[campaign][paymentInfoHash].distributed;
        } else {
            // For reward/distribute, use only capturable amount
            baseAmount = refundableAmount;
            cumulativeRewardAmount = rewards[campaign][paymentInfoHash].distributed;
        }

        // Use cross-multiplication to avoid precision loss from division
        // Instead of: payoutAmount <= (baseAmount * maxPercentage) / 10000
        // We check: payoutAmount * 10000 <= baseAmount * maxPercentage
        uint256 scaledNewCumulativeRewardAmount = uint256(paymentReward.payoutAmount + cumulativeRewardAmount) * 10000;
        uint256 scaledMaxAllowed = uint256(baseAmount) * uint256(maxPercentage);

        if (scaledNewCumulativeRewardAmount > scaledMaxAllowed) {
            // Calculate the actual max allowed amount for error reporting
            uint120 maxAllowedAmount = uint120((uint256(baseAmount) * uint256(maxPercentage)) / 10000);
            revert RewardExceedsMaxPercentage(paymentReward.payoutAmount, maxAllowedAmount);
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

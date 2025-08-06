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
/// @dev Rewards can be made in any token (supports cashback, loyalty, etc.)
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

    /// @notice Tracks rewards info per campaign per token per payment
    mapping(address campaign => mapping(address token => mapping(bytes32 paymentHash => RewardState rewardState)))
        public rewards;

    /// @notice Thrown when the allocated amount is less than the amount being deallocated or distributed
    error InsufficientAllocation(uint120 amount, uint120 allocated);

    /// @notice Thrown when the payment amount is invalid
    error ZeroPayoutAmount();

    /// @notice Thrown when the payment has not been collected
    error PaymentNotCollected();

    /// @notice Constructor
    ///
    /// @param flywheel_ The Flywheel core protocol contract address
    /// @param escrow_ The AuthCaptureEscrow contract address
    constructor(address flywheel_, address escrow_) SimpleRewards(flywheel_) {
        escrow = AuthCaptureEscrow(escrow_);
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
            bytes32 paymentInfoHash = _validatePaymentReward(paymentRewards[i]);
            payouts[i] = _preparePayout(paymentRewards[i], paymentInfoHash);

            // Add the payout amount to the distributed amount
            rewards[campaign][token][paymentInfoHash].distributed += paymentRewards[i].payoutAmount;
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
            bytes32 paymentInfoHash = _validatePaymentReward(paymentRewards[i]);
            payouts[i] = _preparePayout(paymentRewards[i], paymentInfoHash);

            // Add the payout amount to the allocated amount
            rewards[campaign][token][paymentInfoHash].allocated += paymentRewards[i].payoutAmount;
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

        // For each payment reward, deduct the payout amount from allocated
        for (uint256 i = 0; i < len; i++) {
            bytes32 paymentInfoHash = _validatePaymentReward(paymentRewards[i]);
            payouts[i] = _preparePayout(paymentRewards[i], paymentInfoHash);
            uint120 payoutAmount = paymentRewards[i].payoutAmount;

            // Check sufficient allocation
            uint120 allocated = rewards[campaign][token][paymentInfoHash].allocated;
            if (allocated < payoutAmount) revert InsufficientAllocation(payoutAmount, allocated);

            // Deduct the payout amount from allocated
            rewards[campaign][token][paymentInfoHash].allocated = allocated - payoutAmount;
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
            bytes32 paymentInfoHash = _validatePaymentReward(paymentRewards[i]);
            payouts[i] = _preparePayout(paymentRewards[i], paymentInfoHash);
            uint120 payoutAmount = paymentRewards[i].payoutAmount;

            // Check sufficient allocation
            uint120 allocated = rewards[campaign][token][paymentInfoHash].allocated;
            if (allocated < payoutAmount) revert InsufficientAllocation(payoutAmount, allocated);

            // Shift the payout amount from allocated to distributed
            rewards[campaign][token][paymentInfoHash].allocated = allocated - payoutAmount;
            rewards[campaign][token][paymentInfoHash].distributed += payoutAmount;
        }
    }

    /// @dev Validates a payment reward and returns the payment info hash
    ///
    /// @param paymentReward The payment reward
    function _validatePaymentReward(PaymentReward memory paymentReward)
        internal
        view
        returns (bytes32 paymentInfoHash)
    {
        // Check payout amount non-zero
        if (paymentReward.payoutAmount == 0) revert ZeroPayoutAmount();

        // Check payment has been collected
        paymentInfoHash = escrow.getHash(paymentReward.paymentInfo);
        (bool hasCollectedPayment,,) = escrow.paymentState(paymentInfoHash);
        if (!hasCollectedPayment) revert PaymentNotCollected();
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

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
    struct RewardsInfo {
        /// @dev Amount of reward allocated for this payment
        uint120 allocated;
        /// @dev Amount of reward distributed for this payment
        uint120 distributed;
    }

    /// @notice The escrow contract to track payment states and calculate payment hash
    AuthCaptureEscrow public immutable escrow;

    /// @notice Tracks rewards info per campaign per token per payment
    mapping(address campaign => mapping(address token => mapping(bytes32 paymentHash => RewardsInfo info))) public
        rewards;

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
        (AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 payoutAmount) =
            _parseHookData(token, hookData);

        rewards[campaign][token][paymentInfoHash].distributed += payoutAmount;

        return (_createPayouts(paymentInfo, paymentInfoHash, payoutAmount), 0);
    }

    /// @inheritdoc CampaignHooks
    function onAllocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        (AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 payoutAmount) =
            _parseHookData(token, hookData);

        rewards[campaign][token][paymentInfoHash].allocated += payoutAmount;

        return (_createPayouts(paymentInfo, paymentInfoHash, payoutAmount), 0);
    }

    /// @inheritdoc CampaignHooks
    function onDeallocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts)
    {
        (AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 payoutAmount) =
            _parseHookData(token, hookData);

        uint120 allocated = rewards[campaign][token][paymentInfoHash].allocated;
        if (allocated < payoutAmount) revert InsufficientAllocation(payoutAmount, allocated);
        rewards[campaign][token][paymentInfoHash].allocated = allocated - payoutAmount;

        return (_createPayouts(paymentInfo, paymentInfoHash, payoutAmount));
    }

    /// @inheritdoc CampaignHooks
    function onDistribute(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        (AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 payoutAmount) =
            _parseHookData(token, hookData);

        uint120 allocated = rewards[campaign][token][paymentInfoHash].allocated;
        if (allocated < payoutAmount) revert InsufficientAllocation(payoutAmount, allocated);
        rewards[campaign][token][paymentInfoHash].allocated = allocated - payoutAmount;

        rewards[campaign][token][paymentInfoHash].distributed += payoutAmount;

        return (_createPayouts(paymentInfo, paymentInfoHash, payoutAmount), 0);
    }

    /// @dev Parses the hook data and returns the payment info, payment info hash, and payout amount
    ///
    /// @param token Expected token address for validation
    /// @param hookData The hook data
    ///
    /// @return paymentInfo The payment info
    /// @return paymentInfoHash The payment info hash
    /// @return payoutAmount The payout amount
    function _parseHookData(address token, bytes calldata hookData)
        internal
        view
        returns (AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 payoutAmount)
    {
        // Check payout amount non-zero
        (paymentInfo, payoutAmount) = abi.decode(hookData, (AuthCaptureEscrow.PaymentInfo, uint120));
        if (payoutAmount == 0) revert ZeroPayoutAmount();

        // Check payment has been collected
        paymentInfoHash = escrow.getHash(paymentInfo);
        (bool hasCollectedPayment,,) = escrow.paymentState(paymentInfoHash);
        if (!hasCollectedPayment) revert PaymentNotCollected();
    }

    /// @notice Creates a Flywheel.Payout array for a given payment and amount
    ///
    /// @param paymentInfo Payment info
    /// @param paymentInfoHash Hash of payment info
    /// @param amount Amount of cashback to reward
    ///
    /// @return payouts Payout array
    function _createPayouts(AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 amount)
        internal
        pure
        returns (Flywheel.Payout[] memory payouts)
    {
        payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: paymentInfo.payer,
            amount: amount,
            extraData: abi.encodePacked(paymentInfoHash)
        });
    }
}

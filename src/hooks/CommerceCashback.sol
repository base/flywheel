// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";

/// @title CommerceCashback
///
/// @notice Campaign Hooks for processing commerce payment cashback rewards
///
/// @dev Handles allocation and distribution of rewards based on payment information from AuthCaptureEscrow
/// @dev TODO:Accounting logic is broken without full payment state tracking, operator hooks, or refund collector
contract CommerceCashback is CampaignHooks {
    /// @notice Configuration for cashback rewards
    struct CashbackConfig {
        /// @dev Address of the account who manages cashback rewards
        address manager;
        /// @dev Cashback basis points for calculating payouts
        uint16 cashbackBps;
    }

    /// @notice Maximum basis points (100%)
    uint16 public constant MAX_BPS = 10_000;

    /// @notice Address of the AuthCaptureEscrow contract
    AuthCaptureEscrow public immutable authCaptureEscrow;

    /// @notice Configurations for cashback reward campaigns
    mapping(address campaign => CashbackConfig config) public configs;

    /// @notice Cache snapshots for recent payment states
    mapping(address campaign => mapping(bytes32 paymentInfoHash => AuthCaptureEscrow.PaymentState snapshot)) public
        lastSnapshot;

    /// @notice Emitted when a cashback campaign is configured
    ///
    /// @param campaign Address of the campaign
    /// @param manager Address of the manager
    /// @param cashbackBps Cashback basis points
    event CashbackConfigured(address indexed campaign, address manager, uint16 cashbackBps);

    /// @notice Manager address cannot be zero
    error InvalidManager();

    /// @notice Cashback basis points cannot exceed maximum
    error InvalidCashbackBps();

    /// @notice Payment has not been authorized
    error PaymentNotAuthorized();

    /// @notice Capturable amount is not zero
    error PaymentNotVoided();

    /// @notice Reward has already been allocated for this payment
    error RewardAlreadyAllocated();

    /// @notice Reward allocation is zero
    error ZeroRewardAllocation();

    /// @notice Refundable amount decreased, indicating no capture was made
    error ZeroAdditionalCaptures();

    /// @notice Sender is not authorized to perform this action
    error Unauthorized();

    /// @notice Payment token does not match expected token
    error InvalidToken();

    /// @notice Constructor for CommerceRewards
    ///
    /// @param protocol_ Address of the protocol contract
    /// @param authCaptureEscrow_ Address of the AuthCaptureEscrow contract
    constructor(address protocol_, address authCaptureEscrow_) CampaignHooks(protocol_) {
        authCaptureEscrow = AuthCaptureEscrow(authCaptureEscrow_);
    }

    /// @inheritdoc CampaignHooks
    /// @dev Decodes cashback configuration and stores it for the campaign
    function onCreateCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {
        CashbackConfig memory config = abi.decode(hookData, (CashbackConfig));
        if (config.manager == address(0)) revert InvalidManager();
        if (config.cashbackBps > MAX_BPS) revert InvalidCashbackBps();

        configs[campaign] = config;
        emit CashbackConfigured(campaign, config.manager, config.cashbackBps);
    }

    /// @inheritdoc CampaignHooks
    /// @dev Decodes payment information and calculates rewards based on payment amounts
    function onAllocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        AuthCaptureEscrow.PaymentInfo memory payment = _parseParams(sender, campaign, token, hookData);
        (bytes32 paymentInfoHash, AuthCaptureEscrow.PaymentState memory paymentState) = _getPaymentState(payment);
        AuthCaptureEscrow.PaymentState memory snapshot = lastSnapshot[campaign][paymentInfoHash];
        lastSnapshot[campaign][paymentInfoHash] = paymentState;

        // Check payment has been authorized
        if (paymentState.capturableAmount == 0) revert PaymentNotAuthorized();

        // Check reward has not already been allocated
        if (snapshot.capturableAmount > 0) revert RewardAlreadyAllocated();

        uint256 amount = _calculateCashback(campaign, paymentState.capturableAmount + paymentState.refundableAmount);

        payouts = new Flywheel.Payout[](1);
        payouts[0] =
            Flywheel.Payout({recipient: payment.payer, amount: amount, extraData: abi.encodePacked(paymentInfoHash)});
    }

    /// @inheritdoc CampaignHooks
    function onDistribute(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        AuthCaptureEscrow.PaymentInfo memory payment = _parseParams(sender, campaign, token, hookData);
        (bytes32 paymentInfoHash, AuthCaptureEscrow.PaymentState memory paymentState) = _getPaymentState(payment);
        AuthCaptureEscrow.PaymentState memory snapshot = lastSnapshot[campaign][paymentInfoHash];
        lastSnapshot[campaign][paymentInfoHash] = paymentState;

        // Check payment has had more value captured
        if (paymentState.refundableAmount <= snapshot.refundableAmount) revert ZeroAdditionalCaptures();

        // Check reward has remaining allocation
        if (!snapshot.hasCollectedPayment) revert ZeroRewardAllocation();

        uint256 amount = _calculateCashback(campaign, paymentState.refundableAmount - snapshot.refundableAmount);

        payouts = new Flywheel.Payout[](1);
        payouts[0] =
            Flywheel.Payout({recipient: payment.payer, amount: amount, extraData: abi.encodePacked(paymentInfoHash)});
    }

    /// @inheritdoc CampaignHooks
    /// @dev Deallocates allocated cashback for a payment
    function onDeallocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts)
    {
        AuthCaptureEscrow.PaymentInfo memory payment = _parseParams(sender, campaign, token, hookData);
        (bytes32 paymentInfoHash, AuthCaptureEscrow.PaymentState memory paymentState) = _getPaymentState(payment);
        AuthCaptureEscrow.PaymentState memory snapshot = lastSnapshot[campaign][paymentInfoHash];
        lastSnapshot[campaign][paymentInfoHash] = paymentState;

        // Check payment was voided
        if (paymentState.capturableAmount > 0) revert PaymentNotVoided();

        // Check reward has remaining allocation
        if (snapshot.capturableAmount == 0) revert ZeroRewardAllocation();

        uint256 amount = _calculateCashback(campaign, snapshot.capturableAmount);

        payouts = new Flywheel.Payout[](1);
        payouts[0] =
            Flywheel.Payout({recipient: payment.payer, amount: amount, extraData: abi.encodePacked(paymentInfoHash)});
    }

    /// @inheritdoc CampaignHooks
    /// @dev Validate sender is campaign cashback manager
    function onWithdrawFunds(address sender, address campaign, address token, uint256 amount, bytes calldata hookData)
        external
        override
        onlyFlywheel
    {
        if (sender != configs[campaign].manager) revert Unauthorized();
    }

    /// @notice Parses the parameters for the onAllocate and onDistribute functions
    ///
    /// @param sender Address of the sender
    /// @param token Address of the token
    /// @param hookData Data for the campaign hook
    ///
    /// @return payment Payment info
    function _parseParams(address sender, address campaign, address token, bytes calldata hookData)
        internal
        view
        returns (AuthCaptureEscrow.PaymentInfo memory payment)
    {
        payment = abi.decode(hookData, (AuthCaptureEscrow.PaymentInfo));
        if (sender != configs[campaign].manager) revert Unauthorized();
        if (payment.token != token) revert InvalidToken();
    }

    /// @notice Gets the payment state for a payment
    ///
    /// @param payment Payment info
    ///
    /// @return paymentInfoHash Hash of the payment info
    /// @return paymentState Payment state
    function _getPaymentState(AuthCaptureEscrow.PaymentInfo memory payment)
        internal
        view
        returns (bytes32 paymentInfoHash, AuthCaptureEscrow.PaymentState memory paymentState)
    {
        paymentInfoHash = authCaptureEscrow.getHash(payment);
        (bool hasCollectedPayment, uint120 capturableAmount, uint120 refundableAmount) =
            authCaptureEscrow.paymentState(paymentInfoHash);
        paymentState = AuthCaptureEscrow.PaymentState(hasCollectedPayment, capturableAmount, refundableAmount);
    }

    /// @notice Calculates the cashback amount for a payment
    ///
    /// @param amount Amount of capturable or refundable payment
    /// @param campaign Address of the campaign
    ///
    /// @return cashback Amount of cashback to be distributed
    function _calculateCashback(address campaign, uint120 amount) internal view returns (uint256 cashback) {
        return ((amount * configs[campaign].cashbackBps) / MAX_BPS);
    }
}

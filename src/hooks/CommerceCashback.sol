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

    /// @notice Emitted when a payment is allocated
    ///
    /// @param campaign Address of the campaign
    /// @param paymentInfoHash Hash of the payment info
    /// @param amount Amount of cashback awarded
    event CashbackAllocated(address indexed campaign, bytes32 indexed paymentInfoHash, uint256 amount);

    /// @notice Emitted when a payment is distributed
    ///
    /// @param campaign Address of the campaign
    /// @param paymentInfoHash Hash of the payment info
    /// @param amount Amount of cashback awarded
    event CashbackDistributed(address indexed campaign, bytes32 indexed paymentInfoHash, uint256 amount);

    /// @notice Manager address cannot be zero
    error InvalidManager();

    /// @notice Cashback basis points cannot exceed maximum
    error InvalidCashbackBps();

    /// @notice Payment has not been collected yet
    error PaymentNotCollected();

    /// @notice Reward has already been allocated for this payment
    error RewardAlreadyAllocated();

    /// @notice Reward has not been allocated yet
    error RewardNotAllocated();

    /// @notice Refundable amount decreased, indicating no capture was made
    error RefundableAmountDecreased();

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
    function onCreateCampaign(address campaign, bytes calldata data) external override onlyFlywheel {
        CashbackConfig memory config = abi.decode(data, (CashbackConfig));

        // Check manager non-zero
        if (config.manager == address(0)) revert InvalidManager();

        // Check cashback basis points are valid
        if (config.cashbackBps > MAX_BPS) revert InvalidCashbackBps();

        configs[campaign] = config;
    }

    /// @inheritdoc CampaignHooks
    /// @dev Decodes payment information and calculates rewards based on payment amounts
    function onAllocate(address sender, address campaign, address token, bytes calldata data)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        AuthCaptureEscrow.PaymentInfo memory payment = _parseParams(sender, campaign, token, data);
        (bytes32 paymentInfoHash, AuthCaptureEscrow.PaymentState memory paymentState) = _getPaymentState(payment);

        // Skip if payment has not been collected
        if (!paymentState.hasCollectedPayment) revert PaymentNotCollected();

        // Skip if reward has already been allocated
        if (lastSnapshot[campaign][paymentInfoHash].hasCollectedPayment) revert RewardAlreadyAllocated();

        lastSnapshot[campaign][paymentInfoHash] = paymentState;
        uint256 amount = _calculateCashback(campaign, paymentState.capturableAmount + paymentState.refundableAmount);
        emit CashbackAllocated(campaign, paymentInfoHash, amount);
        return _formatPayouts(payment.payer, amount);
    }

    /// @inheritdoc CampaignHooks
    function onDistribute(address sender, address campaign, address token, bytes calldata data)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        AuthCaptureEscrow.PaymentInfo memory payment = _parseParams(sender, campaign, token, data);
        (bytes32 paymentInfoHash, AuthCaptureEscrow.PaymentState memory paymentState) = _getPaymentState(payment);

        // Skip if reward has not been allocated
        AuthCaptureEscrow.PaymentState memory snapshot = lastSnapshot[campaign][paymentInfoHash];
        if (!snapshot.hasCollectedPayment) revert RewardNotAllocated();

        // Capture was made if refundable amount is more than the last snapshot
        if (paymentState.refundableAmount < snapshot.refundableAmount) revert RefundableAmountDecreased();

        lastSnapshot[campaign][paymentInfoHash] = paymentState;
        uint256 amount = _calculateCashback(campaign, paymentState.refundableAmount - snapshot.refundableAmount);
        emit CashbackDistributed(campaign, paymentInfoHash, amount);
        return _formatPayouts(payment.payer, amount);
    }

    /// @inheritdoc CampaignHooks
    /// @dev Validate sender is campaign cashback manager
    function onWithdrawFunds(address sender, address campaign, address token, uint256 amount, bytes calldata data)
        external
        override
        onlyFlywheel
    {
        if (sender != configs[campaign].manager) revert Unauthorized();
    }

    /// @notice Updates the snapshot for a payment
    ///
    /// @param campaign Address of the campaign
    /// @param paymentInfoHash Hash of the payment info
    function updateSnapshot(address campaign, bytes32 paymentInfoHash) external {
        (bool hasCollectedPayment, uint120 capturableAmount, uint120 refundableAmount) =
            authCaptureEscrow.paymentState(paymentInfoHash);
        lastSnapshot[campaign][paymentInfoHash] = AuthCaptureEscrow.PaymentState({
            hasCollectedPayment: hasCollectedPayment,
            capturableAmount: capturableAmount,
            refundableAmount: refundableAmount
        });
    }

    /// @notice Parses the parameters for the onAllocate and onDistribute functions
    ///
    /// @param sender Address of the sender
    /// @param token Address of the token
    /// @param data Data for the campaign hook
    ///
    /// @return payment Payment info
    function _parseParams(address sender, address campaign, address token, bytes calldata data)
        internal
        view
        returns (AuthCaptureEscrow.PaymentInfo memory payment)
    {
        payment = abi.decode(data, (AuthCaptureEscrow.PaymentInfo));

        // Check sender is manager
        if (sender != configs[campaign].manager) revert Unauthorized();

        // Check token is correct
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
        paymentState = AuthCaptureEscrow.PaymentState({
            hasCollectedPayment: hasCollectedPayment,
            capturableAmount: capturableAmount,
            refundableAmount: refundableAmount
        });
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

    /// @notice Prepares the return values for the onAllocate and onDistribute functions
    ///
    /// @param recipient Address of the recipient
    /// @param amount Amount of cashback to be distributed
    ///
    /// @return payouts Array of payouts to be distributed
    /// @return fee Amount of fee to be paid
    function _formatPayouts(address recipient, uint256 amount)
        internal
        pure
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: recipient, amount: amount});
        return (payouts, 0);
    }
}

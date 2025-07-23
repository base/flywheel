// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";

/// @title CommerceCashback
///
/// @notice Attribution hook for processing commerce payment cashback
///
/// @dev Handles attribution based on payment information from AuthCaptureEscrow
contract CommerceCashback is CampaignHooks {
    /// @notice Maximum basis points (100%)
    uint16 public constant MAX_BPS = 10_000;

    /// @notice Address of the AuthCaptureEscrow contract
    AuthCaptureEscrow public immutable authCaptureEscrow;

    /// @notice Address of the operator who must process payments for this cashback system
    address public immutable operator;

    /// @notice Cashback basis points for calculating payouts
    uint16 public immutable cashbackBps;

    /// @notice Mapping from campaign address to payment info hash to payment state
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

    /// @notice Constructor for CommerceRewards
    ///
    /// @param protocol_ Address of the protocol contract
    /// @param authCaptureEscrow_ Address of the AuthCaptureEscrow contract
    /// @param operator_ Address of the authorized operator
    /// @param cashbackBps_ Cashback basis points for calculating payouts
    constructor(address protocol_, address authCaptureEscrow_, address operator_, uint16 cashbackBps_)
        CampaignHooks(protocol_)
    {
        authCaptureEscrow = AuthCaptureEscrow(authCaptureEscrow_);
        operator = operator_;
        cashbackBps = cashbackBps_;
    }

    /// @inheritdoc CampaignHooks
    /// @dev Decodes payment information and calculates rewards based on payment amounts
    function onAllocate(address sender, address campaign, address payoutToken, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        AuthCaptureEscrow.PaymentInfo memory payment = abi.decode(hookData, (AuthCaptureEscrow.PaymentInfo));

        // Check sender is operator
        if (sender != operator) revert();

        // Check operator is correct
        if (payment.operator != operator) revert();

        // Check token is correct
        if (payment.token != payoutToken) revert();

        bytes32 paymentInfoHash = authCaptureEscrow.getHash(payment);
        (bool hasCollectedPayment, uint120 capturableAmount, uint120 refundableAmount) =
            authCaptureEscrow.paymentState(paymentInfoHash);

        // Skip if payment has not been collected
        if (!hasCollectedPayment) revert();

        // Skip if reward has already been allocated
        if (lastSnapshot[campaign][paymentInfoHash].hasCollectedPayment) revert();
        lastSnapshot[campaign][paymentInfoHash] = AuthCaptureEscrow.PaymentState({
            hasCollectedPayment: hasCollectedPayment,
            capturableAmount: capturableAmount,
            refundableAmount: refundableAmount
        });

        // Calculate payout
        uint256 cashbackAmount = ((capturableAmount + refundableAmount) * cashbackBps) / MAX_BPS;

        // Emit cashback allocated event
        emit CashbackAllocated(campaign, paymentInfoHash, cashbackAmount);

        payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: payment.payer, amount: cashbackAmount});
        return (payouts, 0);
    }

    /// @inheritdoc CampaignHooks
    function onDistribute(address sender, address campaign, address payoutToken, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        AuthCaptureEscrow.PaymentInfo memory payment = abi.decode(hookData, (AuthCaptureEscrow.PaymentInfo));

        // Check sender is operator
        if (sender != operator) revert();

        // Check operator is correct
        if (payment.operator != operator) revert();

        // Check token is correct
        if (payment.token != payoutToken) revert();

        bytes32 paymentInfoHash = authCaptureEscrow.getHash(payment);

        // Skip if reward has not been allocated
        AuthCaptureEscrow.PaymentState memory snapshot = lastSnapshot[campaign][paymentInfoHash];
        if (!snapshot.hasCollectedPayment) revert();

        // Get payment state
        (bool hasCollectedPayment, uint120 capturableAmount, uint120 refundableAmount) =
            authCaptureEscrow.paymentState(paymentInfoHash);
        authCaptureEscrow.paymentState(paymentInfoHash);

        // Capture was made if refundable amount is more than the last snapshot
        if (refundableAmount < snapshot.refundableAmount) revert();

        uint256 cashbackAmount = ((refundableAmount - snapshot.refundableAmount) * cashbackBps) / MAX_BPS;

        lastSnapshot[campaign][paymentInfoHash] = AuthCaptureEscrow.PaymentState({
            hasCollectedPayment: hasCollectedPayment,
            capturableAmount: capturableAmount,
            refundableAmount: refundableAmount
        });

        // Emit cashback distributed event
        emit CashbackDistributed(campaign, paymentInfoHash, cashbackAmount);

        payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: payment.payer, amount: cashbackAmount});
        return (payouts, 0);
    }

    /// @notice Updates the snapshot for a payment
    ///
    /// @param campaign Address of the campaign
    /// @param paymentInfoHash Hash of the payment info
    function updateSnapshot(address campaign, bytes32 paymentInfoHash) public {
        // Get payment state
        (bool hasCollectedPayment, uint120 capturableAmount, uint120 refundableAmount) =
            authCaptureEscrow.paymentState(paymentInfoHash);
        authCaptureEscrow.paymentState(paymentInfoHash);

        lastSnapshot[campaign][paymentInfoHash] = AuthCaptureEscrow.PaymentState({
            hasCollectedPayment: hasCollectedPayment,
            capturableAmount: capturableAmount,
            refundableAmount: refundableAmount
        });
    }
}

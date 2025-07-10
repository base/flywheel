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

    /// @notice Mapping from campaign address to payment info hash to reward status
    mapping(address campaign => mapping(bytes32 paymentInfoHash => bool rewarded)) public rewardedPayments;

    /// @notice Emitted when a payment is rewarded
    ///
    /// @param campaign Address of the campaign
    /// @param paymentInfoHash Hash of the payment info
    /// @param amount Amount of cashback awarded
    event CashbackAwarded(address indexed campaign, bytes32 indexed paymentInfoHash, uint256 amount);

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

    /// @notice Processes attribution for commerce payments
    ///
    /// @param campaign Address of the campaign
    /// @param attributor Address of the attribution provider (unused in this implementation)
    /// @param payoutToken Address of the token to be distributed
    /// @param attributionData Encoded payment information from AuthCaptureEscrow
    ///
    /// @return payouts Array of payouts to be distributed
    ///
    /// @dev Decodes payment information and calculates rewards based on payment amounts
    function _attribute(address campaign, address attributor, address payoutToken, bytes calldata attributionData)
        internal
        override
        returns (Flywheel.Payout[] memory payouts, uint256 attributionFee)
    {
        AuthCaptureEscrow.PaymentInfo[] memory payments = abi.decode(attributionData, (AuthCaptureEscrow.PaymentInfo[]));
        address payer = payments[0].payer;
        uint256 cashbackTotal = 0;
        for (uint256 i = 0; i < payments.length; i++) {
            AuthCaptureEscrow.PaymentInfo memory payment = payments[i];

            // Check operator is trusted
            if (payment.operator != operator) revert();

            // Check token is correct
            if (payment.token != payoutToken) revert();

            // Check payer is correct
            if (payment.payer != payer) revert();

            // Skip if already rewarded
            bytes32 paymentInfoHash = authCaptureEscrow.getHash(payment);
            if (rewardedPayments[campaign][paymentInfoHash]) continue;
            rewardedPayments[campaign][paymentInfoHash] = true;

            // Calculate payout
            (, uint120 capturableAmount, uint120 refundableAmount) = authCaptureEscrow.paymentState(paymentInfoHash);
            uint256 cashbackAmount = ((capturableAmount + refundableAmount) * cashbackBps) / MAX_BPS;
            cashbackTotal += cashbackAmount;

            // Emit cashback awarded event
            emit CashbackAwarded(campaign, paymentInfoHash, cashbackAmount);
        }
        payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: payer, amount: cashbackTotal});
        return (payouts, 0);
    }
}

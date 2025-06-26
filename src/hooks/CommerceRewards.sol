// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../Flywheel.sol";
import {AttributionHook} from "./AttributionHook.sol";
import {MetadataMixin} from "./MetadataMixin.sol";

contract CommerceRewards is AttributionHook, MetadataMixin {
    uint16 public constant MAX_BPS = 10_000;

    /// @notice Address of the AuthCaptureEscrow contract
    AuthCaptureEscrow public immutable authCaptureEscrow;

    /// @notice Address of the operator who must process payments for this rewards system
    address public immutable operator;

    uint16 public immutable rewardBps;

    mapping(address campaign => mapping(bytes32 paymentInfoHash => bool rewarded)) public rewardedPayments;

    constructor(address protocol_, address owner_, address authCaptureEscrow_, address operator_, uint16 rewardBps_)
        AttributionHook(protocol_)
        MetadataMixin(owner_)
    {
        authCaptureEscrow = AuthCaptureEscrow(authCaptureEscrow_);
        operator = operator_;
        rewardBps = rewardBps_;
    }

    function _attribute(address campaign, address attributor, address payoutToken, bytes calldata attributionData)
        internal
        override
        returns (Flywheel.Payout[] memory payouts)
    {
        AuthCaptureEscrow.PaymentInfo[] memory payments = abi.decode(attributionData, (AuthCaptureEscrow.PaymentInfo[]));
        address payer = payments[0].payer;
        uint256 rewardTotal = 0;
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
            rewardTotal += (capturableAmount + refundableAmount) * rewardBps / MAX_BPS;
        }
        payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: payer, amount: rewardTotal});
        return payouts;
    }
}

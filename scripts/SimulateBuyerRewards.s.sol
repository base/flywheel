// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {LibString} from "solady/utils/LibString.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../src/Flywheel.sol";
import {BuyerRewards} from "../src/hooks/BuyerRewards.sol";

contract SimulateBuyerRewards is Script {
    AuthCaptureEscrow public escrow = AuthCaptureEscrow(0xBdEA0D1bcC5966192B070Fdf62aB4EF5b4420cff);
    Flywheel public flywheel = Flywheel(0xB04d55fCc15569B23B8B8C05068C7dAb2B9028D8);
    address public campaign = 0x51419a6C090A50Aa0BBb5400D49E66E5dbe3DcbF;
    address public usdc = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    AuthCaptureEscrow.PaymentInfo paymentInfo;

    function run() external {
        vm.startBroadcast();

        paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: 0xf88e91765F27e4Ae0B7d8257c560EFbEcF239347,
            payer: 0x5dF0cA0E1c27701D72f7d4e3Cf81ACFe848d0194,
            receiver: 0x2B654aB28f82a2a4E4F6DB8e20791E5AcF4125c6,
            token: usdc,
            maxAmount: 1e4,
            preApprovalExpiry: 1914749767655,
            authorizationExpiry: 2014749777655,
            refundExpiry: 2114749787655,
            minFeeBps: 50,
            maxFeeBps: 100,
            feeReceiver: 0x43E7b6EAdE34a87E3962dfC2642c7C0621d362d7,
            salt: 0xeffac98ac06263e5a6e86077982bfc70baf6110ae0d3f22b550da7505a412e75
        });

        // flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        // getPaymentState();
        // flywheel.reward(campaign, usdc, abi.encode(paymentInfo, 1e4));
        flywheel.allocate(campaign, usdc, abi.encode(paymentInfo, 1e4));
        // flywheel.distribute(campaign, usdc, abi.encode(paymentInfo, 1e4));
        flywheel.deallocate(campaign, usdc, abi.encode(paymentInfo, 1e4));

        vm.stopBroadcast();
    }

    function getPaymentState() public view returns (bool, uint120, uint120) {
        (bool hasCollectedPayment, uint120 capturableAmount, uint120 capturedAmount) =
            escrow.paymentState(escrow.getHash(paymentInfo));
        console.log("hasCollectedPayment", hasCollectedPayment);
        console.log("capturableAmount", capturableAmount);
        console.log("capturedAmount", capturedAmount);
        return (hasCollectedPayment, capturableAmount, capturedAmount);
    }
}

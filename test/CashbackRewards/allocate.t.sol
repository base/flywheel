// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {CashbackRewardsBase} from "./CashbackRewardsBase.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";
import {Flywheel} from "../../src/Flywheel.sol";
import {CashbackRewards} from "../../src/hooks/CashbackRewards.sol";

contract AllocateTest is CashbackRewardsBase {
    function test_revertsOnUnauthorizedCaller() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, 100e6);
        bytes memory hookData = createCashbackHookData(paymentInfo, 10e6);

        authorizePayment(paymentInfo);

        // Non-manager tries to allocate - should fail
        vm.prank(buyer);
        vm.expectRevert(CashbackRewards.Unauthorized.selector);
        flywheel.allocate(cashbackCampaign, address(usdc), hookData);
    }

    function test_revertsOnUnauthorizedPayment() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, 100e6);
        uint120 allocateAmount = 10e6;
        bytes memory hookData = createCashbackHookData(paymentInfo, allocateAmount);

        // Don't authorize payment - should revert with NonexistentPayment
        bytes32 paymentInfoHash = escrow.getHash(paymentInfo);
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(CashbackRewards.NonexistentPayment.selector, paymentInfoHash));
        flywheel.allocate(cashbackCampaign, address(usdc), hookData);
    }

    function test_allocate_revertsOnZeroAmount() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, 100e6);
        bytes memory hookData = createCashbackHookData(paymentInfo, 0); // Zero amount

        vm.prank(manager);
        vm.expectRevert(CashbackRewards.ZeroPayoutAmount.selector);
        flywheel.allocate(cashbackCampaign, address(usdc), hookData);
    }

    function test_revertsOnWrongToken() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, 100e6);
        // Create payment info with USDC but call allocate with different token
        paymentInfo.token = address(0x1234); // Wrong token

        bytes memory hookData = createCashbackHookData(paymentInfo, 10e6);

        vm.prank(manager);
        vm.expectRevert(CashbackRewards.InvalidToken.selector);
        flywheel.allocate(cashbackCampaign, address(usdc), hookData); // Calling with USDC but payment expects 0x1234
    }

    function test_revertsOnInsufficientFunds() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, 2000e6);
        uint120 excessiveAllocation = 1001e6; // More than campaign balance (1000 USDC)

        // Must authorize payment first
        authorizePayment(paymentInfo);

        bytes memory hookData = createCashbackHookData(paymentInfo, excessiveAllocation);

        vm.prank(manager);
        vm.expectRevert(Flywheel.InsufficientCampaignFunds.selector);
        flywheel.allocate(cashbackCampaign, address(usdc), hookData);
    }

    function test_successfulAllocation() public {
        // Create a payment for testing
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, 100e6);
        uint120 allocateAmount = 10e6; // 10 USDC allocation

        // Get initial state
        CashbackRewards.RewardsInfo memory initialRewards = getRewardsInfo(paymentInfo, cashbackCampaign);
        uint256 initialCampaignBalance = usdc.balanceOf(cashbackCampaign);

        // Must authorize payment first
        authorizePayment(paymentInfo);

        // Create hook data
        bytes memory hookData = createCashbackHookData(paymentInfo, allocateAmount);

        // Manager allocates funds
        vm.prank(manager);
        (Flywheel.Payout[] memory payouts, uint256 fee) = flywheel.allocate(cashbackCampaign, address(usdc), hookData);

        // Verify allocation tracking
        CashbackRewards.RewardsInfo memory finalRewards = getRewardsInfo(paymentInfo, cashbackCampaign);
        assertEq(finalRewards.allocated, initialRewards.allocated + allocateAmount, "Allocated amount should increase");
        assertEq(finalRewards.distributed, initialRewards.distributed, "Distributed amount should remain unchanged");

        // Verify no tokens transferred (allocation is just reservation)
        assertEq(usdc.balanceOf(cashbackCampaign), initialCampaignBalance, "Campaign balance should not change");

        // Verify payouts (allocation now creates payouts)
        assertEq(payouts.length, 1, "Allocation should return one payout");
        assertEq(payouts[0].recipient, buyer, "Payout recipient should be buyer (payer)");
        assertEq(payouts[0].amount, allocateAmount, "Payout amount should match allocation amount");
        assertEq(fee, 0, "Allocation should have no fee");
    }

    function test_maxCampaignBalance() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, 1000e6);
        uint120 maxAllocation = 1000e6; // Allocate entire campaign balance

        // Must authorize payment first
        authorizePayment(paymentInfo);

        bytes memory hookData = createCashbackHookData(paymentInfo, maxAllocation);

        vm.prank(manager);
        flywheel.allocate(cashbackCampaign, address(usdc), hookData);

        CashbackRewards.RewardsInfo memory rewards = getRewardsInfo(paymentInfo, cashbackCampaign);
        assertEq(rewards.allocated, maxAllocation, "Should handle allocation of full campaign balance");
    }

    function test_emitsFlywheelEvents() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, 100e6);
        uint120 allocateAmount = 10e6;
        bytes memory hookData = createCashbackHookData(paymentInfo, allocateAmount);

        // Must authorize payment first
        authorizePayment(paymentInfo);

        // Expect Flywheel PayoutAllocated event since CashbackRewards creates payouts for allocation
        bytes32 paymentInfoHash = escrow.getHash(paymentInfo);
        vm.expectEmit(true, true, true, true);
        emit Flywheel.PayoutAllocated(
            cashbackCampaign, address(usdc), buyer, allocateAmount, abi.encodePacked(paymentInfoHash)
        );

        vm.prank(manager);
        flywheel.allocate(cashbackCampaign, address(usdc), hookData);
    }
}

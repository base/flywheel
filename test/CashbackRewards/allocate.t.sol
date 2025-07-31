// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {CashbackRewardsBase} from "./CashbackRewardsBase.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";
import {Flywheel} from "../../src/Flywheel.sol";
import {CashbackRewards} from "../../src/hooks/CashbackRewards.sol";

contract AllocateTest is CashbackRewardsBase {
    function test_revertsOnUnauthorizedCaller(uint120 paymentAmount, uint120 allocateAmount, address unauthorizedCaller)
        public
    {
        paymentAmount = uint120(bound(paymentAmount, 1e6, 10_000e6)); // 1-10,000 USDC
        allocateAmount = uint120(bound(allocateAmount, 1, 1000e6)); // 1 wei to 1000 USDC (campaign balance)
        vm.assume(unauthorizedCaller != manager && unauthorizedCaller != address(0));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        bytes memory hookData = createCashbackHookData(paymentInfo, allocateAmount);

        authorizePayment(paymentInfo);

        // Non-manager tries to allocate - should fail
        vm.prank(unauthorizedCaller);
        vm.expectRevert(CashbackRewards.Unauthorized.selector);
        flywheel.allocate(cashbackCampaign, address(usdc), hookData);
    }

    function test_revertsOnUnauthorizedPayment(uint120 paymentAmount, uint120 allocateAmount) public {
        paymentAmount = uint120(bound(paymentAmount, 1e6, 10_000e6)); // 1-10,000 USDC
        allocateAmount = uint120(bound(allocateAmount, 1, 1000e6)); // 1 wei to 1000 USDC (campaign balance)

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
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

    function test_revertsOnWrongToken(uint120 paymentAmount, uint120 allocateAmount, address wrongToken) public {
        paymentAmount = uint120(bound(paymentAmount, 1e6, 10_000e6)); // 1-10,000 USDC
        allocateAmount = uint120(bound(allocateAmount, 1, 1000e6)); // 1 wei to 1000 USDC
        vm.assume(wrongToken != address(usdc) && wrongToken != address(0));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        // Create payment info with wrong token but call allocate with USDC
        paymentInfo.token = wrongToken;

        bytes memory hookData = createCashbackHookData(paymentInfo, allocateAmount);

        vm.prank(manager);
        vm.expectRevert(CashbackRewards.InvalidToken.selector);
        flywheel.allocate(cashbackCampaign, address(usdc), hookData); // Calling with USDC but payment expects wrongToken
    }

    function test_revertsOnInsufficientFunds(uint120 paymentAmount, uint120 excessiveAllocation) public {
        paymentAmount = uint120(bound(paymentAmount, 1001e6, 10_000e6)); // Must be > campaign balance for realism
        excessiveAllocation = uint120(bound(excessiveAllocation, 1001e6, type(uint120).max)); // More than campaign balance (1000 USDC)

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);

        // Must authorize payment first
        authorizePayment(paymentInfo);

        bytes memory hookData = createCashbackHookData(paymentInfo, excessiveAllocation);

        vm.prank(manager);
        vm.expectRevert(Flywheel.InsufficientCampaignFunds.selector);
        flywheel.allocate(cashbackCampaign, address(usdc), hookData);
    }

    function test_successfulAllocation(uint120 paymentAmount, uint120 allocateAmount) public {
        paymentAmount = uint120(bound(paymentAmount, 1e6, 10_000e6)); // 1-10,000 USDC
        allocateAmount = uint120(bound(allocateAmount, 1, 1000e6)); // 1 wei to 1000 USDC (campaign balance)

        // Create a payment for testing
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);

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

    function test_emitsFlywheelEvents(uint120 paymentAmount, uint120 allocateAmount) public {
        paymentAmount = uint120(bound(paymentAmount, 1e6, 10_000e6)); // 1-10,000 USDC
        allocateAmount = uint120(bound(allocateAmount, 1, 1000e6)); // 1 wei to 1000 USDC (campaign balance)

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
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

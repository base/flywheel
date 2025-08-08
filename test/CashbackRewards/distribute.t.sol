// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {CashbackRewardsBase} from "./CashbackRewardsBase.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";
import {Flywheel} from "../../src/Flywheel.sol";
import {CashbackRewards} from "../../src/hooks/CashbackRewards.sol";
import {SimpleRewards} from "../../src/hooks/SimpleRewards.sol";

contract DistributeTest is CashbackRewardsBase {
    function test_revertsOnUnauthorizedCaller(
        uint120 paymentAmount,
        uint120 distributeAmount,
        address unauthorizedCaller
    ) public {
        paymentAmount = uint120(bound(paymentAmount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT));
        distributeAmount = uint120(bound(distributeAmount, MIN_REWARD_AMOUNT, MAX_REWARD_AMOUNT));
        vm.assume(unauthorizedCaller != manager && unauthorizedCaller != address(0));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        bytes memory hookData = createCashbackHookData(paymentInfo, distributeAmount);

        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(unauthorizedCaller);
        flywheel.distribute(cashbackCampaign, address(usdc), hookData);
    }

    function test_revertsOnZeroAmount(uint120 paymentAmount) public {
        paymentAmount = uint120(bound(paymentAmount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        bytes memory hookData = createCashbackHookData(paymentInfo, 0);

        chargePayment(paymentInfo);

        vm.expectRevert(CashbackRewards.ZeroPayoutAmount.selector);
        vm.prank(manager);
        flywheel.distribute(cashbackCampaign, address(usdc), hookData);
    }

    function test_revertsOnWrongToken(uint120 paymentAmount, uint120 distributeAmount, address wrongToken) public {
        paymentAmount = uint120(bound(paymentAmount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT));
        distributeAmount = uint120(bound(distributeAmount, MIN_REWARD_AMOUNT, MAX_REWARD_AMOUNT));
        vm.assume(wrongToken != address(usdc) && wrongToken != address(0));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        paymentInfo.token = wrongToken;

        bytes memory hookData = createCashbackHookData(paymentInfo, distributeAmount);

        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(CashbackRewards.TokenMismatch.selector));
        flywheel.distribute(cashbackCampaign, address(usdc), hookData);
    }

    function test_revertsOnUnauthorizedPayment(uint120 paymentAmount, uint120 distributeAmount) public {
        paymentAmount = uint120(bound(paymentAmount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT));
        distributeAmount = uint120(bound(distributeAmount, MIN_REWARD_AMOUNT, MAX_REWARD_AMOUNT));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        bytes memory hookData = createCashbackHookData(paymentInfo, distributeAmount);

        vm.expectRevert(CashbackRewards.PaymentNotCollected.selector);
        vm.prank(manager);
        flywheel.distribute(cashbackCampaign, address(usdc), hookData);
    }

    function test_revertsOnInsufficientAllocation(uint120 paymentAmount, uint120 distributeAmount) public {
        paymentAmount = uint120(bound(paymentAmount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT));
        distributeAmount = uint120(bound(distributeAmount, MIN_REWARD_AMOUNT, MAX_REWARD_AMOUNT));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        bytes memory hookData = createCashbackHookData(paymentInfo, distributeAmount);

        chargePayment(paymentInfo);

        vm.expectRevert(abi.encodeWithSelector(CashbackRewards.InsufficientAllocation.selector, distributeAmount, 0));
        vm.prank(manager);
        flywheel.distribute(cashbackCampaign, address(usdc), hookData);
    }

    function test_successfulDistribute(uint120 paymentAmount, uint120 distributeAmount) public {
        paymentAmount = uint120(bound(paymentAmount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT));
        distributeAmount = uint120(bound(distributeAmount, MIN_REWARD_AMOUNT, MAX_REWARD_AMOUNT));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        bytes memory allocateHookData = createCashbackHookData(paymentInfo, distributeAmount);
        bytes memory distributeHookData = createCashbackHookData(paymentInfo, distributeAmount);

        chargePayment(paymentInfo);

        vm.prank(manager);
        flywheel.allocate(cashbackCampaign, address(usdc), allocateHookData);

        CashbackRewards.RewardState memory rewardsBefore = getRewardsInfo(paymentInfo, cashbackCampaign);

        vm.prank(manager);
        flywheel.distribute(cashbackCampaign, address(usdc), distributeHookData);

        CashbackRewards.RewardState memory rewardsAfter = getRewardsInfo(paymentInfo, cashbackCampaign);

        assertEq(rewardsAfter.allocated, rewardsBefore.allocated - distributeAmount);
        assertEq(rewardsAfter.distributed, rewardsBefore.distributed + distributeAmount);
    }

    function test_successfulDistributeWithinMaxPercentage(uint120 paymentAmount, uint120 distributeAmount) public {
        paymentAmount = uint120(bound(paymentAmount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT));
        uint120 maxValidDistribute =
            uint120((uint256(paymentAmount) * uint256(TEST_MAX_REWARD_BASIS_POINTS)) / uint256(MAX_BASIS_POINTS));
        distributeAmount = uint120(bound(distributeAmount, MIN_REWARD_AMOUNT, maxValidDistribute));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        bytes memory allocateHookData = createCashbackHookData(paymentInfo, distributeAmount);
        bytes memory distributeHookData = createCashbackHookData(paymentInfo, distributeAmount);

        usdc.mint(restrictedCampaign, maxValidDistribute);
        chargePayment(paymentInfo);

        vm.prank(manager);
        flywheel.allocate(restrictedCampaign, address(usdc), allocateHookData);

        vm.prank(manager);
        flywheel.distribute(restrictedCampaign, address(usdc), distributeHookData);

        CashbackRewards.RewardState memory rewards = getRewardsInfo(paymentInfo, restrictedCampaign);
        assertEq(rewards.distributed, distributeAmount);
    }

    function test_partialDistribution(uint120 paymentAmount, uint120 allocationAmount, uint120 distributionAmount)
        public
    {
        paymentAmount = uint120(bound(paymentAmount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT));
        allocationAmount = uint120(bound(allocationAmount, MIN_ALLOCATION_AMOUNT, MAX_ALLOCATION_AMOUNT));
        distributionAmount = uint120(bound(distributionAmount, MIN_REWARD_AMOUNT, allocationAmount));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        bytes memory allocateHookData = createCashbackHookData(paymentInfo, allocationAmount);
        bytes memory distributeHookData = createCashbackHookData(paymentInfo, distributionAmount);

        chargePayment(paymentInfo);

        vm.prank(manager);
        flywheel.allocate(cashbackCampaign, address(usdc), allocateHookData);

        vm.prank(manager);
        flywheel.distribute(cashbackCampaign, address(usdc), distributeHookData);

        CashbackRewards.RewardState memory rewards = getRewardsInfo(paymentInfo, cashbackCampaign);
        assertEq(rewards.allocated, allocationAmount - distributionAmount);
        assertEq(rewards.distributed, distributionAmount);
    }

    function test_multipleDistributions(
        uint120 paymentAmount,
        uint120 allocationAmount,
        uint120 firstDistribution,
        uint120 secondDistribution
    ) public {
        paymentAmount = uint120(bound(paymentAmount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT));
        allocationAmount = uint120(bound(allocationAmount, MIN_ALLOCATION_AMOUNT, MAX_ALLOCATION_AMOUNT));
        firstDistribution = uint120(bound(firstDistribution, MIN_REWARD_AMOUNT, allocationAmount / 2));
        secondDistribution = uint120(bound(secondDistribution, MIN_REWARD_AMOUNT, allocationAmount - firstDistribution));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        bytes memory allocateHookData = createCashbackHookData(paymentInfo, allocationAmount);

        chargePayment(paymentInfo);

        vm.prank(manager);
        flywheel.allocate(cashbackCampaign, address(usdc), allocateHookData);

        bytes memory firstDistributeHookData = createCashbackHookData(paymentInfo, firstDistribution);
        vm.prank(manager);
        flywheel.distribute(cashbackCampaign, address(usdc), firstDistributeHookData);

        bytes memory secondDistributeHookData = createCashbackHookData(paymentInfo, secondDistribution);
        vm.prank(manager);
        flywheel.distribute(cashbackCampaign, address(usdc), secondDistributeHookData);

        CashbackRewards.RewardState memory rewards = getRewardsInfo(paymentInfo, cashbackCampaign);
        assertEq(rewards.allocated, allocationAmount - firstDistribution - secondDistribution);
        assertEq(rewards.distributed, firstDistribution + secondDistribution);
    }

    function test_batchDistributeMultiplePayments(
        uint120 firstPaymentAmount,
        uint120 secondPaymentAmount,
        uint120 firstAllocation,
        uint120 secondAllocation,
        uint120 firstDistribute,
        uint120 secondDistribute
    ) public {
        // Use reasonable bounds to ensure buyer can afford both payments
        firstPaymentAmount = uint120(bound(firstPaymentAmount, MIN_PAYMENT_AMOUNT, 1000000e6)); // Max 1M USDC
        secondPaymentAmount = uint120(bound(secondPaymentAmount, MIN_PAYMENT_AMOUNT, 1000000e6)); // Max 1M USDC
        firstAllocation = uint120(bound(firstAllocation, MIN_REWARD_AMOUNT, MAX_REWARD_AMOUNT / 2));
        secondAllocation = uint120(bound(secondAllocation, MIN_REWARD_AMOUNT, MAX_REWARD_AMOUNT / 2));
        firstDistribute = uint120(bound(firstDistribute, MIN_REWARD_AMOUNT, firstAllocation));
        secondDistribute = uint120(bound(secondDistribute, MIN_REWARD_AMOUNT, secondAllocation));

        // Create two different payments
        AuthCaptureEscrow.PaymentInfo memory firstPayment = createPaymentInfo(buyer, firstPaymentAmount);
        firstPayment.salt = uint256(keccak256("first_payment"));

        AuthCaptureEscrow.PaymentInfo memory secondPayment = createPaymentInfo(buyer, secondPaymentAmount);
        secondPayment.salt = uint256(keccak256("second_payment"));

        // Charge both payments and allocate rewards
        chargePayment(firstPayment);
        chargePayment(secondPayment);

        // Allocate rewards for both payments
        bytes memory firstAllocateData = createCashbackHookData(firstPayment, firstAllocation);
        bytes memory secondAllocateData = createCashbackHookData(secondPayment, secondAllocation);

        vm.prank(manager);
        flywheel.allocate(cashbackCampaign, address(usdc), firstAllocateData);
        vm.prank(manager);
        flywheel.allocate(cashbackCampaign, address(usdc), secondAllocateData);

        // Create batch distribution hook data
        CashbackRewards.PaymentReward[] memory paymentRewards = new CashbackRewards.PaymentReward[](2);
        paymentRewards[0] = CashbackRewards.PaymentReward({paymentInfo: firstPayment, payoutAmount: firstDistribute});
        paymentRewards[1] = CashbackRewards.PaymentReward({paymentInfo: secondPayment, payoutAmount: secondDistribute});
        bytes memory batchHookData = abi.encode(paymentRewards);

        // Get initial states
        CashbackRewards.RewardState memory firstRewardsBefore = getRewardsInfo(firstPayment, cashbackCampaign);
        CashbackRewards.RewardState memory secondRewardsBefore = getRewardsInfo(secondPayment, cashbackCampaign);

        // Execute batch distribution
        vm.prank(manager);
        flywheel.distribute(cashbackCampaign, address(usdc), batchHookData);

        // Verify both distributions were processed
        CashbackRewards.RewardState memory firstRewardsAfter = getRewardsInfo(firstPayment, cashbackCampaign);
        CashbackRewards.RewardState memory secondRewardsAfter = getRewardsInfo(secondPayment, cashbackCampaign);

        assertEq(firstRewardsAfter.allocated, firstRewardsBefore.allocated - firstDistribute);
        assertEq(firstRewardsAfter.distributed, firstRewardsBefore.distributed + firstDistribute);
        assertEq(secondRewardsAfter.allocated, secondRewardsBefore.allocated - secondDistribute);
        assertEq(secondRewardsAfter.distributed, secondRewardsBefore.distributed + secondDistribute);
    }

    function test_emitsFlywheelEvents(uint120 paymentAmount, uint120 distributeAmount) public {
        paymentAmount = uint120(bound(paymentAmount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT));
        distributeAmount = uint120(bound(distributeAmount, MIN_REWARD_AMOUNT, MAX_REWARD_AMOUNT));

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = createPaymentInfo(buyer, paymentAmount);
        bytes memory allocateHookData = createCashbackHookData(paymentInfo, distributeAmount);
        bytes memory distributeHookData = createCashbackHookData(paymentInfo, distributeAmount);

        chargePayment(paymentInfo);

        vm.prank(manager);
        flywheel.allocate(cashbackCampaign, address(usdc), allocateHookData);

        bytes32 paymentInfoHash = escrow.getHash(paymentInfo);
        vm.expectEmit(true, true, true, true);
        emit Flywheel.PayoutsDistributed(
            cashbackCampaign, address(usdc), buyer, distributeAmount, abi.encodePacked(paymentInfoHash)
        );

        vm.prank(manager);
        flywheel.distribute(cashbackCampaign, address(usdc), distributeHookData);
    }
}

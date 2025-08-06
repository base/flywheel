// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../src/Flywheel.sol";
import {BuyerRewards} from "../src/hooks/BuyerRewards.sol";
import {SimpleRewards} from "../src/hooks/SimpleRewards.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";

contract BuyerRewardsTest is Test {
    Flywheel public flywheel;
    BuyerRewards public hook;
    AuthCaptureEscrow public escrow;
    DummyERC20 public token;

    address public owner = address(0x1000);
    address public manager = address(0x2000);
    address public payer = address(0x3000);
    address public merchant = address(0x4000);

    address public campaign;
    uint256 public constant INITIAL_TOKEN_BALANCE = 1000e18;
    uint120 public constant CASHBACK_AMOUNT = 100e18;

    function setUp() public {
        // Deploy contracts
        flywheel = new Flywheel();
        escrow = new AuthCaptureEscrow();
        hook = new BuyerRewards(address(flywheel), address(escrow));

        // Deploy token with initial holders
        address[] memory initialHolders = new address[](2);
        initialHolders[0] = owner;
        initialHolders[1] = address(this);
        token = new DummyERC20(initialHolders);

        // Create campaign
        bytes memory hookData = abi.encode(owner, manager, "https://api.example.com/campaign", 0);

        campaign = flywheel.createCampaign(address(hook), 1, hookData);
    }

    // NOTE: Core campaign creation is tested in Flywheel.t.sol
    // This focuses on BuyerRewards-specific campaign setup and verification

    function test_reward_success() public {
        // Create and collect payment in escrow
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12345
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);

        // Mock payment collection in escrow
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, paymentHash),
            abi.encode(true, false, false) // hasCollectedPayment = true
        );

        // Fund campaign
        vm.prank(owner);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        // Activate campaign
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Process reward
        BuyerRewards.PaymentReward[] memory paymentRewards = new BuyerRewards.PaymentReward[](1);
        paymentRewards[0] = BuyerRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: CASHBACK_AMOUNT});
        bytes memory hookData = abi.encode(paymentRewards);

        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // Verify payer received cashback
        assertEq(token.balanceOf(payer), CASHBACK_AMOUNT);

        // Verify rewards info tracking
        (uint120 allocated, uint120 distributed) = hook.rewards(campaign, paymentHash);
        assertEq(allocated, 0);
        assertEq(distributed, CASHBACK_AMOUNT);
    }

    // NOTE: Core allocate/distribute/deallocate functionality is tested in Flywheel.t.sol
    // This hook focuses on BuyerRewards-specific behavior (payment verification, etc.)

    function test_onlyManager_canCallPayoutFunctions() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12347
        });

        BuyerRewards.PaymentReward[] memory paymentRewards = new BuyerRewards.PaymentReward[](1);
        paymentRewards[0] = BuyerRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: CASHBACK_AMOUNT});
        bytes memory hookData = abi.encode(paymentRewards);

        // Fund and activate campaign
        vm.prank(owner);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Owner cannot call payout functions
        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(owner);
        flywheel.reward(campaign, address(token), hookData);

        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(owner);
        flywheel.allocate(campaign, address(token), hookData);

        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(owner);
        flywheel.deallocate(campaign, address(token), hookData);

        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(owner);
        flywheel.distribute(campaign, address(token), hookData);
    }

    function test_onlyOwner_canWithdrawFunds() public {
        // Fund campaign
        vm.prank(owner);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        // Finalize campaign
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");

        // Owner can withdraw
        vm.prank(owner);
        flywheel.withdrawFunds(campaign, address(token), INITIAL_TOKEN_BALANCE, "");

        // Manager cannot withdraw
        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(manager);
        flywheel.withdrawFunds(campaign, address(token), 0, "");
    }

    function test_revert_paymentNotCollected() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12348
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);

        // Mock payment NOT collected
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, paymentHash),
            abi.encode(false, false, false) // hasCollectedPayment = false
        );

        // Fund and activate campaign
        vm.prank(owner);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        BuyerRewards.PaymentReward[] memory paymentRewards = new BuyerRewards.PaymentReward[](1);
        paymentRewards[0] = BuyerRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: CASHBACK_AMOUNT});
        bytes memory hookData = abi.encode(paymentRewards);

        // Should revert when payment not collected
        vm.expectRevert(BuyerRewards.PaymentNotCollected.selector);
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);
    }

    function test_revert_zeroPayoutAmount() public {
        // Fund and activate campaign first
        vm.prank(owner);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12349
        });

        BuyerRewards.PaymentReward[] memory paymentRewards = new BuyerRewards.PaymentReward[](1);
        paymentRewards[0] = BuyerRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: 0});
        bytes memory hookData = abi.encode(paymentRewards);

        // Should revert with zero payout amount
        vm.expectRevert(BuyerRewards.ZeroPayoutAmount.selector);
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);
    }

    function test_revert_insufficientAllocation() public {
        // Try to distribute more than allocated
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12350
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);

        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, paymentHash),
            abi.encode(true, false, false)
        );

        // Fund and activate campaign
        vm.prank(owner);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Allocate small amount
        BuyerRewards.PaymentReward[] memory allocateRewards = new BuyerRewards.PaymentReward[](1);
        allocateRewards[0] = BuyerRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(50e18)});
        bytes memory allocateData = abi.encode(allocateRewards);
        vm.prank(manager);
        flywheel.allocate(campaign, address(token), allocateData);

        // Try to distribute larger amount
        BuyerRewards.PaymentReward[] memory distributeRewards = new BuyerRewards.PaymentReward[](1);
        distributeRewards[0] = BuyerRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: CASHBACK_AMOUNT}); // 100e18 > 50e18
        bytes memory distributeData = abi.encode(distributeRewards);

        vm.expectRevert(abi.encodeWithSelector(BuyerRewards.InsufficientAllocation.selector, CASHBACK_AMOUNT, 50e18));
        vm.prank(manager);
        flywheel.distribute(campaign, address(token), distributeData);
    }

    function test_campaignCreatedEvent() public {
        // Create new campaign and check event
        bytes memory hookData = abi.encode(owner, manager, "https://api.example.com/new-campaign", 0);

        // Calculate expected campaign address
        address expectedCampaign = flywheel.campaignAddress(address(hook), 2, hookData);

        vm.expectEmit(true, false, false, true);
        emit SimpleRewards.CampaignCreated(expectedCampaign, owner, manager, "https://api.example.com/new-campaign");

        address newCampaign = flywheel.createCampaign(address(hook), 2, hookData);

        // Verify campaign created
        assertEq(newCampaign, expectedCampaign);
        assertEq(hook.owners(newCampaign), owner);
        assertEq(hook.managers(newCampaign), manager);
    }

    // =============================================================
    //                    INTEGRATION TESTS
    // =============================================================

    function test_endToEndBuyerRewardsFlow() public {
        // Integration test for complete BuyerRewards workflow

        // Setup - Deploy additional tokens for proper separation
        address[] memory usdcHolders = new address[](3);
        usdcHolders[0] = owner;
        usdcHolders[1] = payer;
        usdcHolders[2] = makeAddr("buyer2");

        address[] memory rewardHolders = new address[](1);
        rewardHolders[0] = owner; // Only owner gets initial reward tokens

        DummyERC20 usdc = new DummyERC20(usdcHolders);
        DummyERC20 rewardToken = new DummyERC20(rewardHolders);

        uint256 INITIAL_FUNDING = 50000e18;
        uint256 CASHBACK_RATE_BPS = 500; // 5% cashback
        uint256 PURCHASE_AMOUNT = 1000e6; // 1,000 USDC

        // Create campaign with reward token
        vm.prank(owner);
        rewardToken.transfer(campaign, INITIAL_FUNDING);

        // 1. Verify initial setup
        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.INACTIVE));
        assertEq(rewardToken.balanceOf(campaign), INITIAL_FUNDING);
        assertEq(rewardToken.balanceOf(payer), 0);

        // 2. Activate campaign
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.ACTIVE));

        // 3. Simulate first buyer purchase and immediate cashback
        bytes32 payment1Hash = keccak256(abi.encodePacked("payment_1", payer, block.timestamp));
        uint256 cashbackAmount1 = PURCHASE_AMOUNT * CASHBACK_RATE_BPS / 10000;

        AuthCaptureEscrow.PaymentInfo memory paymentInfo1 = AuthCaptureEscrow.PaymentInfo({
            operator: manager,
            payer: payer,
            receiver: merchant,
            token: address(usdc),
            maxAmount: uint120(PURCHASE_AMOUNT),
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: uint256(payment1Hash)
        });

        // Simulate payment collection
        vm.startPrank(payer);
        usdc.approve(address(escrow), PURCHASE_AMOUNT);
        usdc.transfer(address(escrow), PURCHASE_AMOUNT);
        vm.stopPrank();

        // Mock escrow payment verification
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(AuthCaptureEscrow.getHash.selector, paymentInfo1),
            abi.encode(payment1Hash)
        );

        vm.mockCall(
            address(escrow),
            abi.encodeWithSignature("paymentState(bytes32)", payment1Hash),
            abi.encode(true, uint120(0), uint120(PURCHASE_AMOUNT))
        );

        BuyerRewards.PaymentReward[] memory paymentRewards1 = new BuyerRewards.PaymentReward[](1);
        paymentRewards1[0] =
            BuyerRewards.PaymentReward({paymentInfo: paymentInfo1, payoutAmount: uint120(cashbackAmount1)});
        bytes memory rewardData = abi.encode(paymentRewards1);

        vm.prank(manager);
        flywheel.reward(campaign, address(usdc), rewardData);

        // Verify immediate cashback
        assertEq(usdc.balanceOf(payer), cashbackAmount1);

        // 4. Simulate second buyer purchase with allocate/distribute workflow
        address buyer2 = makeAddr("buyer2");
        bytes32 payment2Hash = keccak256(abi.encodePacked("payment_2", buyer2, block.timestamp));
        uint256 cashbackAmount2 = (PURCHASE_AMOUNT * 2) * CASHBACK_RATE_BPS / 10000;

        AuthCaptureEscrow.PaymentInfo memory paymentInfo2 = AuthCaptureEscrow.PaymentInfo({
            operator: manager,
            payer: buyer2,
            receiver: merchant,
            token: address(usdc),
            maxAmount: uint120(PURCHASE_AMOUNT * 2),
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: uint256(payment2Hash)
        });

        // Simulate payment collection for buyer2
        vm.startPrank(buyer2);
        usdc.approve(address(escrow), PURCHASE_AMOUNT * 2);
        usdc.transfer(address(escrow), PURCHASE_AMOUNT * 2);
        vm.stopPrank();

        // Mock escrow payment verification for buyer2
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(AuthCaptureEscrow.getHash.selector, paymentInfo2),
            abi.encode(payment2Hash)
        );

        vm.mockCall(
            address(escrow),
            abi.encodeWithSignature("paymentState(bytes32)", payment2Hash),
            abi.encode(true, uint120(0), uint120(PURCHASE_AMOUNT * 2))
        );

        BuyerRewards.PaymentReward[] memory paymentRewards2 = new BuyerRewards.PaymentReward[](1);
        paymentRewards2[0] =
            BuyerRewards.PaymentReward({paymentInfo: paymentInfo2, payoutAmount: uint120(cashbackAmount2)});
        bytes memory allocateData = abi.encode(paymentRewards2);

        // Allocate cashback (reserve for later claim)
        vm.prank(manager);
        flywheel.allocate(campaign, address(usdc), allocateData);

        // Verify allocation (buyer2 hasn't received tokens yet)
        assertEq(usdc.balanceOf(buyer2), 0);

        // 5. Buyer2 claims allocated cashback
        vm.prank(manager);
        flywheel.distribute(campaign, address(usdc), allocateData);

        // Verify distribution
        assertEq(usdc.balanceOf(buyer2), cashbackAmount2);

        // 6. Finalize campaign
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");

        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.FINALIZED));

        // 7. Owner withdraws remaining funds
        uint256 remainingFunds = rewardToken.balanceOf(campaign);
        uint256 ownerBalanceBefore = rewardToken.balanceOf(owner);

        vm.prank(owner);
        flywheel.withdrawFunds(campaign, address(usdc), remainingFunds, "");

        assertEq(usdc.balanceOf(campaign), 0);
        assertEq(usdc.balanceOf(owner), ownerBalanceBefore + remainingFunds);
    }

    function test_authCaptureEscrowIntegration() public {
        // Test the integration with AuthCaptureEscrow for payment verification

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        vm.prank(owner);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        // Create a payment hash and simulate payment collection
        bytes32 paymentHash = keccak256(abi.encodePacked("test_payment", payer, block.timestamp));
        uint256 PURCHASE_AMOUNT = 1000e6;
        uint256 CASHBACK_RATE_BPS = 500; // 5%

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: manager,
            payer: payer,
            receiver: merchant,
            token: address(token),
            maxAmount: uint120(PURCHASE_AMOUNT),
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: uint256(paymentHash)
        });

        // Mock escrow verification
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(AuthCaptureEscrow.getHash.selector, paymentInfo),
            abi.encode(paymentHash)
        );

        vm.mockCall(
            address(escrow),
            abi.encodeWithSignature("paymentState(bytes32)", paymentHash),
            abi.encode(true, uint120(0), uint120(PURCHASE_AMOUNT))
        );

        uint256 cashbackAmount = PURCHASE_AMOUNT * CASHBACK_RATE_BPS / 10000;
        BuyerRewards.PaymentReward[] memory paymentRewards = new BuyerRewards.PaymentReward[](1);
        paymentRewards[0] =
            BuyerRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(cashbackAmount)});
        bytes memory hookData = abi.encode(paymentRewards);

        // Test reward with payment verification
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        assertEq(token.balanceOf(payer), cashbackAmount);

        // Test that uncollected payment would fail
        bytes32 uncollectedHash = keccak256(abi.encodePacked("uncollected_payment", makeAddr("buyer2")));

        // Mock uncollected payment state
        vm.mockCall(
            address(escrow),
            abi.encodeWithSignature("paymentState(bytes32)", uncollectedHash),
            abi.encode(false, uint120(0), uint120(0)) // hasCollectedPayment=false
        );

        AuthCaptureEscrow.PaymentInfo memory uncollectedPayment = AuthCaptureEscrow.PaymentInfo({
            operator: manager,
            payer: makeAddr("buyer2"),
            receiver: merchant,
            token: address(token),
            maxAmount: uint120(PURCHASE_AMOUNT),
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: uint256(uncollectedHash)
        });

        BuyerRewards.PaymentReward[] memory uncollectedRewards = new BuyerRewards.PaymentReward[](1);
        uncollectedRewards[0] =
            BuyerRewards.PaymentReward({paymentInfo: uncollectedPayment, payoutAmount: uint120(cashbackAmount)});
        bytes memory uncollectedData = abi.encode(uncollectedRewards);

        // Should revert because payment not collected
        vm.expectRevert(BuyerRewards.PaymentNotCollected.selector);
        vm.prank(manager);
        flywheel.reward(campaign, address(token), uncollectedData);
    }

    function test_multiTokenCashback() public {
        // Test cashback campaigns with multiple reward tokens

        // Deploy additional reward token
        address[] memory holders = new address[](1);
        holders[0] = owner;
        DummyERC20 bonusToken = new DummyERC20(holders);

        // Fund campaign with both tokens
        vm.startPrank(owner);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);
        bonusToken.transfer(campaign, 10000e18);
        vm.stopPrank();

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Simulate payment
        bytes32 paymentHash = keccak256(abi.encodePacked("multi_token_payment", payer));
        uint256 PURCHASE_AMOUNT = 1000e6;

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: manager,
            payer: payer,
            receiver: merchant,
            token: address(token),
            maxAmount: uint120(PURCHASE_AMOUNT),
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: uint256(paymentHash)
        });

        // Mock escrow verification
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(AuthCaptureEscrow.getHash.selector, paymentInfo),
            abi.encode(paymentHash)
        );

        vm.mockCall(
            address(escrow),
            abi.encodeWithSignature("paymentState(bytes32)", paymentHash),
            abi.encode(true, uint120(0), uint120(PURCHASE_AMOUNT))
        );

        // Give cashback in both tokens
        uint256 mainCashback = PURCHASE_AMOUNT * 500 / 10000; // 5%
        uint256 bonusCashback = 100e6; // Fixed bonus amount

        BuyerRewards.PaymentReward[] memory mainRewards = new BuyerRewards.PaymentReward[](1);
        mainRewards[0] = BuyerRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(mainCashback)});
        bytes memory mainRewardData = abi.encode(mainRewards);

        BuyerRewards.PaymentReward[] memory bonusRewards = new BuyerRewards.PaymentReward[](1);
        bonusRewards[0] = BuyerRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(bonusCashback)});
        bytes memory bonusRewardData = abi.encode(bonusRewards);

        vm.startPrank(manager);
        flywheel.reward(campaign, address(token), mainRewardData);
        flywheel.reward(campaign, address(bonusToken), bonusRewardData);
        vm.stopPrank();

        // Verify both cashbacks received
        assertEq(token.balanceOf(payer), mainCashback);
        assertEq(bonusToken.balanceOf(payer), bonusCashback);
    }
}

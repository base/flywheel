// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../src/Flywheel.sol";
import {BuyerRewards} from "../src/hooks/BuyerRewards.sol";
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
    uint256 public constant CASHBACK_AMOUNT = 100e18;

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
        bytes memory hookData = abi.encode(
            owner,
            manager,
            "https://api.example.com/campaign"
        );

        campaign = flywheel.createCampaign(address(hook), 1, hookData);
    }

    function test_createCampaign() public {
        // Verify campaign was created correctly
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.INACTIVE));
        assertEq(hook.owners(campaign), owner);
        assertEq(hook.managers(campaign), manager);
        assertEq(hook.campaignURI(campaign), "https://api.example.com/campaign");
    }

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
        bytes memory hookData = abi.encode(paymentInfo, CASHBACK_AMOUNT);
        
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // Verify payer received cashback
        assertEq(token.balanceOf(payer), CASHBACK_AMOUNT);
        
        // Verify rewards info tracking
        (uint120 allocated, uint120 distributed) = hook.rewardsInfo(paymentHash, campaign);
        assertEq(allocated, 0);
        assertEq(distributed, CASHBACK_AMOUNT);
    }

    function test_allocate_success() public {
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
            salt: 12346
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);
        
        // Mock payment collection
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

        // Allocate cashback
        bytes memory hookData = abi.encode(paymentInfo, CASHBACK_AMOUNT);
        
        vm.prank(manager);
        flywheel.allocate(campaign, address(token), hookData);

        // Verify allocation tracking (no tokens transferred yet)
        assertEq(token.balanceOf(payer), 0);
        
        // Verify allocation tracked in BuyerRewards hook state
        (uint120 allocated, uint120 distributed) = hook.rewardsInfo(paymentHash, campaign);
        assertEq(allocated, CASHBACK_AMOUNT);
        assertEq(distributed, 0);
        
        // Verify allocation tracked in core Flywheel state
        assertEq(flywheel.allocations(campaign, address(token), payer), CASHBACK_AMOUNT);
    }

    function test_distribute_success() public {
        // First allocate
        test_allocate_success();

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
            salt: 12346
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);

        // Now distribute the allocated amount
        bytes memory hookData = abi.encode(paymentInfo, CASHBACK_AMOUNT);
        
        vm.prank(manager);
        flywheel.distribute(campaign, address(token), hookData);

        // Verify payer received tokens
        assertEq(token.balanceOf(payer), CASHBACK_AMOUNT);
        
        // Verify tracking updated in BuyerRewards hook state
        (uint120 allocated, uint120 distributed) = hook.rewardsInfo(paymentHash, campaign);
        assertEq(allocated, 0); // Moved from allocated to distributed
        assertEq(distributed, CASHBACK_AMOUNT);
        
        // Verify allocation removed from core Flywheel state after distribution
        assertEq(flywheel.allocations(campaign, address(token), payer), 0);
    }

    function test_deallocate_success() public {
        // First allocate
        test_allocate_success();

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
            salt: 12346
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);

        // Deallocate the amount
        bytes memory hookData = abi.encode(paymentInfo, CASHBACK_AMOUNT);
        
        vm.prank(manager);
        flywheel.deallocate(campaign, address(token), hookData);

        // Verify no tokens transferred to payer
        assertEq(token.balanceOf(payer), 0);
        
        // Verify allocation removed from BuyerRewards hook state
        (uint120 allocated, uint120 distributed) = hook.rewardsInfo(paymentHash, campaign);
        assertEq(allocated, 0);
        assertEq(distributed, 0);
        
        // Verify allocation removed from core Flywheel state
        assertEq(flywheel.allocations(campaign, address(token), payer), 0);
    }

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

        bytes memory hookData = abi.encode(paymentInfo, CASHBACK_AMOUNT);

        // Fund and activate campaign
        vm.prank(owner);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);
        
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Owner cannot call payout functions
        vm.expectRevert(BuyerRewards.Unauthorized.selector);
        vm.prank(owner);
        flywheel.reward(campaign, address(token), hookData);

        vm.expectRevert(BuyerRewards.Unauthorized.selector);
        vm.prank(owner);
        flywheel.allocate(campaign, address(token), hookData);
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
        vm.expectRevert(BuyerRewards.Unauthorized.selector);
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

        bytes memory hookData = abi.encode(paymentInfo, CASHBACK_AMOUNT);

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

        bytes memory hookData = abi.encode(paymentInfo, 0); // Zero amount

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
        bytes memory allocateData = abi.encode(paymentInfo, 50e18);
        vm.prank(manager);
        flywheel.allocate(campaign, address(token), allocateData);

        // Try to distribute larger amount
        bytes memory distributeData = abi.encode(paymentInfo, CASHBACK_AMOUNT); // 100e18 > 50e18
        
        vm.expectRevert(abi.encodeWithSelector(BuyerRewards.InsufficientAllocation.selector, CASHBACK_AMOUNT, 50e18));
        vm.prank(manager);
        flywheel.distribute(campaign, address(token), distributeData);
    }

    function test_campaignCreatedEvent() public {
        // Create new campaign and check event
        bytes memory hookData = abi.encode(
            owner,
            manager,
            "https://api.example.com/new-campaign"
        );

        // Calculate expected campaign address
        address expectedCampaign = flywheel.campaignAddress(2, hookData);

        vm.expectEmit(true, false, false, true);
        emit BuyerRewards.CampaignCreated(expectedCampaign, owner, manager, "https://api.example.com/new-campaign");

        address newCampaign = flywheel.createCampaign(address(hook), 2, hookData);
        
        // Verify campaign created
        assertEq(newCampaign, expectedCampaign);
        assertEq(hook.owners(newCampaign), owner);
        assertEq(hook.managers(newCampaign), manager);
    }
}
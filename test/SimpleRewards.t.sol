// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";

import {Flywheel} from "../src/Flywheel.sol";
import {SimpleRewards} from "../src/hooks/SimpleRewards.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";

contract SimpleRewardsTest is Test {
    Flywheel public flywheel;
    SimpleRewards public hook;
    DummyERC20 public token;

    address public manager = address(0x1000);
    address public randomUser = address(0x2000);
    address public recipient1 = address(0x3000);
    address public recipient2 = address(0x4000);

    address public campaign;
    uint256 public constant INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 public constant PAYOUT_AMOUNT = 100e18;

    function setUp() public {
        // Deploy contracts
        flywheel = new Flywheel();
        hook = new SimpleRewards(address(flywheel));

        // Deploy token with initial holders
        address[] memory initialHolders = new address[](2);
        initialHolders[0] = manager;
        initialHolders[1] = address(this);
        token = new DummyERC20(initialHolders);

        // Create campaign
        bytes memory hookData = abi.encode(manager);
        campaign = flywheel.createCampaign(address(hook), 1, hookData);
    }

    function test_createCampaign() public {
        // Verify campaign was created correctly
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.INACTIVE));
        assertEq(hook.managers(campaign), manager);
    }

    function test_reward_success() public {
        // Fund campaign
        vm.prank(manager);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        // Activate campaign
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Create payout data
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](2);
        payouts[0] = Flywheel.Payout({
            recipient: recipient1,
            amount: PAYOUT_AMOUNT,
            extraData: ""
        });
        payouts[1] = Flywheel.Payout({
            recipient: recipient2,
            amount: PAYOUT_AMOUNT / 2,
            extraData: ""
        });

        bytes memory hookData = abi.encode(payouts);

        // Process reward
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // Verify recipients received tokens
        assertEq(token.balanceOf(recipient1), PAYOUT_AMOUNT);
        assertEq(token.balanceOf(recipient2), PAYOUT_AMOUNT / 2);
    }

    function test_allocate_success() public {
        // Fund and activate campaign
        vm.prank(manager);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Create payout data
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: recipient1,
            amount: PAYOUT_AMOUNT,
            extraData: ""
        });

        bytes memory hookData = abi.encode(payouts);

        // Allocate payout
        vm.prank(manager);
        flywheel.allocate(campaign, address(token), hookData);

        // Verify no tokens transferred yet (allocation only)
        assertEq(token.balanceOf(recipient1), 0);
        
        // Verify allocation was recorded in core Flywheel state
        assertEq(flywheel.allocations(campaign, address(token), recipient1), PAYOUT_AMOUNT);
        
        // Note: SimpleRewards doesn't track allocations internally like BuyerRewards
        // It just passes through the payout data to the core Flywheel
    }

    function test_distribute_success() public {
        // First allocate
        test_allocate_success();

        // Create same payout data for distribution
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: recipient1,
            amount: PAYOUT_AMOUNT,
            extraData: ""
        });

        bytes memory hookData = abi.encode(payouts);

        // Distribute the allocated amount
        vm.prank(manager);
        flywheel.distribute(campaign, address(token), hookData);

        // Verify recipient received tokens
        assertEq(token.balanceOf(recipient1), PAYOUT_AMOUNT);
        
        // Verify allocation was removed from core Flywheel state after distribution
        assertEq(flywheel.allocations(campaign, address(token), recipient1), 0);
    }

    function test_deallocate_success() public {
        // First allocate
        test_allocate_success();

        // Create payout data for deallocation
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: recipient1,
            amount: PAYOUT_AMOUNT,
            extraData: ""
        });

        bytes memory hookData = abi.encode(payouts);

        // Deallocate the amount
        vm.prank(manager);
        flywheel.deallocate(campaign, address(token), hookData);

        // Verify no tokens transferred to recipient
        assertEq(token.balanceOf(recipient1), 0);
        
        // Verify allocation state was actually updated (decreased to zero)
        assertEq(flywheel.allocations(campaign, address(token), recipient1), 0);
    }

    function test_onlyManager_canCallPayoutFunctions() public {
        // Fund and activate campaign
        vm.prank(manager);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);
        
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Create payout data
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: recipient1,
            amount: PAYOUT_AMOUNT,
            extraData: ""
        });

        bytes memory hookData = abi.encode(payouts);

        // Random user cannot call payout functions
        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(randomUser);
        flywheel.reward(campaign, address(token), hookData);

        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(randomUser);
        flywheel.allocate(campaign, address(token), hookData);

        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(randomUser);
        flywheel.distribute(campaign, address(token), hookData);

        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(randomUser);
        flywheel.deallocate(campaign, address(token), hookData);
    }

    function test_onlyManager_canUpdateStatus() public {
        // Manager can update status
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));

        // Random user cannot update status
        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(randomUser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.INACTIVE, "");
    }

    function test_onlyManager_canWithdrawFunds() public {
        // Fund campaign
        vm.prank(manager);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        // Finalize campaign
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");

        // Manager can withdraw
        vm.prank(manager);
        flywheel.withdrawFunds(campaign, address(token), INITIAL_TOKEN_BALANCE, "");

        // Random user cannot withdraw
        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(randomUser);
        flywheel.withdrawFunds(campaign, address(token), 0, "");
    }

    function test_batchPayouts() public {
        // Fund and activate campaign
        vm.prank(manager);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Create multiple payouts
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](3);
        payouts[0] = Flywheel.Payout({
            recipient: recipient1,
            amount: 100e18,
            extraData: ""
        });
        payouts[1] = Flywheel.Payout({
            recipient: recipient2,
            amount: 200e18,
            extraData: ""
        });
        payouts[2] = Flywheel.Payout({
            recipient: address(0x5000),
            amount: 150e18,
            extraData: ""
        });

        bytes memory hookData = abi.encode(payouts);

        // Process batch reward
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // Verify all recipients received correct amounts
        assertEq(token.balanceOf(recipient1), 100e18);
        assertEq(token.balanceOf(recipient2), 200e18);
        assertEq(token.balanceOf(address(0x5000)), 150e18);
    }

    function test_emptyPayouts() public {
        // Fund and activate campaign
        vm.prank(manager);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Create empty payouts array
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](0);
        bytes memory hookData = abi.encode(payouts);

        // Should not revert with empty payouts
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // No tokens should be transferred
        assertEq(token.balanceOf(recipient1), 0);
        assertEq(token.balanceOf(recipient2), 0);
    }

    function test_multipleTokenTypes() public {
        // Deploy second token
        address[] memory initialHolders = new address[](1);
        initialHolders[0] = manager;
        DummyERC20 token2 = new DummyERC20(initialHolders);

        // Fund campaign with both tokens
        vm.startPrank(manager);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);
        token2.transfer(campaign, INITIAL_TOKEN_BALANCE);
        
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        vm.stopPrank();

        // Create payouts for first token
        Flywheel.Payout[] memory payouts1 = new Flywheel.Payout[](1);
        payouts1[0] = Flywheel.Payout({
            recipient: recipient1,
            amount: 100e18,
            extraData: ""
        });

        // Create payouts for second token
        Flywheel.Payout[] memory payouts2 = new Flywheel.Payout[](1);
        payouts2[0] = Flywheel.Payout({
            recipient: recipient2,
            amount: 200e18,
            extraData: ""
        });

        // Process rewards for both tokens
        vm.prank(manager);
        flywheel.reward(campaign, address(token), abi.encode(payouts1));

        vm.prank(manager);
        flywheel.reward(campaign, address(token2), abi.encode(payouts2));

        // Verify correct token distributions
        assertEq(token.balanceOf(recipient1), 100e18);
        assertEq(token.balanceOf(recipient2), 0);
        assertEq(token2.balanceOf(recipient1), 0);
        assertEq(token2.balanceOf(recipient2), 200e18);
    }

    function test_allPayoutFunctions_supportedInAllStates() public {
        // Fund campaign
        vm.prank(manager);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        // Create payout data
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: recipient1,
            amount: 50e18,
            extraData: ""
        });
        bytes memory hookData = abi.encode(payouts);

        // Test in ACTIVE state
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);
        
        vm.prank(manager);
        flywheel.allocate(campaign, address(token), hookData);
        
        vm.prank(manager);
        flywheel.deallocate(campaign, address(token), hookData);
        
        vm.prank(manager);
        flywheel.allocate(campaign, address(token), hookData);
        
        vm.prank(manager);
        flywheel.distribute(campaign, address(token), hookData);

        // Test in FINALIZING state
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");

        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);
        
        vm.prank(manager);
        flywheel.allocate(campaign, address(token), hookData);
        
        vm.prank(manager);
        flywheel.deallocate(campaign, address(token), hookData);
        
        vm.prank(manager);
        flywheel.allocate(campaign, address(token), hookData);
        
        vm.prank(manager);
        flywheel.distribute(campaign, address(token), hookData);

        // Verify recipient received tokens from multiple operations
        assertEq(token.balanceOf(recipient1), 200e18); // 4 reward + distribute operations × 50e18
    }

    function test_zeroAmountPayouts() public {
        // Fund and activate campaign
        vm.prank(manager);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Create zero amount payouts
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](2);
        payouts[0] = Flywheel.Payout({
            recipient: recipient1,
            amount: 0,
            extraData: ""
        });
        payouts[1] = Flywheel.Payout({
            recipient: recipient2,
            amount: PAYOUT_AMOUNT,
            extraData: ""
        });

        bytes memory hookData = abi.encode(payouts);

        // Should not revert with zero amounts
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // Only non-zero amount should be transferred
        assertEq(token.balanceOf(recipient1), 0);
        assertEq(token.balanceOf(recipient2), PAYOUT_AMOUNT);
    }

    function test_createNewCampaign() public {
        // Create second campaign with different manager
        address newManager = address(0x9000);
        bytes memory hookData = abi.encode(newManager);

        address newCampaign = flywheel.createCampaign(address(hook), 2, hookData);

        // Verify new campaign has correct manager
        assertEq(hook.managers(newCampaign), newManager);
        assertEq(hook.managers(campaign), manager); // Original campaign unchanged

        // Verify isolation - original manager cannot control new campaign
        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(manager);
        flywheel.updateStatus(newCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        // But new manager can control new campaign
        vm.prank(newManager);
        flywheel.updateStatus(newCampaign, Flywheel.CampaignStatus.ACTIVE, "");
        assertEq(uint256(flywheel.campaignStatus(newCampaign)), uint256(Flywheel.CampaignStatus.ACTIVE));
    }

    function test_noFeesCharged() public {
        // Fund and activate campaign
        vm.prank(manager);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Create payout data
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: recipient1,
            amount: PAYOUT_AMOUNT,
            extraData: ""
        });

        bytes memory hookData = abi.encode(payouts);

        // Check initial balances
        uint256 campaignBalance = token.balanceOf(campaign);
        uint256 recipientBalance = token.balanceOf(recipient1);

        // Process reward
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // Verify no fees were charged (full amount transferred)
        assertEq(token.balanceOf(recipient1), recipientBalance + PAYOUT_AMOUNT);
        assertEq(token.balanceOf(campaign), campaignBalance - PAYOUT_AMOUNT);
    }
}
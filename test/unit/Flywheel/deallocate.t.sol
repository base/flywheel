// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../src/Flywheel.sol";
import {Constants} from "../../../src/Constants.sol";
import {FlywheelTest} from "../../lib/FlywheelTestBase.sol";
import {Vm} from "forge-std/Vm.sol";

/// @title DeallocateTest
/// @notice Tests for Flywheel.deallocate
contract DeallocateTest is FlywheelTest {
    address public campaign;

    function setUp() public {
        setUpFlywheelBase();
        campaign = createSimpleCampaign(owner, manager, "Test Campaign", 1);
    }

    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts if campaign does not exist
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    /// @param unknownCampaign Non-existent campaign address
    function test_reverts_whenCampaignDoesNotExist(address token, bytes memory hookData, address unknownCampaign)
        public
    {
        vm.assume(unknownCampaign != campaign);

        vm.expectRevert(Flywheel.CampaignDoesNotExist.selector);
        flywheel.deallocate(unknownCampaign, token, hookData);
    }

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts if campaign is INACTIVE
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignInactive(address token, bytes memory hookData) public {
        // Campaign starts as INACTIVE by default
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.INACTIVE));
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        vm.prank(manager);
        flywheel.deallocate(campaign, token, hookData);
    }

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts if campaign is FINALIZED
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignFinalized(address token, bytes memory hookData) public {
        activateCampaign(campaign, manager);
        finalizeCampaign(campaign, manager);
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZED));
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        vm.prank(manager);
        flywheel.deallocate(campaign, token, hookData);
    }

    /// @dev Verifies that deallocate succeeds even when campaign is initially insolvent
    /// @dev Deallocate cannot cause InsufficientCampaignFunds since it only reduces allocations
    /// @param amount Deallocation amount
    function test_reverts_ifCampaignIsInsufficientlyFunded(uint256 amount) public {
        address recipient = boundToValidPayableAddress(makeAddr("recipient"));
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);

        // Fund and allocate first
        fundCampaign(campaign, amount, address(this));
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "payout");
        managerAllocate(campaign, address(mockToken), payouts);

        // Verify initial allocation
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))), amount);

        // Now drain ALL funds to make campaign insolvent BEFORE deallocating
        vm.prank(campaign);
        mockToken.transfer(address(0xdead), amount);

        // Campaign now has 0 balance but amount allocated - insolvent
        // However, deallocate should still succeed because it reduces allocations, improving solvency
        vm.prank(manager);
        flywheel.deallocate(campaign, address(mockToken), abi.encode(payouts));

        // Verify deallocation was successful and campaign is now solvent
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))), 0);
        assertEq(flywheel.totalAllocatedPayouts(campaign, address(mockToken)), 0);
    }

    /// @dev Verifies that deallocate calls are allowed for campaign in ACTIVE state
    /// @param allocateAmount Allocation amount
    /// @param deallocateAmount Deallocation amount
    function test_succeeds_whenCampaignActive(uint256 allocateAmount, uint256 deallocateAmount) public {
        address recipient = boundToValidPayableAddress(makeAddr("recipient"));
        allocateAmount = boundToValidAmount(allocateAmount);
        deallocateAmount = boundToValidAmount(deallocateAmount);
        vm.assume(allocateAmount > 0);
        vm.assume(deallocateAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));
        fundCampaign(campaign, allocateAmount, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, allocateAmount, "payout");
        managerAllocate(campaign, address(mockToken), payouts);

        // Verify allocation was successful
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))), allocateAmount);

        // Now deallocate a partial amount
        Flywheel.Payout[] memory deallocatePayouts = buildSinglePayout(recipient, deallocateAmount, "deallocate");
        vm.prank(manager);
        flywheel.deallocate(campaign, address(mockToken), abi.encode(deallocatePayouts));

        // Verify deallocation was successful (remaining allocation = allocateAmount - deallocateAmount)
        assertEq(
            flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))),
            allocateAmount - deallocateAmount
        );
    }

    /// @dev Verifies that deallocate remains allowed for campaign in FINALIZING state
    /// @param allocateAmount Allocation amount
    /// @param deallocateAmount Deallocation amount
    function test_succeeds_whenCampaignFinalizing(uint256 allocateAmount, uint256 deallocateAmount) public {
        address recipient = boundToValidPayableAddress(makeAddr("recipient"));
        allocateAmount = boundToValidAmount(allocateAmount);
        deallocateAmount = boundToValidAmount(deallocateAmount);
        vm.assume(allocateAmount > 0);
        vm.assume(deallocateAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, allocateAmount, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, allocateAmount, "payout");
        managerAllocate(campaign, address(mockToken), payouts);

        // Move to FINALIZING state
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZING));

        // Now deallocate - should work in FINALIZING state
        Flywheel.Payout[] memory deallocatePayouts = buildSinglePayout(recipient, deallocateAmount, "deallocate");
        vm.prank(manager);
        flywheel.deallocate(campaign, address(mockToken), abi.encode(deallocatePayouts));

        // Verify deallocation was successful
        assertEq(
            flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))),
            allocateAmount - deallocateAmount
        );
    }

    /// @dev Verifies that deallocate calls work with an ERC20 token
    /// @param allocateAmount Allocation amount
    /// @param deallocateAmount Deallocation amount
    function test_succeeds_withERC20Token(uint256 allocateAmount, uint256 deallocateAmount) public {
        address recipient = boundToValidPayableAddress(makeAddr("recipient"));
        allocateAmount = boundToValidAmount(allocateAmount);
        deallocateAmount = boundToValidAmount(deallocateAmount);
        vm.assume(allocateAmount > 0);
        vm.assume(deallocateAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, allocateAmount, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, allocateAmount, "payout");
        managerAllocate(campaign, address(mockToken), payouts);

        // Verify initial allocation
        uint256 initialAllocated = flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient)));
        uint256 initialTotalAllocated = flywheel.totalAllocatedPayouts(campaign, address(mockToken));
        assertEq(initialAllocated, allocateAmount);
        assertEq(initialTotalAllocated, allocateAmount);

        // Now deallocate
        Flywheel.Payout[] memory deallocatePayouts = buildSinglePayout(recipient, deallocateAmount, "deallocate");
        vm.prank(manager);
        flywheel.deallocate(campaign, address(mockToken), abi.encode(deallocatePayouts));

        // Verify deallocation cleared the allocation
        assertEq(
            flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))),
            allocateAmount - deallocateAmount
        );
        assertEq(flywheel.totalAllocatedPayouts(campaign, address(mockToken)), allocateAmount - deallocateAmount);
    }

    /// @dev Verifies that deallocate calls work with native token
    /// @param allocateAmount Allocation amount
    /// @param deallocateAmount Deallocation amount
    function test_succeeds_withNativeToken(uint256 allocateAmount, uint256 deallocateAmount) public {
        address recipient = boundToValidPayableAddress(makeAddr("recipient"));
        allocateAmount = boundToValidAmount(allocateAmount);
        deallocateAmount = boundToValidAmount(deallocateAmount);
        vm.assume(allocateAmount > 0);
        vm.assume(deallocateAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        // Fund campaign with native token
        vm.deal(campaign, allocateAmount);

        // First allocate the funds
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, allocateAmount, "payout");
        managerAllocate(campaign, Constants.NATIVE_TOKEN, payouts);

        // Verify initial allocation
        uint256 initialAllocated =
            flywheel.allocatedPayout(campaign, Constants.NATIVE_TOKEN, bytes32(bytes20(recipient)));
        uint256 initialTotalAllocated = flywheel.totalAllocatedPayouts(campaign, Constants.NATIVE_TOKEN);
        assertEq(initialAllocated, allocateAmount);
        assertEq(initialTotalAllocated, allocateAmount);

        // Now deallocate
        Flywheel.Payout[] memory deallocatePayouts = buildSinglePayout(recipient, deallocateAmount, "deallocate");
        vm.prank(manager);
        flywheel.deallocate(campaign, Constants.NATIVE_TOKEN, abi.encode(deallocatePayouts));

        // Verify deallocation cleared the allocation
        assertEq(
            flywheel.allocatedPayout(campaign, Constants.NATIVE_TOKEN, bytes32(bytes20(recipient))),
            allocateAmount - deallocateAmount
        );
        assertEq(flywheel.totalAllocatedPayouts(campaign, Constants.NATIVE_TOKEN), allocateAmount - deallocateAmount);
    }

    /// @notice Ignores zero-amount deallocations (no-op)
    /// @dev Verifies totals unchanged and no event for zero amounts using the deployed token
    function test_ignoresZeroAmountDeallocations(uint256 allocateAmount) public {
        address recipient = boundToValidPayableAddress(makeAddr("recipient"));
        allocateAmount = boundToValidAmount(allocateAmount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, allocateAmount, address(this));

        // First allocate some funds
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, allocateAmount, "payout");
        managerAllocate(campaign, address(mockToken), payouts);

        // Store initial state
        uint256 initialAllocated = flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient)));
        uint256 initialTotalAllocated = flywheel.totalAllocatedPayouts(campaign, address(mockToken));

        // Now try to deallocate zero amount
        vm.recordLogs();
        Flywheel.Payout[] memory zeroPayouts = buildSinglePayout(recipient, 0, "zero_payout");
        vm.prank(manager);
        flywheel.deallocate(campaign, address(mockToken), abi.encode(zeroPayouts));

        // Verify zero amount deallocation had no effect
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))), initialAllocated);
        assertEq(flywheel.totalAllocatedPayouts(campaign, address(mockToken)), initialTotalAllocated);

        // Assert no PayoutsDeallocated event emitted by flywheel
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 payoutsDeallocatedSig = keccak256("PayoutsDeallocated(address,address,bytes32,uint256,bytes)");
        for (uint256 i = 0; i < logs.length; i++) {
            bool isFromFlywheel = logs[i].emitter == address(flywheel);
            bool isPayoutsDeallocated = logs[i].topics.length > 0 && logs[i].topics[0] == payoutsDeallocatedSig;
            if (isFromFlywheel && isPayoutsDeallocated) {
                revert("PayoutsDeallocated was emitted for zero-amount deallocation");
            }
        }
    }

    /// @dev Verifies that deallocate calls work with multiple deallocations
    /// @param amount1 First deallocation amount
    /// @param amount2 Second deallocation amount
    function test_succeeds_withMultipleDeallocations(uint256 amount1, uint256 amount2) public {
        address recipient1 = boundToValidPayableAddress(makeAddr("recipient1"));
        address recipient2 = boundToValidPayableAddress(makeAddr("recipient2"));
        vm.assume(recipient1 != recipient2);

        (amount1, amount2) = boundToValidMultiAmounts(amount1, amount2);
        vm.assume(amount1 > 0 && amount2 > 0);
        uint256 totalAmount = amount1 + amount2;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalAmount, address(this));

        // First allocate funds to both recipients
        Flywheel.Payout[] memory allocPayouts = new Flywheel.Payout[](2);
        allocPayouts[0] = Flywheel.Payout({recipient: recipient1, amount: amount1, extraData: "payout1"});
        allocPayouts[1] = Flywheel.Payout({recipient: recipient2, amount: amount2, extraData: "payout2"});
        managerAllocate(campaign, address(mockToken), allocPayouts);

        // Verify allocations
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient1))), amount1);
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient2))), amount2);
        assertEq(flywheel.totalAllocatedPayouts(campaign, address(mockToken)), totalAmount);

        // Now deallocate from both recipients
        Flywheel.Payout[] memory deallocPayouts = new Flywheel.Payout[](2);
        deallocPayouts[0] = Flywheel.Payout({recipient: recipient1, amount: amount1, extraData: "payout1"});
        deallocPayouts[1] = Flywheel.Payout({recipient: recipient2, amount: amount2, extraData: "payout2"});

        vm.prank(manager);
        flywheel.deallocate(campaign, address(mockToken), abi.encode(deallocPayouts));

        // Verify deallocations cleared all allocations
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient1))), 0);
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient2))), 0);
        assertEq(flywheel.totalAllocatedPayouts(campaign, address(mockToken)), 0);
    }

    /// @dev Verifies that the PayoutsDeallocated event is emitted for each deallocation
    /// @param amount Deallocation amount
    /// @param recipient Recipient address
    /// @param eventTestData Extra data for the payout to attach in events
    function test_emitsPayoutsDeallocatedEvent(uint256 amount, address recipient, bytes memory eventTestData) public {
        recipient = boundToValidPayableAddress(recipient);
        amount = boundToValidAmount(amount);
        vm.assume(amount > 0);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, eventTestData);
        managerAllocate(campaign, address(mockToken), payouts);

        // Now deallocate and expect the PayoutsDeallocated event
        vm.expectEmit(true, true, true, true);
        emit Flywheel.PayoutsDeallocated(
            campaign, address(mockToken), bytes32(bytes20(recipient)), amount, eventTestData
        );

        vm.prank(manager);
        flywheel.deallocate(campaign, address(mockToken), abi.encode(payouts));
    }
}

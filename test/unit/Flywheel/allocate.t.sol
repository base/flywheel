// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../src/Flywheel.sol";
import {Constants} from "../../../src/Constants.sol";
import {FlywheelTest} from "../../lib/FlywheelTestBase.sol";

/// @title AllocateTest
/// @notice Tests for Flywheel.allocate
contract AllocateTest is FlywheelTest {
    address public campaign;

    function setUp() public {
        setUpFlywheelBase();
        campaign = createSimpleCampaign(owner, manager, "Test Campaign", 1);
    }

    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts when campaign does not exist
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignDoesNotExist(address token, bytes memory hookData) public {
        address nonExistentCampaign = address(0x1234);

        vm.expectRevert(Flywheel.CampaignDoesNotExist.selector);
        flywheel.allocate(nonExistentCampaign, token, hookData);
    }

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is INACTIVE
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignInactive(address token, bytes memory hookData) public {
        // Campaign starts as INACTIVE by default
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.INACTIVE));
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        vm.prank(manager);
        flywheel.allocate(campaign, token, hookData);
    }

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is FINALIZED
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignFinalized(address token, bytes memory hookData) public {
        activateCampaign(campaign, manager);
        finalizeCampaign(campaign, manager);
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZED));
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        vm.prank(manager);
        flywheel.allocate(campaign, token, hookData);
    }

    /// @dev Expects InsufficientCampaignFunds
    /// @dev Reverts if campaign is insufficiently funded
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_reverts_ifCampaignIsInsufficientlyFunded(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);

        // Campaign has no funds, so any allocation should fail
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");

        vm.expectRevert(Flywheel.InsufficientCampaignFunds.selector);
        managerAllocate(campaign, address(mockToken), payouts);
    }

    /// @dev Verifies that allocate calls are allowed for campaign in ACTIVE state
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_succeeds_whenCampaignActive(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));
        fundCampaign(campaign, amount, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");

        // Should succeed when campaign is ACTIVE
        managerAllocate(campaign, address(mockToken), payouts);

        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))), amount);
        assertEq(flywheel.totalAllocatedPayouts(campaign, address(mockToken)), amount);
    }

    /// @dev Verifies that allocate remains allowed for campaign in FINALIZING state
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_succeeds_whenCampaignFinalizing(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        // Move to FINALIZING state
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZING));
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");

        // Should succeed when campaign is FINALIZING
        managerAllocate(campaign, address(mockToken), payouts);

        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))), amount);
        assertEq(flywheel.totalAllocatedPayouts(campaign, address(mockToken)), amount);
    }

    /// @dev Verifies that allocate calls work with an ERC20 token
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_succeeds_withERC20Token(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");

        managerAllocate(campaign, address(mockToken), payouts);

        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))), amount);
        assertEq(flywheel.totalAllocatedPayouts(campaign, address(mockToken)), amount);
    }

    /// @dev Verifies that allocate calls work with native token
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_succeeds_withNativeToken(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);

        // Fund campaign with native token
        vm.deal(campaign, amount);

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");

        managerAllocate(campaign, Constants.NATIVE_TOKEN, payouts);

        assertEq(flywheel.allocatedPayout(campaign, Constants.NATIVE_TOKEN, bytes32(bytes20(recipient))), amount);
        assertEq(flywheel.totalAllocatedPayouts(campaign, Constants.NATIVE_TOKEN), amount);
    }

    /// @dev Ignores zero-amount allocations (no-op)
    /// @dev Verifies totals for zero amounts
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_ignoresZeroAmountAllocations(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount); // Need some amount to fund campaign, but we'll allocate 0

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, 0, "");

        managerAllocate(campaign, address(mockToken), payouts);

        // Zero amount allocations should not change state
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))), 0);
        assertEq(flywheel.totalAllocatedPayouts(campaign, address(mockToken)), 0);
    }

    /// @dev Verifies that allocate calls work with multiple allocations
    /// @param recipient1 First recipient address
    /// @param recipient2 Second recipient address
    /// @param amount1 First allocation amount
    /// @param amount2 Second allocation amount
    function test_succeeds_withMultipleAllocations(
        address recipient1,
        address recipient2,
        uint256 amount1,
        uint256 amount2
    ) public {
        recipient1 = boundToValidAddress(recipient1);
        recipient2 = boundToValidAddress(recipient2);
        vm.assume(recipient1 != recipient2);

        (amount1, amount2) = boundToValidMultiAmounts(amount1, amount2);

        uint256 totalAmount = amount1 + amount2;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalAmount, address(this));

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](2);
        payouts[0] = Flywheel.Payout({recipient: recipient1, amount: amount1, extraData: "payout1"});
        payouts[1] = Flywheel.Payout({recipient: recipient2, amount: amount2, extraData: "payout2"});

        managerAllocate(campaign, address(mockToken), payouts);

        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient1))), amount1);
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient2))), amount2);
        assertEq(flywheel.totalAllocatedPayouts(campaign, address(mockToken)), totalAmount);
    }

    /// @dev Emits PayoutAllocated event
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_emitsPayoutAllocatedEvent(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "test_data");

        vm.expectEmit(true, true, true, true);
        emit Flywheel.PayoutAllocated(campaign, address(mockToken), bytes32(bytes20(recipient)), amount, "test_data");

        managerAllocate(campaign, address(mockToken), payouts);
    }
}

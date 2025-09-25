// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {Vm} from "forge-std/Vm.sol";

import {Flywheel} from "../../src/Flywheel.sol";
import {SimpleRewards} from "../../src/hooks/SimpleRewards.sol";
import {MockERC20} from "../lib/mocks/MockERC20.sol";
import {Constants} from "../../src/Constants.sol";
import {CampaignSolvencyHandler} from "./handlers/CampaignSolvencyHandler.sol";

/// @title FlywheelInvariantsTest
/// @notice Invariant tests for the Flywheel protocol
/// @dev Tests multiple protocol invariants: solvency, accounting consistency, and state transitions
contract FlywheelInvariantsTest is StdInvariant, StdAssertions {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Flywheel public flywheel;
    SimpleRewards public simpleRewards;
    MockERC20 public token;
    CampaignSolvencyHandler public handler;

    address public constant OWNER = address(0x1);
    address public constant MANAGER = address(0x2);
    string public constant CAMPAIGN_URI = "https://example.com/campaign";

    function setUp() public {
        // Deploy core contracts
        flywheel = new Flywheel();
        simpleRewards = new SimpleRewards(address(flywheel));
        address[] memory initialHolders = new address[](0);
        token = new MockERC20(initialHolders);

        // Deploy handler
        handler = new CampaignSolvencyHandler(flywheel, simpleRewards, token);

        // Set handler as target for invariant testing
        targetContract(address(handler));

        // Label contracts for better trace output
        vm.label(address(flywheel), "Flywheel");
        vm.label(address(simpleRewards), "SimpleRewards");
        vm.label(address(token), "TestToken");
        vm.label(address(handler), "Handler");
        vm.label(OWNER, "Owner");
        vm.label(MANAGER, "Manager");
    }

    /// @notice The core solvency invariant - adjusted for campaign status
    /// @dev Campaign balance must cover required obligations based on status:
    ///      - ACTIVE/FINALIZING: Must cover allocated payouts + allocated fees
    ///      - FINALIZED: Only needs to cover allocated fees (payouts can be withdrawn by owner)
    function invariant_campaignSolvency() public view {
        address[] memory campaigns = handler.getCampaigns();

        for (uint256 i = 0; i < campaigns.length; i++) {
            address campaign = campaigns[i];
            Flywheel.CampaignStatus status = flywheel.campaignStatus(campaign);

            // Check solvency for ERC20 token
            uint256 tokenBalance = token.balanceOf(campaign);
            uint256 totalAllocatedPayouts = flywheel.totalAllocatedPayouts(campaign, address(token));
            uint256 totalAllocatedFees = flywheel.totalAllocatedFees(campaign, address(token));

            uint256 requiredTokenSolvency = status == Flywheel.CampaignStatus.FINALIZED
                ? totalAllocatedFees  // Only fees for finalized campaigns
                : totalAllocatedPayouts + totalAllocatedFees; // Both for active campaigns

            assertGe(
                tokenBalance,
                requiredTokenSolvency,
                "Campaign token balance insufficient for required obligations"
            );

            // Check solvency for native token
            uint256 nativeBalance = campaign.balance;
            uint256 totalAllocatedPayoutsNative = flywheel.totalAllocatedPayouts(campaign, Constants.NATIVE_TOKEN);
            uint256 totalAllocatedFeesNative = flywheel.totalAllocatedFees(campaign, Constants.NATIVE_TOKEN);

            uint256 requiredNativeSolvency = status == Flywheel.CampaignStatus.FINALIZED
                ? totalAllocatedFeesNative  // Only fees for finalized campaigns
                : totalAllocatedPayoutsNative + totalAllocatedFeesNative; // Both for active campaigns

            assertGe(
                nativeBalance,
                requiredNativeSolvency,
                "Campaign native balance insufficient for required obligations"
            );
        }
    }

    /// @notice Invariant that individual allocations sum to totals
    /// @dev Sum of all individual allocatedPayout entries should equal totalAllocatedPayouts
    function invariant_allocationAccountingConsistency() public view {
        address[] memory campaigns = handler.getCampaigns();

        for (uint256 i = 0; i < campaigns.length; i++) {
            address campaign = campaigns[i];

            // Check ERC20 token allocation consistency
            bytes32[] memory payoutKeys = handler.getPayoutKeys(campaign, address(token));
            uint256 sumAllocatedPayouts = 0;

            for (uint256 j = 0; j < payoutKeys.length; j++) {
                sumAllocatedPayouts += flywheel.allocatedPayout(campaign, address(token), payoutKeys[j]);
            }

            assertEq(
                sumAllocatedPayouts,
                flywheel.totalAllocatedPayouts(campaign, address(token)),
                "Individual payout allocations don't sum to total allocated payouts"
            );

            // Check fee allocation consistency
            bytes32[] memory feeKeys = handler.getFeeKeys(campaign, address(token));
            uint256 sumAllocatedFees = 0;

            for (uint256 k = 0; k < feeKeys.length; k++) {
                sumAllocatedFees += flywheel.allocatedFee(campaign, address(token), feeKeys[k]);
            }

            assertEq(
                sumAllocatedFees,
                flywheel.totalAllocatedFees(campaign, address(token)),
                "Individual fee allocations don't sum to total allocated fees"
            );
        }
    }

    /// @notice Invariant that campaign status transitions are valid
    /// @dev Campaign status should never go backwards (except ACTIVE <-> FINALIZING)
    function invariant_validCampaignStatusTransitions() public view {
        address[] memory campaigns = handler.getCampaigns();

        for (uint256 i = 0; i < campaigns.length; i++) {
            address campaign = campaigns[i];
            Flywheel.CampaignStatus currentStatus = flywheel.campaignStatus(campaign);
            Flywheel.CampaignStatus previousStatus = handler.getPreviousStatus(campaign);

            // If we have a previous status, check transition validity
            if (previousStatus != Flywheel.CampaignStatus.INACTIVE || currentStatus != Flywheel.CampaignStatus.INACTIVE) {
                bool validTransition = _isValidStatusTransition(previousStatus, currentStatus);
                assertTrue(validTransition, "Invalid campaign status transition detected");
            }
        }
    }

    /// @notice Helper function to validate status transitions
    /// @param from Previous status
    /// @param to Current status
    /// @return valid Whether the transition is valid
    function _isValidStatusTransition(Flywheel.CampaignStatus from, Flywheel.CampaignStatus to)
        internal
        pure
        returns (bool valid)
    {
        // Same status is always valid (no change)
        if (from == to) return true;

        // Valid forward transitions
        if (from == Flywheel.CampaignStatus.INACTIVE && to == Flywheel.CampaignStatus.ACTIVE) return true;
        if (from == Flywheel.CampaignStatus.ACTIVE && to == Flywheel.CampaignStatus.FINALIZING) return true;
        if (from == Flywheel.CampaignStatus.FINALIZING && to == Flywheel.CampaignStatus.FINALIZED) return true;

        // Bidirectional transition between ACTIVE and FINALIZING
        if (from == Flywheel.CampaignStatus.FINALIZING && to == Flywheel.CampaignStatus.ACTIVE) return true;

        // All other transitions are invalid
        return false;
    }

    /// @notice Validation test to prove we're doing real work
    function test_handler_metrics_validation() public {
        // Run a smaller invariant test to check metrics
        vm.label(address(this), "InvariantTest");

        // Simulate some calls manually to check our handler
        handler.createCampaign(1000000 * 1e18);
        handler.createCampaign(500000 * 1e18);

        // Activate campaigns so they can accept payouts
        handler.updateStatus(0, 1); // Should transition to ACTIVE
        handler.updateStatus(1, 1); // Should transition to ACTIVE

        handler.allocatePayouts(0, 1, 10000 * 1e18, false);
        handler.allocatePayouts(1, 2, 5000 * 1e18, true);

        // Check that we actually did work
        uint256 allocations = handler.successfulAllocations();
        uint256 campaigns = handler.getCampaigns().length;

        assertGt(allocations, 0, "Handler should have successful allocations");
        assertGt(campaigns, 0, "Handler should have created campaigns");

        emit log_named_uint("Successful allocations", allocations);
        emit log_named_uint("Campaigns created", campaigns);
    }
}
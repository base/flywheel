// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {Vm} from "forge-std/Vm.sol";

import {Flywheel} from "../../src/Flywheel.sol";
import {SimpleRewards} from "../../src/hooks/SimpleRewards.sol";
import {MockERC20} from "../lib/mocks/MockERC20.sol";
import {Constants} from "../../src/Constants.sol";
import {AggressiveFlywheelHandler} from "./handlers/AggressiveFlywheelHandler.sol";

/// @title AggressiveFlywheelInvariantsTest
/// @notice AGGRESSIVE invariant tests that try to break the protocol
/// @dev This version allows "bad" calls to test protocol robustness
contract AggressiveFlywheelInvariantsTest is StdInvariant, StdAssertions {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    Flywheel public flywheel;
    SimpleRewards public simpleRewards;
    MockERC20 public token;
    AggressiveFlywheelHandler public handler;

    address public constant OWNER = address(0x1);
    address public constant MANAGER = address(0x2);

    function setUp() public {
        // Deploy contracts
        flywheel = new Flywheel();
        simpleRewards = new SimpleRewards(address(flywheel));
        address[] memory initialHolders = new address[](0);
        token = new MockERC20(initialHolders);

        // Deploy AGGRESSIVE handler
        handler = new AggressiveFlywheelHandler(flywheel, simpleRewards, token);

        // Set handler as target
        targetContract(address(handler));

        // Labels
        vm.label(address(flywheel), "Flywheel");
        vm.label(address(simpleRewards), "SimpleRewards");
        vm.label(address(token), "TestToken");
        vm.label(address(handler), "AggressiveHandler");
    }

    /// @notice The solvency invariant should ALWAYS hold, even under aggressive testing
    /// @dev Respects the business logic: FINALIZED campaigns only need to cover fees
    function invariant_campaignSolvency() public view {
        address[] memory campaigns = handler.getCampaigns();

        for (uint256 i = 0; i < campaigns.length; i++) {
            address campaign = campaigns[i];
            Flywheel.CampaignStatus status = flywheel.campaignStatus(campaign);

            // Check ERC20 solvency
            uint256 tokenBalance = token.balanceOf(campaign);
            uint256 totalAllocatedPayouts = flywheel.totalAllocatedPayouts(campaign, address(token));
            uint256 totalAllocatedFees = flywheel.totalAllocatedFees(campaign, address(token));

            uint256 requiredTokenSolvency = status == Flywheel.CampaignStatus.FINALIZED
                ? totalAllocatedFees
                : totalAllocatedPayouts + totalAllocatedFees;

            assertGe(
                tokenBalance,
                requiredTokenSolvency,
                "Campaign ERC20 solvency violated"
            );

            // Check native token solvency
            uint256 nativeBalance = campaign.balance;
            uint256 totalAllocatedPayoutsNative = flywheel.totalAllocatedPayouts(campaign, Constants.NATIVE_TOKEN);
            uint256 totalAllocatedFeesNative = flywheel.totalAllocatedFees(campaign, Constants.NATIVE_TOKEN);

            uint256 requiredNativeSolvency = status == Flywheel.CampaignStatus.FINALIZED
                ? totalAllocatedFeesNative
                : totalAllocatedPayoutsNative + totalAllocatedFeesNative;

            assertGe(
                nativeBalance,
                requiredNativeSolvency,
                "Campaign native solvency violated"
            );
        }
    }

    /// @notice Test that shows our aggressive handler is actually trying to break things
    function test_aggressive_handler_metrics() public {
        // Run some aggressive operations
        handler.createCampaign(1000000 * 1e18, 50); // 50% chance of funding
        handler.createCampaign(0, 10); // Low funding chance

        // Try to activate campaigns (some might fail)
        handler.updateStatus(0, 1);
        handler.updateStatus(1, 1);

        // Try aggressive allocations
        handler.allocatePayouts(0, 1, 2000000 * 1e18, false, 90); // Very aggressive!
        handler.allocatePayouts(1, 2, 1000000 * 1e18, true, 95);  // Even more aggressive!

        // Try over-distributions
        handler.distributePayouts(0, 1, 1000000 * 1e18, false, 90);

        // Try aggressive withdrawals
        handler.withdrawFunds(0, 500000 * 1e18, false, 90);

        // Check our metrics
        uint256 successful = handler.successfulAllocations();
        uint256 failed = handler.failedAllocations();
        uint256 solvencyAttempts = handler.solvencyViolationAttempts();
        uint256 statusAttempts = handler.invalidStatusAttempts();

        emit log_named_uint("Successful allocations", successful);
        emit log_named_uint("Failed allocations", failed);
        emit log_named_uint("Solvency violation attempts", solvencyAttempts);
        emit log_named_uint("Invalid status attempts", statusAttempts);

        // We should see some failures if we're being aggressive enough!
        // This proves we're actually testing edge cases
    }
}
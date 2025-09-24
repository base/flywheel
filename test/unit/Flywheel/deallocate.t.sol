// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title DeallocateTest
/// @notice Test stubs for Flywheel.deallocate
contract DeallocateTest is Test {
    /// @notice Reduces allocations and emits PayoutsDeallocated
    /// @dev Verifies mapping updates and event correctness using a deployed test token
    /// @param amount Deallocation amount (fuzzed)
    function test_deallocate_reducesAllocations_andEmitsEvent(uint256 amount) public {}

    /// @notice Succeeds when campaign is FINALIZING
    /// @dev Verifies that deallocate remains allowed in FINALIZING state
    /// @param amount Deallocation amount (fuzzed)
    function test_deallocate_succeeds_whenCampaignFinalizing(uint256 amount) public {}

    /// @notice Reverts when campaign is INACTIVE
    /// @dev Expects InvalidCampaignStatus; token is fuzzed since it's unused
    /// @param token ERC20 token address under test (fuzzed)
    /// @param hookData Raw hook data (fuzzed)
    function test_deallocate_reverts_whenCampaignInactive(address token, bytes memory hookData) public {}

    /// @notice Reverts when campaign is FINALIZED
    /// @dev Expects InvalidCampaignStatus; token not used if revert happens early
    /// @param token ERC20 token address under test (fuzzed)
    /// @param hookData Raw hook data (fuzzed)
    function test_deallocate_reverts_whenCampaignFinalized(address token, bytes memory hookData) public {}

    /// @notice Decrements totalAllocatedPayouts and asserts solvency
    /// @dev Exercises total accounting correctness using deployed token
    /// @param amount Deallocation amount (fuzzed)
    function test_deallocate_decrementsTotalAllocated_andAssertsSolvency(uint256 amount) public {}

    /// @notice Ignores zero-amount deallocations (no-op)
    /// @dev Verifies totals unchanged and no event for zero amounts using the deployed token
    /// @param hookData Raw hook data (fuzzed)
    function test_deallocate_ignoresZeroAmountDeallocations(bytes memory hookData) public {}
}

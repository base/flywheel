// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";

import {SimpleRewardsTest} from "../../../lib/SimpleRewardsTest.sol";

contract SimpleRewardsOnAllocateTest is SimpleRewardsTest {
    /// @notice Test that onAllocate reverts when called by non-Flywheel address
    ///
    /// @dev This test validates the onlyFlywheel access control by attempting to call
    /// _onAllocate directly from various sender addresses that are not the flywheel contract.
    /// Should revert with appropriate access control error.
    ///
    /// @param sender The address attempting to call the function (should not be flywheel)
    /// @param hookData The encoded payout data for allocation
    function test_onAllocate_revert_onlyFlywheel(address sender, bytes memory hookData) public {}

    /// @notice Test that onAllocate reverts when called by non-manager address
    ///
    /// @dev This test validates the onlyManager modifier by attempting to allocate rewards
    /// from addresses that are not the designated campaign manager. Should revert with
    /// Unauthorized error.
    ///
    /// @param sender The address attempting to call the function (should not be manager)
    /// @param hookData The encoded payout data for allocation
    function test_onAllocate_revert_onlyManager(address sender, bytes memory hookData) public {}

    /// @notice Test that onAllocate reverts when provided with invalid hook data
    ///
    /// @dev This test validates that the function properly decodes and validates the hookData
    /// parameter. Tests various invalid data formats, empty data, incorrectly structured data,
    /// and malformed abi.encode results for Payout arrays.
    ///
    /// @param sender The address calling the function
    /// @param hookData The malformed or invalid hook data that should cause a revert
    function test_onAllocate_revert_invalidHookData(address sender, bytes memory hookData) public {}

    /// @notice Test that onAllocate successfully processes a single ERC20 token allocation
    ///
    /// @dev This test validates that _onAllocate correctly converts a single Payout to an
    /// Allocation with the proper key (derived from recipient address), amount, and extraData.
    /// Verifies the allocation structure and data integrity.
    ///
    /// @param payout The single payout to be converted to allocation
    function test_onAllocate_success_erc20Single(Flywheel.Payout memory payout) public {}

    /// @notice Test that onAllocate successfully processes a single native token allocation
    ///
    /// @dev This test validates that _onAllocate correctly handles native token allocations
    /// with the same conversion logic as ERC20 tokens. Verifies that native token allocations
    /// produce the same Allocation structure.
    ///
    /// @param payout The single native token payout to be converted to allocation
    function test_onAllocate_success_nativeTokenSingle(Flywheel.Payout memory payout) public {}

    /// @notice Test that onAllocate successfully processes multiple ERC20 token allocations in batch
    ///
    /// @dev This test validates that _onAllocate correctly converts an array of Payouts to
    /// Allocations for ERC20 tokens. Verifies that all allocations are created correctly
    /// with proper keys, amounts, and extraData preserved.
    ///
    /// @param payouts The array of ERC20 payouts to be converted to allocations
    function test_onAllocate_success_erc20Batch(Flywheel.Payout[] memory payouts) public {}

    /// @notice Test that onAllocate successfully processes multiple native token allocations in batch
    ///
    /// @dev This test validates that _onAllocate correctly handles batch conversion of native
    /// token payouts to allocations. Verifies that native token batch processing works
    /// identically to ERC20 batch processing.
    ///
    /// @param payouts The array of native token payouts to be converted to allocations
    function test_onAllocate_success_nativeTokenBatch(Flywheel.Payout[] memory payouts) public {}

    /// @notice Test that onAllocate generates allocation keys that correctly match recipient addresses
    ///
    /// @dev This test validates the key generation logic where the allocation key is derived
    /// from bytes32(bytes20(recipient)). Ensures that the key can be used to identify and
    /// track allocations for specific recipients.
    ///
    /// @param payout The payout used to test key generation and recipient matching
    function test_onAllocate_success_keyMatchesRecipient(Flywheel.Payout memory payout) public {}
}

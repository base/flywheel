// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";

import {SimpleRewardsTest} from "../../../lib/SimpleRewardsTest.sol";

contract SimpleRewardsOnSendTest is SimpleRewardsTest {
    /// @notice Test that onSend reverts when called by non-Flywheel address
    ///
    /// @dev This test validates the onlyFlywheel access control by attempting to call
    /// _onSend directly from various sender addresses that are not the flywheel contract.
    /// Should revert with appropriate access control error.
    ///
    /// @param sender The address attempting to call the function (should not be flywheel)
    /// @param hookData The encoded payout data
    function test_onSend_revert_onlyFlywheel(address sender, bytes memory hookData) public {}

    /// @notice Test that onSend reverts when called by non-manager address
    ///
    /// @dev This test validates the onlyManager modifier by attempting to send payouts
    /// from addresses that are not the designated campaign manager. Should revert with
    /// Unauthorized error.
    ///
    /// @param sender The address attempting to call the function (should not be manager)
    /// @param hookData The encoded payout data
    function test_onSend_revert_onlyManager(address sender, bytes memory hookData) public {}

    /// @notice Test that onSend reverts when provided with invalid hook data
    ///
    /// @dev This test validates that the function properly decodes and validates the hookData
    /// parameter. Tests various invalid data formats, empty data, incorrectly structured data,
    /// and malformed abi.encode results for Payout arrays.
    ///
    /// @param sender The address calling the function
    /// @param hookData The malformed or invalid hook data that should cause a revert
    function test_onSend_revert_invalidHookData(address sender, bytes memory hookData) public {}

    /// @notice Test that onSend successfully processes a single ERC20 token payout
    ///
    /// @dev This test validates that _onSend correctly decodes a single payout and returns
    /// the appropriate payouts array. Verifies that no fees are charged and sendFeesNow is false.
    /// Tests with various ERC20 token amounts and recipients.
    ///
    /// @param payout The single payout to be processed with recipient, amount, and extraData
    function test_onSend_success_erc20Single(Flywheel.Payout memory payout) public {}

    /// @notice Test that onSend successfully processes a single native token payout
    ///
    /// @dev This test validates that _onSend correctly handles native token payouts with the
    /// same logic as ERC20 tokens. Verifies the payout is correctly returned and no fees
    /// are charged for native token transfers.
    ///
    /// @param payout The single native token payout to be processed
    function test_onSend_success_nativeTokenSingle(Flywheel.Payout memory payout) public {}

    /// @notice Test that onSend successfully processes multiple ERC20 token payouts in batch
    ///
    /// @dev This test validates that _onSend correctly decodes and processes an array of
    /// payouts for ERC20 tokens. Verifies that all payouts are returned correctly without
    /// modification and no fees are charged on any of the payouts.
    ///
    /// @param payouts The array of ERC20 payouts to be processed in batch
    function test_onSend_success_erc20Batch(Flywheel.Payout[] memory payouts) public {}

    /// @notice Test that onSend successfully processes multiple native token payouts in batch
    ///
    /// @dev This test validates that _onSend correctly handles batch processing of native
    /// token payouts. Verifies that all payouts are returned correctly and native token
    /// batch processing works identically to ERC20 batch processing.
    ///
    /// @param payouts The array of native token payouts to be processed in batch
    function test_onSend_success_nativeTokenBatch(Flywheel.Payout[] memory payouts) public {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";

import {SimpleRewardsTest} from "../../../lib/SimpleRewardsTest.sol";

contract SimpleRewardsOnWithdrawFundsTest is SimpleRewardsTest {
    /// @notice Test that onWithdrawFunds reverts when called by non-Flywheel address
    ///
    /// @dev This test validates the onlyFlywheel access control by attempting to call
    /// _onWithdrawFunds directly from various sender addresses that are not the flywheel contract.
    /// Should revert with appropriate access control error.
    ///
    /// @param sender The address attempting to call the function (should not be flywheel)
    /// @param hookData The encoded payout data for fund withdrawal
    function test_onWithdrawFunds_revert_onlyFlywheel(address sender, bytes memory hookData) public {}

    /// @notice Test that onWithdrawFunds reverts when called by non-owner address
    ///
    /// @dev This test validates that only the campaign owner can withdraw funds, not the manager
    /// or other addresses. Should revert with Unauthorized error when called by non-owner.
    /// Note: This differs from other functions that use onlyManager modifier.
    ///
    /// @param sender The address attempting to call the function (should not be owner)
    /// @param hookData The encoded payout data for fund withdrawal
    function test_onWithdrawFunds_revert_onlyOwner(address sender, bytes memory hookData) public {}

    /// @notice Test that onWithdrawFunds reverts when provided with invalid hook data
    ///
    /// @dev This test validates that the function properly decodes and validates the hookData
    /// parameter. Tests various invalid data formats, empty data, incorrectly structured data,
    /// and malformed abi.encode results for Payout struct.
    ///
    /// @param sender The address calling the function
    /// @param hookData The malformed or invalid hook data that should cause a revert
    function test_onWithdrawFunds_revert_invalidHookData(address sender, bytes memory hookData) public {}

    /// @notice Test that onWithdrawFunds successfully processes ERC20 token withdrawal
    ///
    /// @dev This test validates that _onWithdrawFunds correctly decodes and returns the
    /// payout for ERC20 token withdrawal. Verifies that the owner can withdraw remaining
    /// campaign funds to the specified recipient with the correct amount and extraData.
    ///
    /// @param payout The ERC20 payout data for fund withdrawal
    function test_onWithdrawFunds_success_erc20(Flywheel.Payout memory payout) public {}

    /// @notice Test that onWithdrawFunds successfully processes native token withdrawal
    ///
    /// @dev This test validates that _onWithdrawFunds correctly handles native token withdrawal
    /// with the same logic as ERC20 tokens. Verifies that the owner can withdraw native
    /// token funds from the campaign.
    ///
    /// @param payout The native token payout data for fund withdrawal
    function test_onWithdrawFunds_success_nativeToken(Flywheel.Payout memory payout) public {}
}

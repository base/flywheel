// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title WithdrawFundsTest
/// @notice Test stubs for Flywheel.withdrawFunds
contract WithdrawFundsTest is Test {
    /// @notice Withdraws funds via hook and emits FundsWithdrawn
    /// @dev Verifies hook authorization and campaign solvency assertion using deployed token
    /// @param amount Withdraw amount (fuzzed)
    function test_withdrawFunds_withdraws_andEmitsEvent(uint256 amount) public {}

    /// @notice Reverts on zero amount
    /// @dev Expects ZeroAmount error
    function test_withdrawFunds_reverts_whenZeroAmount() public {}

    /// @notice Reverts when send fails
    /// @dev Expects SendFailed error
    /// @param token ERC20 token address under test (fuzzed)
    /// @param amount Withdraw amount (fuzzed)
    function test_withdrawFunds_reverts_whenSendFailed(address token, uint256 amount) public {}

    /// @notice Respects solvency rule in FINALIZED state (ignore payouts, require fees only)
    /// @dev Exercises path where requiredSolvency excludes totalAllocatedPayouts using deployed token
    /// @param feeAmount Fee amount reserved (fuzzed)
    function test_withdrawFunds_enforcesSolvency_finalizedIgnoresPayouts(uint256 feeAmount) public {}
}

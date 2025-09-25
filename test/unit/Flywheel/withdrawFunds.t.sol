// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title WithdrawFundsTest
/// @notice Tests for Flywheel.withdrawFunds
contract WithdrawFundsTest is Test {
    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts when campaign does not exist
    /// @param campaign Campaign address
    function test_reverts_whenCampaignDoesNotExist(address campaign) public {}

    /// @dev Expects ZeroAmount
    /// @dev Reverts on zero amount
    function test_reverts_whenZeroAmount() public {}

    /// @dev Expects SendFailed when Campaign.sendTokens returns false (ERC20)
    /// @param token ERC20 token address under test
    /// @param amount Withdraw amount
    function test_reverts_whenSendFailed_ERC20(address token, uint256 amount) public {}

    /// @dev Expects SendFailed when Campaign.sendTokens returns false (native token)
    /// @param amount Withdraw amount
    function test_reverts_whenSendFailed_native(uint256 amount) public {}

    /// @dev Expects InsufficientCampaignFunds
    /// @dev Verifies that withdraw funds enforces solvency before FINALIZED
    /// @dev Solvency incorporates both total allocated payouts and total allocated fees
    /// @param amount Withdraw amount
    function test_reverts_whenCampaignIsNotSolvent_beforeFinalized(uint256 amount) public {}

    /// @dev Expects InsufficientCampaignFunds
    /// @dev Respects solvency rule in FINALIZED state (ignore payouts, require fees only)
    /// @param amount Withdraw amount
    function test_reverts_whenCampaignIsNotSolvent_finalizedIgnoresPayouts(uint256 amount) public {}

    /// @dev Verifies withdrawal succeeds (ERC20)
    /// @param recipient Recipient address
    /// @param amount Withdraw amount
    function test_succeeds_withERC20(address recipient, uint256 amount) public {}

    /// @dev Verifies withdrawal succeeds (native token)
    /// @param recipient Recipient address
    /// @param amount Withdraw amount
    function test_succeeds_withNative(address recipient, uint256 amount) public {}

    /// @dev Verifies that the FundsWithdrawn event is emitted
    /// @param recipient Recipient address
    /// @param amount Withdraw amount
    function test_emitsFundsWithdrawnEvent(address recipient, uint256 amount) public {}
}

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
    function test_withdrawFunds_reverts_whenCampaignDoesNotExist(address campaign) public {}

    /// @dev Expects ZeroAmount
    /// @dev Reverts on zero amount
    function test_withdrawFunds_reverts_whenZeroAmount() public {}

    /// @dev Expects SendFailed when Campaign.sendTokens returns false (ERC20)
    /// @param token ERC20 token address under test
    /// @param amount Withdraw amount
    function test_withdrawFunds_reverts_whenSendFailed_ERC20(address token, uint256 amount) public {}

    /// @dev Expects SendFailed when Campaign.sendTokens returns false (native token)
    /// @param amount Withdraw amount
    function test_withdrawFunds_reverts_whenSendFailed_native(uint256 amount) public {}

    /// @dev Verifies withdrawal succeeds (ERC20)
    /// @param recipient Recipient address
    /// @param amount Withdraw amount
    function test_withdrawFunds_succeeds_withERC20(address recipient, uint256 amount) public {}

    /// @dev Verifies withdrawal succeeds (native token)
    /// @param recipient Recipient address
    /// @param amount Withdraw amount
    function test_withdrawFunds_succeeds_withNative(address recipient, uint256 amount) public {}

    /// @dev Respects solvency rule in FINALIZED state (ignore payouts, require fees only)
    /// @param feeAmount Fee amount reserved
    function test_withdrawFunds_enforcesSolvency_finalizedIgnoresPayouts(uint256 feeAmount) public {}
}

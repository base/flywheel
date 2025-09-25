// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {Campaign} from "../../../src/Campaign.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title SendTokensTest
/// @notice Tests for `Campaign.sendTokens`
contract SendTokensTest is Test {
    /// @notice sendTokens reverts for non-Flywheel callers
    /// @dev Expects OnlyFlywheel error when msg.sender != flywheel
    /// @param caller Caller address
    function test_sendTokens_reverts_whenCallerNotFlywheel(address caller) public {}

    /// @dev Verifies sendTokens succeeds for native token
    /// @param recipient Recipient address
    /// @param amount Amount to send
    function test_sendTokens_succeeds_forNativeToken(address recipient, uint256 amount) public {}

    /// @dev Verifies sendTokens succeeds for ERC20 token
    /// @param recipient Recipient address
    /// @param amount Amount to send
    function test_sendTokens_succeeds_forERC20Token(address recipient, uint256 amount) public {}

    /// @dev Verifies sendTokens returns false when send fails (ERC20)
    /// @param recipient Recipient address
    /// @param amount Amount to send
    function test_sendTokens_returnsFalseWhenSendFails_ERC20(address recipient, uint256 amount) public {}

    /// @dev Verifies sendTokens returns false when send fails (native token)
    /// @param recipient Recipient address
    /// @param amount Amount to send
    function test_sendTokens_returnsFalseWhenSendFails_native(address recipient, uint256 amount) public {}
}

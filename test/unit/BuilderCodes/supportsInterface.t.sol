// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.supportsInterface
contract SupportsInterfaceTest is BuilderCodesTest {
    /// @notice Test that supportsInterface returns true for ERC165
    function test_supportsInterface_true_ERC165() public {}

    /// @notice Test that supportsInterface returns true for ERC721
    function test_supportsInterface_true_ERC721() public {}

    /// @notice Test that supportsInterface returns true for ERC4906
    function test_supportsInterface_true_ERC4906() public {}

    /// @notice Test that supportsInterface returns true for AccessControl
    function test_supportsInterface_true_AccessControl() public {}

    /// @notice Test that supportsInterface returns false for unsupported interfaces
    ///
    /// @param interfaceId The interface ID to test
    function test_supportsInterface_false_other(bytes4 interfaceId) public {}
}

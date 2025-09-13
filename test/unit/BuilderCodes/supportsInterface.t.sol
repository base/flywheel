// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesBase} from "./BuilderCodesBase.sol";

/// @notice Tests for BuilderCodes.supportsInterface
contract SupportsInterfaceTest is BuilderCodesBase {
    function test_supportsInterface_true_ERC165() public {}

    function test_supportsInterface_true_ERC721() public {}

    function test_supportsInterface_true_ERC4906() public {}

    function test_supportsInterface_true_AccessControl() public {}

    function test_supportsInterface_false_other(bytes4 interfaceId) public {}
}

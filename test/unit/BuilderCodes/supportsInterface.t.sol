// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesCommon} from "../../common/BuilderCodesCommon.sol";

/// @notice Tests for BuilderCodes.supportsInterface
contract SupportsInterfaceTest is BuilderCodesCommon {
    function test_supportsInterface_true_ERC165() public {}

    function test_supportsInterface_true_ERC721() public {}

    function test_supportsInterface_true_ERC4906() public {}

    function test_supportsInterface_true_AccessControl() public {}

    function test_supportsInterface_false_other(bytes4 interfaceId) public {}
}

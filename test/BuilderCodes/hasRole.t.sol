// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesBase} from "./BuilderCodesBase.sol";

/// @notice Tests for BuilderCodes.hasRole
contract HasRoleTest is BuilderCodesBase {
    function test_hasRole_true_isOwner(bytes32 role) public {}

    function test_hasRole_true_hasRole(bytes32 role, address account) public {}

    function test_hasRole_false_other(bytes32 role, address account) public {}
}

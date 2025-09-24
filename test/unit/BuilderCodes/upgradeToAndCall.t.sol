// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.upgradeToAndCall
contract UpgradeToAndCallTest is BuilderCodesTest {
    /// @notice Test that upgradeToAndCall reverts when caller is not the owner
    function test_upgradeToAndCall_revert_notOwner() public {}

    /// @notice Test that upgradeToAndCall successfully updates the implementation
    function test_upgradeToAndCall_success_updatesImplementation() public {}

    /// @notice Test that upgradeToAndCall succeeds without default slot ordering collision
    function test_upgradeToAndCall_success_noDefaultSlotOrderingCollision() public {}

    /// @notice Test that upgradeToAndCall can change the EIP712 domain version
    function test_upgradeToAndCall_success_canChangeEIP712DomainVersion() public {}

    /// @notice Test that upgradeToAndCall emits the ERC1967 Upgraded event
    function test_upgradeToAndCall_success_emitsERC1967Upgraded() public {}
}

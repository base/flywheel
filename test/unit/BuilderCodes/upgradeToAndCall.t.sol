// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesBase} from "./BuilderCodesBase.sol";

/// @notice Tests for BuilderCodes.updateToAndCall
contract UpgradeToAndCallTest is BuilderCodesBase {
    /**
     * upgradeToAndCall reverts
     */
    function test_upgradeToAndCall_revert_notOwner() public {}

    /**
     * upgradeToAndCall success conditions
     */
    function test_upgradeToAndCall_success_updatesImplementation() public {}

    function test_upgradeToAndCall_success_noDefaultSlotOrderingCollision() public {}

    function test_upgradeToAndCall_success_canChangeEIP712DomainVersion() public {}

    /**
     * upgradeToAndCall event emission
     */
    function test_upgradeToAndCall_success_emitsERC1967Upgraded() public {}
}

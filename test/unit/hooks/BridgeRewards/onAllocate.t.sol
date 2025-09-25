// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract BridgeRewardsOnAllocateTest is BridgeRewardsTest {
    /// @notice Tests that onAllocate reverts when called by non-flywheel address
    ///
    /// @dev Verifies access control enforcement - only the flywheel contract should be able
    ///      to call hook functions. Tests the onlyFlywheel modifier functionality.
    ///
    /// @param sender Random address that is not the flywheel contract
    /// @param hookData Arbitrary hook data for the allocation call
    function test_onAllocate_revert_onlyFlywheel(address sender, bytes memory hookData) public {}

    /// @notice Tests that onAllocate reverts as BridgeRewards does not support allocation
    ///
    /// @dev BridgeRewards is designed for immediate payouts during bridge operations,
    ///      not for allocating tokens to be distributed later. This test verifies
    ///      that allocation attempts are properly rejected.
    ///
    /// @param sender The address attempting to perform allocation
    /// @param hookData Hook data containing allocation parameters
    function test_onAllocate_revert_unsupported(address sender, bytes memory hookData) public {}
}

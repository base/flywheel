// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract BridgeRewardsOnDeallocateTest is BridgeRewardsTest {
    /// @notice Tests that onDeallocate reverts when called by non-flywheel address
    ///
    /// @dev Verifies access control enforcement - only the flywheel contract should be able
    ///      to call hook functions. Tests the onlyFlywheel modifier functionality.
    ///
    /// @param sender Random address that is not the flywheel contract
    /// @param hookData Arbitrary hook data for the deallocation call
    function test_onDeallocate_revert_onlyFlywheel(address sender, bytes memory hookData) public {}

    /// @notice Tests that onDeallocate reverts as BridgeRewards does not support deallocation
    ///
    /// @dev BridgeRewards operates with immediate payouts during bridge operations,
    ///      not with allocated tokens that need deallocation. This test verifies
    ///      that deallocation attempts are properly rejected.
    ///
    /// @param sender The address attempting to perform deallocation
    /// @param hookData Hook data containing deallocation parameters
    function test_onDeallocate_revert_unsupported(address sender, bytes memory hookData) public {}
}

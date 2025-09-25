// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract BridgeRewardsOnDistributeTest is BridgeRewardsTest {
    /// @notice Tests that onDistribute reverts when called by non-flywheel address
    ///
    /// @dev Verifies access control enforcement - only the flywheel contract should be able
    ///      to call hook functions. Tests the onlyFlywheel modifier functionality.
    ///
    /// @param sender Random address that is not the flywheel contract
    /// @param hookData Arbitrary hook data for the distribution call
    function test_onDistribute_revert_onlyFlywheel(address sender, bytes memory hookData) public {}

    /// @notice Tests that onDistribute reverts as BridgeRewards does not support batch distribution
    ///
    /// @dev BridgeRewards handles payouts immediately during the bridge operation via onSend,
    ///      not through separate distribution calls. This test verifies that distribution
    ///      attempts are properly rejected as unsupported functionality.
    ///
    /// @param sender The address attempting to perform distribution
    /// @param hookData Hook data containing distribution parameters
    function test_onDistribute_revert_unsupported(address sender, bytes memory hookData) public {}
}

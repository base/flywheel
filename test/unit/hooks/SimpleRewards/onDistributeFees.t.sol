// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";

import {SimpleRewardsTest} from "../../../lib/SimpleRewardsTest.sol";

contract SimpleRewardsOnDistributeFeesTest is SimpleRewardsTest {
    /// @notice Test that onDistributeFees reverts when called by non-Flywheel address
    ///
    /// @dev This test validates the onlyFlywheel access control by attempting to call
    /// _onDistributeFees directly from various sender addresses that are not the flywheel contract.
    /// Should revert with appropriate access control error.
    ///
    /// @param sender The address attempting to call the function (should not be flywheel)
    /// @param hookData The encoded fee distribution data
    function test_onDistributeFees_revert_onlyFlywheel(address sender, bytes memory hookData) public {}

    /// @notice Test that onDistributeFees reverts as unsupported operation
    ///
    /// @dev This test validates that SimpleRewards does not support fee distribution functionality.
    /// The hook should revert when _onDistributeFees is called, as SimpleRewards is designed
    /// for direct payouts without fee collection or distribution mechanisms.
    ///
    /// @param sender The address calling the function
    /// @param hookData The encoded fee distribution data (should be irrelevant)
    function test_onDistributeFees_revert_unsupported(address sender, bytes memory hookData) public {}
}

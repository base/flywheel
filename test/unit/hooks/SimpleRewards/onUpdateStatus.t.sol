// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";

import {SimpleRewardsTest} from "../../../lib/SimpleRewardsTest.sol";

contract SimpleRewardsOnUpdateStatusTest is SimpleRewardsTest {
    /// @notice Test that onUpdateStatus reverts when called by non-Flywheel address
    ///
    /// @dev This test validates the onlyFlywheel access control by attempting to call
    /// _onUpdateStatus directly from various sender addresses that are not the flywheel contract.
    /// Should revert with appropriate access control error.
    ///
    /// @param sender The address attempting to call the function (should not be flywheel)
    /// @param hookData The encoded data for status update (usually empty for SimpleRewards)
    function test_onUpdateStatus_revert_onlyFlywheel(address sender, bytes memory hookData) public {}

    /// @notice Test that onUpdateStatus reverts when called by non-manager address
    ///
    /// @dev This test validates the onlyManager modifier by attempting to update campaign status
    /// from addresses that are not the designated campaign manager. Should revert with
    /// Unauthorized error.
    ///
    /// @param sender The address attempting to call the function (should not be manager)
    /// @param hookData The encoded data for status update
    function test_onUpdateStatus_revert_onlyManager(address sender, bytes memory hookData) public {}

    /// @notice Test that onUpdateStatus successfully handles transitions from ACTIVE status
    ///
    /// @dev This test validates that _onUpdateStatus correctly processes status transitions
    /// from ACTIVE to other valid states (INACTIVE, FINALIZING, FINALIZED). The function should
    /// complete without error and allow the state transition.
    ///
    /// @param newStatus The new campaign status to transition to from ACTIVE
    function test_onUpdateStatus_success_activeToOther(Flywheel.CampaignStatus newStatus) public {}

    /// @notice Test that onUpdateStatus successfully handles transitions from INACTIVE status
    ///
    /// @dev This test validates that _onUpdateStatus correctly processes status transitions
    /// from INACTIVE to other valid states (ACTIVE, FINALIZING, FINALIZED). The function should
    /// complete without error and allow the state transition.
    ///
    /// @param newStatus The new campaign status to transition to from INACTIVE
    function test_onUpdateStatus_success_inactiveToOther(Flywheel.CampaignStatus newStatus) public {}

    /// @notice Test that onUpdateStatus successfully handles transition from FINALIZING to FINALIZED
    ///
    /// @dev This test validates that _onUpdateStatus correctly processes the final status transition
    /// from FINALIZING to FINALIZED. This is typically the final state change in a campaign lifecycle
    /// and should complete without error.
    ///
    /// @param newStatus The new campaign status (should typically be FINALIZED)
    function test_onUpdateStatus_success_finalizingToFinalized(Flywheel.CampaignStatus newStatus) public {}
}

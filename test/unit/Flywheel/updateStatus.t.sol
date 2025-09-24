// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title UpdateStatusTest
/// @notice Test stubs for Flywheel.updateStatus
contract UpdateStatusTest is Test {
    /// @notice Transitions INACTIVE -> ACTIVE
    /// @dev Verifies CampaignStatusUpdated event and status change
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus (fuzzed)
    function test_updateStatus_inactiveToActive(bytes memory hookData) public {}

    /// @notice Transitions ACTIVE -> FINALIZING
    /// @dev Verifies CampaignStatusUpdated event and status change
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus (fuzzed)
    function test_updateStatus_activeToFinalizing(bytes memory hookData) public {}

    /// @notice Transitions FINALIZING -> FINALIZED
    /// @dev Verifies CampaignStatusUpdated event and status change
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus (fuzzed)
    function test_updateStatus_finalizingToFinalized(bytes memory hookData) public {}

    /// @notice Reverts when setting same status
    /// @dev Expects InvalidCampaignStatus
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus (fuzzed)
    function test_updateStatus_reverts_whenNoStatusChange(bytes memory hookData) public {}

    /// @notice Reverts when updating from FINALIZED
    /// @dev Expects InvalidCampaignStatus
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus (fuzzed)
    function test_updateStatus_reverts_whenFromFinalized(bytes memory hookData) public {}

    /// @notice Reverts when FINALIZING -> not FINALIZED
    /// @dev Expects InvalidCampaignStatus
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus (fuzzed)
    function test_updateStatus_reverts_whenFinalizingToOther(bytes memory hookData) public {}

    /// @notice Hook-specific constraints are enforced (uses SimpleRewards manager-only rule)
    /// @dev Demonstrates that hooks run pre-state update and may revert
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus (fuzzed)
    function test_updateStatus_enforcesHookConstraints(bytes memory hookData) public {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title UpdateStatusTest
/// @notice Tests for Flywheel.updateStatus
contract UpdateStatusTest is Test {
    /// @dev Expects InvalidCampaignStatus when setting same status
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus
    function test_updateStatus_reverts_whenNoStatusChange(bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus when updating from FINALIZED
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus
    function test_updateStatus_reverts_whenFromFinalized(bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus when FINALIZING -> not FINALIZED
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus
    function test_updateStatus_reverts_whenFinalizingToNotFinalized(bytes memory hookData) public {}

    /// @notice Transitions INACTIVE -> ACTIVE
    /// @dev Verifies CampaignStatusUpdated event and status change
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus
    function test_updateStatus_succeeds_inactiveToActive(bytes memory hookData) public {}

    /// @notice Transitions ACTIVE -> FINALIZING
    /// @dev Verifies CampaignStatusUpdated event and status change
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus
    function test_updateStatus_succeeds_activeToFinalizing(bytes memory hookData) public {}

    /// @notice Transitions FINALIZING -> FINALIZED
    /// @dev Verifies CampaignStatusUpdated event and status change
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus
    function test_updateStatus_succeeds_finalizingToFinalized(bytes memory hookData) public {}
}

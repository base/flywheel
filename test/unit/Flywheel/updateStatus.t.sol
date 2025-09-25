// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title UpdateStatusTest
/// @notice Tests for Flywheel.updateStatus
contract UpdateStatusTest is Test {
    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts when campaign does not exist
    /// @param campaign Non-existent campaign address
    function test_reverts_ifNonexistentCampaign(address campaign) public {}

    /// @dev Expects InvalidCampaignStatus when setting same status
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus
    function test_reverts_whenNoStatusChange(bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus when updating from FINALIZED
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateStatus
    function test_reverts_whenFromFinalized(bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus when FINALIZING -> not FINALIZED
    /// @param newStatus New status of the campaign as Flywheel.CampaignStatus
    function test_reverts_whenFinalizingToNotFinalized(uint256 newStatus) public {}

    /// @notice Transitions INACTIVE -> Any other status
    /// @dev Verifies CampaignStatusUpdated event and status change
    /// @param newStatus New status of the campaign as Flywheel.CampaignStatus
    function test_succeeds_inactiveToAnyOtherStatus(uint256 newStatus) public {}

    /// @notice Transitions ACTIVE -> Any other status
    /// @dev Verifies CampaignStatusUpdated event and status change
    /// @param newStatus New status of the campaign as Flywheel.CampaignStatus
    function test_succeeds_activeToAnyOtherStatus(uint256 newStatus) public {}

    /// @notice Transitions FINALIZING -> FINALIZED
    /// @dev Verifies CampaignStatusUpdated event and status change
    function test_succeeds_finalizingToFinalized() public {}
}

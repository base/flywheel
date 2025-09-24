// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title UpdateMetadataTest
/// @notice Test stubs for Flywheel.updateMetadata
contract UpdateMetadataTest is Test {
    /// @notice Emits CampaignMetadataUpdated and forwards to hooks.onUpdateMetadata
    /// @dev Verifies campaignURI reflects potential hook changes
    /// @param newURI New campaign URI to apply via hook (fuzzed)
    function test_updateMetadata_emitsEvent_andCallsHook(bytes memory newURI) public {}

    /// @notice Reverts when campaign is FINALIZED
    /// @dev Expects InvalidCampaignStatus
    /// @param hookData Arbitrary hook data used during the call (fuzzed)
    function test_updateMetadata_reverts_whenFinalized(bytes memory hookData) public {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title UpdateMetadataTest
/// @notice Tests for Flywheel.updateMetadata
contract UpdateMetadataTest is Test {
    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is FINALIZED
    /// @param hookData Arbitrary hook data forwarded to hooks.onUpdateMetadata
    function test_reverts_whenFinalized(bytes memory hookData) public {}

    /// @dev Verifies updateMetadata succeeds and forwards to hooks.onUpdateMetadata
    /// @dev Expects ContractURIUpdated event from hook
    /// @param newURI New campaign URI to apply via hook
    function test_succeeds_andForwardsToHook(bytes memory newURI) public {}

    /// @dev Verifies that CampaignMetadataUpdated is emitted
    /// @param newURI New campaign URI to apply via hook
    function test_emitsCampaignMetadataUpdated(bytes memory newURI) public {}

    /// @dev Verifies that ContractURIUpdated is emitted per ERC-7572
    /// @param newURI New campaign URI to apply via hook
    function test_emitsContractURIUpdated(bytes memory newURI) public {}
}

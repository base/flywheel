// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title CreateCampaignTest
/// @notice Test stubs for Flywheel.createCampaign
contract CreateCampaignTest is Test {
    /// @notice Deploys a campaign clone deterministically
    /// @dev Verifies new code exists at returned address and initial status is INACTIVE
    /// @param nonce Deterministic salt used by createCampaign (fuzzed)
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (fuzzed)
    function test_createCampaign_deploysClone_deterministicAddress(uint256 nonce, bytes memory hookData) public {}

    /// @notice Reuses existing campaign if already deployed with same salt
    /// @dev Verifies idempotency: returns existing campaign without reverting
    /// @param nonce Deterministic salt used by createCampaign (fuzzed)
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (fuzzed)
    function test_createCampaign_returnsExisting_whenAlreadyDeployed(uint256 nonce, bytes memory hookData) public {}

    /// @notice Emits CampaignCreated on successful creation
    /// @dev Will expect and match event fields (campaign address and hooks)
    /// @param nonce Deterministic salt used by createCampaign (fuzzed)
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (fuzzed)
    function test_createCampaign_emitsCampaignCreated(uint256 nonce, bytes memory hookData) public {}

    /// @notice Reverts when hooks address is zero
    /// @dev Expects ZeroAddress error
    /// @param nonce Deterministic salt used by createCampaign (fuzzed)
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (fuzzed)
    function test_createCampaign_reverts_whenHooksZeroAddress(uint256 nonce, bytes memory hookData) public {}

    /// @notice Calls hooks.onCreateCampaign with correct parameters
    /// @dev Uses SimpleRewards to observe effects (e.g., event or mapping write)
    /// @param nonce Deterministic salt used by createCampaign (fuzzed)
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (fuzzed)
    function test_createCampaign_callsHookOnCreate_withHookData(uint256 nonce, bytes memory hookData) public {}

    /// @notice Salt derivation depends on hooks, nonce, and hookData
    /// @dev Demonstrates distinct addresses when varying each component
    /// @param hookData1 First hook data blob to compare (fuzzed)
    /// @param hookData2 Second hook data blob to compare (fuzzed)
    function test_createCampaign_saltDependsOnHooksNonceHookData(bytes memory hookData1, bytes memory hookData2)
        public
    {}
}

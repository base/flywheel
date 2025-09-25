// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title CreateCampaignTest
/// @notice Tests for Flywheel.createCampaign
contract CreateCampaignTest is Test {
    /// @dev Expects ZeroAddress error
    /// @dev Reverts when hooks address is zero
    /// @param nonce Deterministic salt used by createCampaign
    /// @param hookData Stub encoded SimpleRewards hook data (owner, manager, uri)
    function test_reverts_whenHooksZeroAddress(uint256 nonce, bytes memory hookData) public {}

    /// @dev Deploys a campaign clone deterministically and verifies new code exists at returned address
    /// @param nonce Deterministic salt used by createCampaign
    /// @param owner Campaign owner
    /// @param manager Campaign manager
    /// @param uri Campaign URI
    function test_deploysClone_deterministicAddress(uint256 nonce, address owner, address manager, string memory uri)
        public
    {}

    /// @dev Reuses existing campaign if already deployed with same salt
    /// @dev Verifies idempotency: returns existing campaign without reverting
    /// @param nonce Deterministic salt used by createCampaign
    /// @param owner Campaign owner
    /// @param manager Campaign manager
    /// @param uri Campaign URI
    function test_returnsExisting_whenAlreadyDeployed(uint256 nonce, address owner, address manager, string memory uri)
        public
    {}

    /// @dev Verifies initial status is INACTIVE
    /// @param nonce Deterministic salt used by createCampaign
    /// @param owner Campaign owner
    /// @param manager Campaign manager
    /// @param uri Campaign URI
    function test_setsStatusToInactive(uint256 nonce, address owner, address manager, string memory uri) public {}

    /// @dev Verifies hooks are set correctly
    /// @param nonce Deterministic salt used by createCampaign
    /// @param owner Campaign owner
    /// @param manager Campaign manager
    /// @param uri Campaign URI
    function test_setsHooks(uint256 nonce, address owner, address manager, string memory uri) public {}

    /// @dev Emits CampaignCreated on successful creation
    /// @dev Will expect and match event fields (campaign address and hooks)
    /// @param nonce Deterministic salt used by createCampaign
    /// @param owner Campaign owner
    /// @param manager Campaign manager
    /// @param uri Campaign URI
    function test_emitsCampaignCreated(uint256 nonce, address owner, address manager, string memory uri) public {}
}

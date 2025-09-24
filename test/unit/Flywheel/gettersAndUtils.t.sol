// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title GettersAndUtilsTest
/// @notice Test stubs for Flywheel getters and utility functions
contract GettersAndUtilsTest is Test {
    /// @notice campaignExists returns true after createCampaign
    /// @dev Verifies false for unknown addresses
    /// @param nonce Deterministic salt used by createCampaign (fuzzed)
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (fuzzed)
    function test_campaignExists_returnsCorrectly(uint256 nonce, bytes memory hookData) public {}

    /// @notice campaignHooks returns hook address
    /// @dev Uses onlyExists; asserts returned address equals hooks
    /// @param nonce Deterministic salt used by createCampaign (fuzzed)
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (fuzzed)
    function test_campaignHooks_returnsHooksAddress(uint256 nonce, bytes memory hookData) public {}

    /// @notice campaignStatus returns current status
    /// @dev Checks initial INACTIVE, then after status transitions
    /// @param nonce Deterministic salt used by createCampaign (fuzzed)
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (fuzzed)
    function test_campaignStatus_returnsCurrentStatus(uint256 nonce, bytes memory hookData) public {}

    /// @notice campaignURI returns hook-provided URI
    /// @dev With SimpleRewards, hookData sets URI
    /// @param uri The campaign URI to set via hook data (fuzzed)
    function test_campaignURI_returnsHookURI(bytes memory uri) public {}
}

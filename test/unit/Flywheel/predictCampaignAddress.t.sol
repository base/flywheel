// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title PredictCampaignAddressTest
/// @notice Test stubs for Flywheel.predictCampaignAddress
contract PredictCampaignAddressTest is Test {
    /// @notice Predicts address deterministically given hooks, nonce, hookData
    /// @dev Compares against actual deployed address
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (fuzzed)
    /// @param nonce Deterministic salt used by predict/create (fuzzed)
    function test_predictCampaignAddress_matchesActual(bytes memory hookData, uint256 nonce) public {}

    /// @notice Address changes when nonce changes
    /// @dev Same hooks and hookData, different nonce -> different address
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (kept constant) (fuzzed)
    /// @param nonce1 First nonce (fuzzed)
    /// @param nonce2 Second nonce (fuzzed)
    function test_predictCampaignAddress_changesWithNonce(bytes memory hookData, uint256 nonce1, uint256 nonce2)
        public
    {}

    /// @notice Address changes when hookData changes
    /// @dev Same hooks and nonce, different hookData -> different address
    /// @param hookData1 First hook data blob (fuzzed)
    /// @param hookData2 Second hook data blob (fuzzed)
    /// @param nonce Deterministic salt used by predict/create (kept constant) (fuzzed)
    function test_predictCampaignAddress_changesWithHookData(
        bytes memory hookData1,
        bytes memory hookData2,
        uint256 nonce
    ) public {}

    /// @notice Address changes when hooks changes
    /// @dev Different hooks instances yield different addresses even with same salt inputs
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri) (fuzzed)
    /// @param nonce Deterministic salt used by predict/create (fuzzed)
    function test_predictCampaignAddress_changesWithHooks(bytes memory hookData, uint256 nonce) public {}
}

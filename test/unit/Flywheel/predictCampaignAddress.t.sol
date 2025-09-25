// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title PredictCampaignAddressTest
/// @notice Tests for Flywheel.predictCampaignAddress
contract PredictCampaignAddressTest is Test {
    /// @dev Predicts address deterministically given hooks, nonce, and hookData
    /// @param hooks Hooks address
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri)
    /// @param nonce Deterministic salt used by predict/create
    function test_matchesActual(address hooks, bytes memory hookData, uint256 nonce) public {}

    /// @dev Address changes when nonce changes (same hooks and hookData)
    /// @param hooks Hooks address
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri)
    /// @param nonce1 First nonce
    /// @param nonce2 Second nonce
    function test_changesWithNonce(address hooks, bytes memory hookData, uint256 nonce1, uint256 nonce2) public {}

    /// @dev Address changes when hookData changes (same hooks and nonce)
    /// @param hooks Hooks address
    /// @param hookData1 First hook data blob
    /// @param hookData2 Second hook data blob
    /// @param nonce Deterministic salt used by predict/create
    function test_changesWithHookData(address hooks, bytes memory hookData1, bytes memory hookData2, uint256 nonce)
        public
    {}

    /// @dev Address changes when hooks change (different hook instances)
    /// @param hooks1 First hooks address
    /// @param hooks2 Second hooks address
    /// @param hookData Encoded SimpleRewards hook data (owner, manager, uri)
    /// @param nonce Deterministic salt used by predict/create
    function test_changesWithHooks(address hooks1, address hooks2, bytes memory hookData, uint256 nonce) public {}
}

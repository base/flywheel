// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {Campaign} from "../../../src/Campaign.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title UpdateContractURITest
/// @notice Tests for `Campaign.updateContractURI`
contract UpdateContractURITest is Test {
    /// @dev Expects OnlyFlywheel error when msg.sender != flywheel
    /// @dev Reverts when caller is not Flywheel
    /// @param caller Caller address
    function test_updateContractURI_reverts_whenCallerNotFlywheel(address caller) public {}

    /// @dev Verifies updateContractURI succeeds when called by Flywheel
    /// @dev Exercise path via Flywheel.updateMetadata which forwards to Campaign.updateContractURI
    /// @param nonce Deterministic salt for campaign creation
    /// @param owner Owner address to encode into hook data
    /// @param manager Manager address to encode into hook data
    /// @param uri Initial campaign URI
    function test_updateContractURI_succeeds_whenCalledByFlywheel(
        uint256 nonce,
        address owner,
        address manager,
        string memory uri
    ) public {}

    /// @dev Verifies updateContractURI emits ContractURIUpdated
    /// @param nonce Deterministic salt for campaign creation
    /// @param owner Owner address to encode into hook data
    /// @param manager Manager address to encode into hook data
    function test_updateContractURI_emitsContractURIUpdated(uint256 nonce, address owner, address manager) public {}
}

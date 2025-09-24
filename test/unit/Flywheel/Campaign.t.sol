// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {Campaign} from "../../../src/Campaign.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title CampaignTest
/// @notice Tests for `Campaign.sol`
contract CampaignTest is Test {
    /// @notice sendTokens reverts for non-Flywheel callers
    /// @dev Expects OnlyFlywheel error when msg.sender != flywheel
    /// @param caller Caller address
    function test_sendTokens_reverts_whenCallerNotFlywheel(address caller) public {}

    /// @notice updateContractURI reverts for non-Flywheel callers
    /// @dev Expects OnlyFlywheel error when msg.sender != flywheel
    /// @param caller Caller address
    function test_updateContractURI_reverts_whenCallerNotFlywheel(address caller) public {}

    /// @dev Verifies sendTokens succeeds for native token
    /// @param recipient Recipient address
    /// @param amount Amount to send
    function test_sendTokens_succeeds_forNativeToken(address recipient, uint256 amount) public {}

    /// @dev Verifies sendTokens succeeds for ERC20 token
    /// @param recipient Recipient address
    /// @param amount Amount to send
    function test_sendTokens_succeeds_forERC20Token(address recipient, uint256 amount) public {}

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

    /// @dev Expects contractURI returns value from Flywheel.campaignURI
    /// @param nonce Deterministic salt for campaign creation
    /// @param owner Owner address to encode into hook data
    /// @param manager Manager address to encode into hook data
    /// @param uri Campaign URI to encode into hook data
    function test_contractURI_returnsFlywheelCampaignURI(
        uint256 nonce,
        address owner,
        address manager,
        string memory uri
    ) public {}

    /// @dev Verifies ampaign can receive native tokens via receive()
    /// @param nonce Deterministic salt for campaign creation
    /// @param owner Owner address to encode into hook data
    /// @param manager Manager address to encode into hook data
    /// @param amount Native amount to send
    function test_receive_acceptsNativeToken(uint256 nonce, address owner, address manager, uint256 amount) public {}

    /// @dev Verifies updateContractURI emits ContractURIUpdated
    /// @param nonce Deterministic salt for campaign creation
    /// @param owner Owner address to encode into hook data
    /// @param manager Manager address to encode into hook data
    function test_updateContractURI_emitsContractURIUpdated(uint256 nonce, address owner, address manager) public {}
}

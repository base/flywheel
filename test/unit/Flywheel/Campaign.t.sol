// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {Campaign} from "../../../src/Campaign.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title CampaignTest
/// @notice Test stubs for `Campaign.sol` behaviors as exercised via Flywheel
contract CampaignTest is Test {
    /// @notice Only Flywheel can call Campaign.sendTokens; direct calls revert
    /// @dev Verifies direct call reverts and Flywheel-mediated call succeeds
    /// @param isNative When true, exercise native-token branch; otherwise ERC20 branch (fuzzed)
    /// @param recipient Recipient to receive funds when called via Flywheel (fuzzed)
    /// @param amount Amount to attempt to send (fuzzed)
    function test_campaignSendTokens_onlyCallableByFlywheel(bool isNative, address recipient, uint256 amount) public {}

    /// @notice Campaign clone has runtime code after createCampaign
    /// @dev Asserts extcodesize > 0 for the deployed campaign address
    /// @param nonce Deterministic salt used by createCampaign (fuzzed)
    /// @param owner Owner address to encode into hook data (fuzzed)
    /// @param manager Manager address to encode into hook data (fuzzed)
    /// @param uri Campaign URI to encode into hook data (fuzzed)
    function test_campaignClone_hasRuntimeCode(uint256 nonce, address owner, address manager, string memory uri)
        public
    {}
}

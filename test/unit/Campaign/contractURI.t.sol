// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {Campaign} from "../../../src/Campaign.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title ContractURITest
/// @notice Tests for `Campaign.contractURI`
contract ContractURITest is Test {
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
}

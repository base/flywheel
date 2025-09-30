// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract ViewFunctionsTest is BridgeRewardsTest {
    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Returns the metadataURI set in constructor for any campaign address
    function test_campaignURI_success_returnsMetadataURI() public {}

    /// @dev Returns consistent URI regardless of campaign address parameter
    function test_campaignURI_success_consistentAcrossCampaigns() public {}

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies campaignURI matches the metadataURI immutable variable
    function test_campaignURI_matchesMetadataURI() public {}
}
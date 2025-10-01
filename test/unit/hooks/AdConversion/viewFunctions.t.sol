// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

contract ViewFunctionsTest is AdConversionTestBase {
    // ========================================
    // CAMPAIGN URI TESTING
    // ========================================

    /// @dev Returns correct campaign URI
    /// @param campaign Campaign address
    /// @param expectedURI Expected campaign URI
    function test_campaignURI_returnsCorrectURI(address campaign, string memory expectedURI) public;

    /// @dev Returns empty string for campaign with empty URI
    /// @param campaign Campaign address with empty URI
    function test_campaignURI_returnsEmptyString(address campaign) public;

    // ========================================
    // GET CONVERSION CONFIG TESTING
    // ========================================

    /// @dev Returns correct conversion config for valid ID
    /// @param campaign Campaign address
    /// @param configId Valid conversion config ID
    function test_getConversionConfig_returnsCorrectConfig(address campaign, uint16 configId) public;

    /// @dev Reverts when conversion config ID does not exist
    /// @param campaign Campaign address
    /// @param invalidConfigId Non-existent conversion config ID
    function test_getConversionConfig_revert_invalidId(address campaign, uint16 invalidConfigId) public;

    /// @dev Returns config with correct active status
    /// @param campaign Campaign address
    /// @param configId Valid conversion config ID
    /// @param isActive Expected active status
    function test_getConversionConfig_returnsCorrectActiveStatus(address campaign, uint16 configId, bool isActive)
        public;

    /// @dev Returns config with correct onchain status
    /// @param campaign Campaign address
    /// @param configId Valid conversion config ID
    /// @param isOnchain Expected onchain status
    function test_getConversionConfig_returnsCorrectOnchainStatus(address campaign, uint16 configId, bool isOnchain)
        public;

    /// @dev Returns config with correct metadata URI
    /// @param campaign Campaign address
    /// @param configId Valid conversion config ID
    /// @param expectedMetadataURI Expected metadata URI
    function test_getConversionConfig_returnsCorrectMetadataURI(
        address campaign,
        uint16 configId,
        string memory expectedMetadataURI
    ) public;

    // ========================================
    // HAS PUBLISHER ALLOWLIST TESTING
    // ========================================

    /// @dev Returns false when campaign has no allowlist
    /// @param campaign Campaign address without allowlist
    function test_hasPublisherAllowlist_noAllowlist(address campaign) public;

    /// @dev Returns true when campaign has allowlist
    /// @param campaign Campaign address with allowlist
    function test_hasPublisherAllowlist_withAllowlist(address campaign) public;

    // ========================================
    // IS PUBLISHER REF CODE ALLOWED TESTING
    // ========================================

    /// @dev Returns true for any ref code when no allowlist exists
    /// @param campaign Campaign address without allowlist
    /// @param anyRefCode Any publisher reference code
    function test_isPublisherRefCodeAllowed_noAllowlist(address campaign, string memory anyRefCode) public;

    /// @dev Returns true for allowed ref code when allowlist exists
    /// @param campaign Campaign address with allowlist
    /// @param allowedRefCode Publisher ref code in allowlist
    function test_isPublisherRefCodeAllowed_allowedCode(address campaign, string memory allowedRefCode) public;

    /// @dev Returns false for disallowed ref code when allowlist exists
    /// @param campaign Campaign address with allowlist
    /// @param disallowedRefCode Publisher ref code not in allowlist
    function test_isPublisherRefCodeAllowed_disallowedCode(address campaign, string memory disallowedRefCode) public;

    /// @dev Returns false for empty ref code when allowlist exists
    /// @param campaign Campaign address with allowlist
    function test_isPublisherRefCodeAllowed_emptyCode(address campaign) public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles config ID zero (reserved)
    /// @param campaign Campaign address
    function test_getConversionConfig_edge_configIdZero(address campaign) public;

    /// @dev Handles maximum config ID
    /// @param campaign Campaign address
    /// @param maxConfigId Maximum valid config ID
    function test_getConversionConfig_edge_maximumConfigId(address campaign, uint16 maxConfigId) public;

    /// @dev Handles disabled conversion config
    /// @param campaign Campaign address
    /// @param disabledConfigId Disabled conversion config ID
    function test_getConversionConfig_edge_disabledConfig(address campaign, uint16 disabledConfigId) public;
}

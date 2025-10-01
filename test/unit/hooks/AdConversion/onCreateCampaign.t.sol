// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

contract OnCreateCampaignTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when attribution window duration is not in days precision
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param allowedRefCodes Array of allowed publisher ref codes
    /// @param configs Array of conversion configs
    /// @param invalidWindow Attribution window that is not divisible by 1 day
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_revert_invalidAttributionWindowPrecision(
        address attributionProvider,
        address advertiser,
        string memory uri,
        string[] memory allowedRefCodes,
        AdConversion.ConversionConfigInput[] memory configs,
        uint48 invalidWindow,
        uint16 feeBps
    ) public;

    /// @dev Reverts when attribution window exceeds 180 days maximum
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param allowedRefCodes Array of allowed publisher ref codes
    /// @param configs Array of conversion configs
    /// @param excessiveWindow Attribution window greater than 180 days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_revert_attributionWindowExceedsMaximum(
        address attributionProvider,
        address advertiser,
        string memory uri,
        string[] memory allowedRefCodes,
        AdConversion.ConversionConfigInput[] memory configs,
        uint48 excessiveWindow,
        uint16 feeBps
    ) public;

    /// @dev Reverts when attribution provider fee exceeds 100%
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param allowedRefCodes Array of allowed publisher ref codes
    /// @param configs Array of conversion configs
    /// @param attributionWindow Attribution window in days
    /// @param invalidFeeBps Fee BPS greater than MAX_BPS
    function test_onCreateCampaign_revert_invalidFeeBps(
        address attributionProvider,
        address advertiser,
        string memory uri,
        string[] memory allowedRefCodes,
        AdConversion.ConversionConfigInput[] memory configs,
        uint48 attributionWindow,
        uint16 invalidFeeBps
    ) public;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully creates campaign with valid parameters
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_success_basicCampaign(
        address attributionProvider,
        address advertiser,
        string memory uri,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Successfully creates campaign with zero attribution window
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_success_zeroAttributionWindow(
        address attributionProvider,
        address advertiser,
        string memory uri,
        uint16 feeBps
    ) public;

    /// @dev Successfully creates campaign with maximum 180-day attribution window
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_success_maximumAttributionWindow(
        address attributionProvider,
        address advertiser,
        string memory uri,
        uint16 feeBps
    ) public;

    /// @dev Successfully creates campaign with zero fee
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param attributionWindow Attribution window in days
    function test_onCreateCampaign_success_zeroFee(
        address attributionProvider,
        address advertiser,
        string memory uri,
        uint48 attributionWindow
    ) public;

    /// @dev Successfully creates campaign with maximum 100% fee
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param attributionWindow Attribution window in days
    function test_onCreateCampaign_success_maximumFee(
        address attributionProvider,
        address advertiser,
        string memory uri,
        uint48 attributionWindow
    ) public;

    /// @dev Successfully creates campaign with publisher allowlist
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param allowedRefCodes Array of allowed publisher ref codes
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_success_withAllowlist(
        address attributionProvider,
        address advertiser,
        string memory uri,
        string[] memory allowedRefCodes,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Successfully creates campaign without publisher allowlist
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_success_withoutAllowlist(
        address attributionProvider,
        address advertiser,
        string memory uri,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Successfully creates campaign with conversion configs
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param configs Array of conversion configs
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_success_withConversionConfigs(
        address attributionProvider,
        address advertiser,
        string memory uri,
        AdConversion.ConversionConfigInput[] memory configs,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Successfully creates campaign with empty conversion configs
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_success_emptyConversionConfigs(
        address attributionProvider,
        address advertiser,
        string memory uri,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles campaign with empty URI
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_edge_emptyURI(
        address attributionProvider,
        address advertiser,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Handles campaign with same attribution provider and advertiser
    /// @param sameAddress Address for both attribution provider and advertiser
    /// @param uri Campaign URI
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_edge_sameProviderAndAdvertiser(
        address sameAddress,
        string memory uri,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    // ========================================
    // EVENT TESTING
    // ========================================

    /// @dev Emits AdCampaignCreated event with correct parameters
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_emitsAdCampaignCreated(
        address attributionProvider,
        address advertiser,
        string memory uri,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Emits PublisherAddedToAllowlist events for each allowed publisher
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param allowedRefCodes Array of allowed publisher ref codes
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_emitsPublisherAddedToAllowlist(
        address attributionProvider,
        address advertiser,
        string memory uri,
        string[] memory allowedRefCodes,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Emits ConversionConfigAdded events for each conversion config
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param configs Array of conversion configs
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_emitsConversionConfigAdded(
        address attributionProvider,
        address advertiser,
        string memory uri,
        AdConversion.ConversionConfigInput[] memory configs,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies campaign state is correctly stored
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param allowedRefCodes Array of allowed publisher ref codes
    /// @param configs Array of conversion configs
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_verifiesStoredState(
        address attributionProvider,
        address advertiser,
        string memory uri,
        string[] memory allowedRefCodes,
        AdConversion.ConversionConfigInput[] memory configs,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Verifies conversion config count is correctly updated
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param configs Array of conversion configs
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_verifiesConversionConfigCount(
        address attributionProvider,
        address advertiser,
        string memory uri,
        AdConversion.ConversionConfigInput[] memory configs,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Verifies allowlist mapping is correctly populated
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param uri Campaign URI
    /// @param allowedRefCodes Array of allowed publisher ref codes
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_verifiesAllowlistMapping(
        address attributionProvider,
        address advertiser,
        string memory uri,
        string[] memory allowedRefCodes,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Verifies campaign metadata URI is correctly stored
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param campaignURI Campaign metadata URI
    /// @param attributionWindow Attribution window duration
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_storesCampaignURI(
        address advertiser,
        address attributionProvider,
        string memory campaignURI,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Verifies allowlist flag is correctly set when no allowlist provided
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param attributionWindow Attribution window duration
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_setsNoAllowlistFlag(
        address advertiser,
        address attributionProvider,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Verifies allowlist flag is correctly set when allowlist provided
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param allowedRefCodes Array of allowed publisher reference codes
    /// @param attributionWindow Attribution window duration
    /// @param feeBps Attribution provider fee in basis points
    function test_onCreateCampaign_setsAllowlistFlag(
        address advertiser,
        address attributionProvider,
        string[] memory allowedRefCodes,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;
}

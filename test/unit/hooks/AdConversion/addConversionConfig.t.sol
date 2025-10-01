// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

contract AddConversionConfigTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when caller is not the advertiser
    /// @param unauthorizedCaller Unauthorized caller address (not advertiser)
    /// @param campaign Campaign address
    /// @param configInput Conversion config input data
    function test_addConversionConfig_revert_unauthorizedCaller(
        address unauthorizedCaller,
        address campaign,
        AdConversion.ConversionConfigInput memory configInput
    ) public;

    /// @dev Reverts when conversion config count exceeds maximum limit
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with maximum configs
    /// @param configInput Additional conversion config input data
    /// @param maxConfigs Maximum allowed conversion configs
    function test_addConversionConfig_revert_exceedsMaximumConfigs(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput memory configInput,
        uint16 maxConfigs
    ) public;

    /// @dev Reverts when integer overflow occurs in config count
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with near-maximum config count
    /// @param configInput Conversion config input data
    function test_addConversionConfig_revert_configCountOverflow(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput memory configInput
    ) public;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully adds onchain conversion config
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param name Config name
    /// @param description Config description
    function test_addConversionConfig_success_onchainConfig(
        address advertiser,
        address campaign,
        string memory metadataURI,
        string memory description
    ) public;

    /// @dev Successfully adds offchain conversion config
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param name Config name
    /// @param description Config description
    function test_addConversionConfig_success_offchainConfig(
        address advertiser,
        address campaign,
        string memory metadataURI,
        string memory description
    ) public;

    /// @dev Successfully adds multiple conversion configs to same campaign
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param config1 First conversion config input
    /// @param config2 Second conversion config input
    function test_addConversionConfig_success_multipleConfigs(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput memory config1,
        AdConversion.ConversionConfigInput memory config2
    ) public;

    /// @dev Successfully adds config with empty metadata URI
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param metadataURI Config metadata URI
    /// @param isOnchain Whether config is onchain or offchain
    function test_addConversionConfig_success_emptyMetadataURI(
        address advertiser,
        address campaign,
        string memory metadataURI,
        bool isOnchain
    ) public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles adding config with very long metadata URI
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param longMetadataURI Very long config metadata URI
    /// @param isOnchain Whether config is onchain or offchain
    function test_addConversionConfig_edge_longMetadataURI(
        address advertiser,
        address campaign,
        string memory longMetadataURI,
        bool isOnchain
    ) public;

    /// @dev Handles adding config with special characters in metadata URI
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param specialMetadataURI Metadata URI with special characters
    /// @param isOnchain Whether config is onchain or offchain
    function test_addConversionConfig_edge_specialCharacters(
        address advertiser,
        address campaign,
        string memory specialMetadataURI,
        bool isOnchain
    ) public;

    /// @dev Handles adding maximum number of configs (up to limit)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configInputs Array of conversion config inputs up to limit
    function test_addConversionConfig_edge_maximumConfigs(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput[] memory configInputs
    ) public;

    /// @dev Handles adding configs with identical metadata URIs (should be allowed)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param sameMetadataURI Same config metadata URI for both configs
    /// @param isOnchain1 First config type
    /// @param isOnchain2 Second config type
    function test_addConversionConfig_edge_identicalMetadataURI(
        address advertiser,
        address campaign,
        string memory sameMetadataURI,
        bool isOnchain1,
        bool isOnchain2
    ) public;

    // ========================================
    // CONFIG ID TESTING
    // ========================================

    /// @dev Verifies config IDs are assigned sequentially starting from 1
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configInputs Array of conversion config inputs
    function test_addConversionConfig_assignsSequentialIds(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput[] memory configInputs
    ) public;

    /// @dev Verifies config ID 0 is reserved (never assigned)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configInput Conversion config input
    function test_addConversionConfig_reservesIdZero(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput memory configInput
    ) public;

    /// @dev Verifies config IDs are unique across campaign
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param manyConfigInputs Large array of conversion config inputs
    function test_addConversionConfig_uniqueIdsPerCampaign(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput[] memory manyConfigInputs
    ) public;

    // ========================================
    // EVENT TESTING
    // ========================================

    /// @dev Emits ConversionConfigAdded event with correct parameters
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configInput Conversion config input
    function test_addConversionConfig_emitsConversionConfigAdded(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput memory configInput
    ) public;

    /// @dev Emits multiple events when adding multiple configs
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param config1 First conversion config input
    /// @param config2 Second conversion config input
    function test_addConversionConfig_emitsMultipleEvents(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput memory config1,
        AdConversion.ConversionConfigInput memory config2
    ) public;

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies config count is correctly incremented
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configInputs Array of conversion config inputs
    function test_addConversionConfig_incrementsConfigCount(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput[] memory configInputs
    ) public;

    /// @dev Verifies config status is set to ACTIVE by default
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configInput Conversion config input
    function test_addConversionConfig_setsActiveStatus(
        address advertiser,
        address campaign,
        AdConversion.ConversionConfigInput memory configInput
    ) public;
}

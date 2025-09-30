// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

contract DisableConversionConfigTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when caller is not the advertiser
    /// @param unauthorizedCaller Unauthorized caller address (not advertiser)
    /// @param campaign Campaign address
    /// @param configId Conversion config ID to disable
    function test_disableConversionConfig_revert_unauthorizedCaller(
        address unauthorizedCaller,
        address campaign,
        uint16 configId
    ) public;

    /// @dev Reverts when conversion config ID does not exist
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param nonExistentConfigId Non-existent conversion config ID
    function test_disableConversionConfig_revert_configDoesNotExist(
        address advertiser,
        address campaign,
        uint16 nonExistentConfigId
    ) public;

    /// @dev Reverts when trying to disable config ID 0 (reserved)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    function test_disableConversionConfig_revert_configIdZero(
        address advertiser,
        address campaign
    ) public;

    /// @dev Reverts when conversion config is already inactive
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with inactive config
    /// @param inactiveConfigId Already inactive conversion config ID
    function test_disableConversionConfig_revert_configAlreadyInactive(
        address advertiser,
        address campaign,
        uint16 inactiveConfigId
    ) public;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully disables active conversion config
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param activeConfigId Active conversion config ID
    function test_disableConversionConfig_success_disableActiveConfig(
        address advertiser,
        address campaign,
        uint16 activeConfigId
    ) public;

    /// @dev Successfully disables multiple conversion configs
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configId1 First active conversion config ID
    /// @param configId2 Second active conversion config ID
    function test_disableConversionConfig_success_disableMultipleConfigs(
        address advertiser,
        address campaign,
        uint16 configId1,
        uint16 configId2
    ) public;

    /// @dev Successfully disables onchain conversion config
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param onchainConfigId Active onchain conversion config ID
    function test_disableConversionConfig_success_disableOnchainConfig(
        address advertiser,
        address campaign,
        uint16 onchainConfigId
    ) public;

    /// @dev Successfully disables offchain conversion config
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param offchainConfigId Active offchain conversion config ID
    function test_disableConversionConfig_success_disableOffchainConfig(
        address advertiser,
        address campaign,
        uint16 offchainConfigId
    ) public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles disabling config with maximum valid ID
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with maximum configs
    /// @param maxConfigId Maximum valid conversion config ID
    function test_disableConversionConfig_edge_maximumConfigId(
        address advertiser,
        address campaign,
        uint16 maxConfigId
    ) public;

    /// @dev Handles disabling config ID 1 (first valid ID)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with single config
    function test_disableConversionConfig_edge_configIdOne(
        address advertiser,
        address campaign
    ) public;

    /// @dev Handles disabling configs in non-sequential order
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with multiple configs
    /// @param configIds Array of config IDs to disable in random order
    function test_disableConversionConfig_edge_nonSequentialDisabling(
        address advertiser,
        address campaign,
        uint16[] memory configIds
    ) public;

    /// @dev Handles disabling all configs in campaign
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with multiple configs
    /// @param allConfigIds All config IDs in campaign
    function test_disableConversionConfig_edge_disableAllConfigs(
        address advertiser,
        address campaign,
        uint16[] memory allConfigIds
    ) public;

    /// @dev Handles campaign with mix of active and inactive configs
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with mixed config states
    /// @param activeConfigId Currently active config to disable
    /// @param inactiveConfigId Already inactive config
    function test_disableConversionConfig_edge_mixedConfigStates(
        address advertiser,
        address campaign,
        uint16 activeConfigId,
        uint16 inactiveConfigId
    ) public;

    // ========================================
    // EVENT TESTING
    // ========================================

    /// @dev Emits ConversionConfigStatusChanged event with correct parameters
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configId Active conversion config ID to disable
    function test_disableConversionConfig_emitsConversionConfigStatusChanged(
        address advertiser,
        address campaign,
        uint16 configId
    ) public;

    /// @dev Emits multiple events when disabling multiple configs
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configId1 First active conversion config ID
    /// @param configId2 Second active conversion config ID
    function test_disableConversionConfig_emitsMultipleEvents(
        address advertiser,
        address campaign,
        uint16 configId1,
        uint16 configId2
    ) public;

    /// @dev Verifies event contains correct status transition (ACTIVE → INACTIVE)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configId Active conversion config ID to disable
    function test_disableConversionConfig_eventContainsCorrectStatusTransition(
        address advertiser,
        address campaign,
        uint16 configId
    ) public;

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies config status is correctly updated to INACTIVE
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configId Active conversion config ID to disable
    function test_disableConversionConfig_updatesConfigStatus(
        address advertiser,
        address campaign,
        uint16 configId
    ) public;

    /// @dev Verifies config data remains unchanged except status
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configId Active conversion config ID to disable
    function test_disableConversionConfig_preservesConfigData(
        address advertiser,
        address campaign,
        uint16 configId
    ) public;

    /// @dev Verifies other configs remain unaffected
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with multiple configs
    /// @param configToDisable Config ID to disable
    /// @param otherConfigIds Other config IDs that should remain unchanged
    function test_disableConversionConfig_preservesOtherConfigs(
        address advertiser,
        address campaign,
        uint16 configToDisable,
        uint16[] memory otherConfigIds
    ) public;

    /// @dev Verifies config count remains unchanged
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configId Active conversion config ID to disable
    function test_disableConversionConfig_preservesConfigCount(
        address advertiser,
        address campaign,
        uint16 configId
    ) public;

    // ========================================
    // IDEMPOTENCY TESTING
    // ========================================

    /// @dev Verifies disabling already inactive config fails (not idempotent)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configId Config ID to disable twice
    function test_disableConversionConfig_notIdempotent(
        address advertiser,
        address campaign,
        uint16 configId
    ) public;

    /// @dev Verifies config cannot be re-enabled after disabling
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configId Config ID to disable
    function test_disableConversionConfig_cannotReEnable(
        address advertiser,
        address campaign,
        uint16 configId
    ) public;

    // ========================================
    // INTEGRATION TESTING
    // ========================================

    /// @dev Verifies disabled configs are not usable in onSend operations
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param configId Config ID to disable and test
    /// @param attributions Conversion attributions using disabled config
    function test_disableConversionConfig_unusableInOnSend(
        address advertiser,
        address campaign,
        uint16 configId,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Verifies campaign with all disabled configs still functions for other operations
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with all configs disabled
    /// @param allConfigIds All config IDs in campaign
    function test_disableConversionConfig_campaignStillFunctional(
        address advertiser,
        address campaign,
        uint16[] memory allConfigIds
    ) public;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

contract OnUpdateMetadataTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when caller is not attribution provider or advertiser
    /// @param unauthorizedCaller Unauthorized caller address
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    function test_onUpdateMetadata_revert_unauthorizedCaller(
        address unauthorizedCaller,
        address campaign,
        string memory newMetadata
    ) public;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully updates metadata when called by attribution provider
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    function test_onUpdateMetadata_success_attributionProvider(
        address attributionProvider,
        address campaign,
        string memory newMetadata
    ) public;

    /// @dev Successfully updates metadata when called by advertiser
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    function test_onUpdateMetadata_success_advertiser(
        address advertiser,
        address campaign,
        string memory newMetadata
    ) public;

    /// @dev Successfully updates metadata with empty string
    /// @param authorizedCaller Authorized caller (attribution provider or advertiser)
    /// @param campaign Campaign address
    function test_onUpdateMetadata_success_emptyMetadata(
        address authorizedCaller,
        address campaign
    ) public;

    /// @dev Successfully updates metadata with very long string
    /// @param authorizedCaller Authorized caller (attribution provider or advertiser)
    /// @param campaign Campaign address
    /// @param longMetadata Very long metadata string
    function test_onUpdateMetadata_success_longMetadata(
        address authorizedCaller,
        address campaign,
        string memory longMetadata
    ) public;

    /// @dev Successfully updates metadata multiple times
    /// @param authorizedCaller Authorized caller (attribution provider or advertiser)
    /// @param campaign Campaign address
    /// @param firstMetadata First metadata string
    /// @param secondMetadata Second metadata string
    function test_onUpdateMetadata_success_multipleUpdates(
        address authorizedCaller,
        address campaign,
        string memory firstMetadata,
        string memory secondMetadata
    ) public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles metadata update with special characters
    /// @param authorizedCaller Authorized caller (attribution provider or advertiser)
    /// @param campaign Campaign address
    /// @param specialMetadata Metadata containing special characters
    function test_onUpdateMetadata_edge_specialCharacters(
        address authorizedCaller,
        address campaign,
        string memory specialMetadata
    ) public;

    /// @dev Handles metadata update when provider and advertiser are same address
    /// @param sameAddress Address for both attribution provider and advertiser
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    function test_onUpdateMetadata_edge_sameProviderAndAdvertiser(
        address sameAddress,
        address campaign,
        string memory newMetadata
    ) public;

    /// @dev Handles metadata update across different campaign statuses
    /// @param authorizedCaller Authorized caller (attribution provider or advertiser)
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    /// @param campaignStatus Current campaign status
    function test_onUpdateMetadata_edge_differentCampaignStatuses(
        address authorizedCaller,
        address campaign,
        string memory newMetadata,
        uint8 campaignStatus
    ) public;

    // ========================================
    // AUTHORIZATION TESTING
    // ========================================

    /// @dev Verifies both attribution provider and advertiser can update metadata
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param providerMetadata Metadata set by attribution provider
    /// @param advertiserMetadata Metadata set by advertiser
    function test_onUpdateMetadata_bothPartiesCanUpdate(
        address attributionProvider,
        address advertiser,
        address campaign,
        string memory providerMetadata,
        string memory advertiserMetadata
    ) public;

    /// @dev Verifies unauthorized addresses cannot update metadata
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param unauthorizedCaller Unauthorized caller address
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    function test_onUpdateMetadata_onlyAuthorizedCanUpdate(
        address attributionProvider,
        address advertiser,
        address unauthorizedCaller,
        address campaign,
        string memory newMetadata
    ) public;
}
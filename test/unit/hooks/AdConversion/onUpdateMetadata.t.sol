// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

abstract contract OnUpdateMetadataTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when caller is not attribution provider or advertiser
    /// @param unauthorizedCaller Unauthorized caller address
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    function test_revert_unauthorizedCaller(address unauthorizedCaller, address campaign, string memory newMetadata)
        public
        virtual;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully updates metadata when called by attribution provider
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    function test_success_attributionProvider(address attributionProvider, address campaign, string memory newMetadata)
        public
        virtual;

    /// @dev Successfully updates metadata when called by advertiser
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    function test_success_advertiser(address advertiser, address campaign, string memory newMetadata) public virtual;

    /// @dev Successfully updates metadata with empty string
    /// @param authorizedCaller Authorized caller (attribution provider or advertiser)
    /// @param campaign Campaign address
    function test_success_emptyMetadata(address authorizedCaller, address campaign) public virtual;

    /// @dev Successfully updates metadata with very long string
    /// @param authorizedCaller Authorized caller (attribution provider or advertiser)
    /// @param campaign Campaign address
    /// @param longMetadata Very long metadata string
    function test_success_longMetadata(address authorizedCaller, address campaign, string memory longMetadata)
        public
        virtual;

    /// @dev Successfully updates metadata multiple times
    /// @param authorizedCaller Authorized caller (attribution provider or advertiser)
    /// @param campaign Campaign address
    /// @param firstMetadata First metadata string
    /// @param secondMetadata Second metadata string
    function test_success_multipleUpdates(
        address authorizedCaller,
        address campaign,
        string memory firstMetadata,
        string memory secondMetadata
    ) public virtual;

    // ========================================
    // EDGE CASES
    // ========================================
    /// @dev Handles metadata update when provider and advertiser are same address
    /// @param sameAddress Address for both attribution provider and advertiser
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    function test_edge_sameProviderAndAdvertiser(address sameAddress, address campaign, string memory newMetadata)
        public
        virtual;

    /// @dev Handles metadata update across different campaign statuses
    /// @param authorizedCaller Authorized caller (attribution provider or advertiser)
    /// @param campaign Campaign address
    /// @param newMetadata New metadata string
    /// @param campaignStatus Current campaign status
    function test_edge_differentCampaignStatuses(
        address authorizedCaller,
        address campaign,
        string memory newMetadata,
        uint8 campaignStatus
    ) public virtual;
}

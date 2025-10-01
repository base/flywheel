// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

abstract contract OnUpdateStatusTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES - UNAUTHORIZED TRANSITIONS
    // ========================================

    /// @dev Reverts when unauthorized caller attempts any status transition
    /// @param unauthorizedCaller Unauthorized caller address
    /// @param campaign Campaign address
    /// @param fromStatus Current campaign status
    /// @param toStatus Target campaign status
    /// @param metadata Status update metadata
    function test_revert_unauthorizedCaller(
        address unauthorizedCaller,
        address campaign,
        uint8 fromStatus,
        uint8 toStatus,
        string memory metadata
    ) public virtual;

    /// @dev Reverts when attribution provider tries unauthorized INACTIVE → FINALIZING transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_revert_providerInactiveToFinalizing(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public virtual;

    /// @dev Reverts when attribution provider tries unauthorized INACTIVE → FINALIZED transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_revert_providerInactiveToFinalized(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public virtual;

    /// @dev Reverts when attribution provider tries unauthorized ACTIVE → INACTIVE transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_revert_providerActiveToInactive(address attributionProvider, address campaign, string memory metadata)
        public
        virtual;

    /// @dev Reverts when advertiser tries unauthorized INACTIVE → ACTIVE transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_revert_advertiserInactiveToActive(address advertiser, address campaign, string memory metadata)
        public
        virtual;

    /// @dev Reverts when advertiser tries unauthorized INACTIVE → FINALIZING transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_revert_advertiserInactiveToFinalizing(address advertiser, address campaign, string memory metadata)
        public
        virtual;

    /// @dev Reverts when advertiser tries unauthorized ACTIVE → INACTIVE transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_revert_advertiserActiveToInactive(address advertiser, address campaign, string memory metadata)
        public
        virtual;

    /// @dev Reverts when advertiser tries unauthorized ACTIVE → FINALIZED transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_revert_advertiserActiveToFinalized(address advertiser, address campaign, string memory metadata)
        public
        virtual;

    /// @dev Reverts when advertiser tries FINALIZING → FINALIZED before attribution deadline
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in FINALIZING status
    /// @param metadata Status update metadata
    /// @param currentTime Current timestamp before deadline
    function test_revert_advertiserFinalizingToFinalizedBeforeDeadline(
        address advertiser,
        address campaign,
        string memory metadata,
        uint256 currentTime
    ) public virtual;

    // ========================================
    // SUCCESS CASES - ATTRIBUTION PROVIDER TRANSITIONS
    // ========================================

    /// @dev Successfully allows attribution provider INACTIVE → ACTIVE transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_success_providerInactiveToActive(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public virtual;

    /// @dev Successfully allows attribution provider ACTIVE → FINALIZING transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_success_providerActiveToFinalizing(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public virtual;

    /// @dev Successfully allows attribution provider ACTIVE → FINALIZED transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_success_providerActiveToFinalized(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public virtual;

    /// @dev Successfully allows attribution provider FINALIZING → FINALIZED transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in FINALIZING status
    /// @param metadata Status update metadata
    function test_success_providerFinalizingToFinalized(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public virtual;

    // ========================================
    // SUCCESS CASES - ADVERTISER TRANSITIONS
    // ========================================

    /// @dev Successfully allows advertiser INACTIVE → FINALIZED transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_success_advertiserInactiveToFinalized(address advertiser, address campaign, string memory metadata)
        public
        virtual;

    /// @dev Successfully allows advertiser ACTIVE → FINALIZING transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_success_advertiserActiveToFinalizing(address advertiser, address campaign, string memory metadata)
        public
        virtual;

    /// @dev Successfully allows advertiser FINALIZING → FINALIZED after attribution deadline
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in FINALIZING status
    /// @param metadata Status update metadata
    /// @param currentTime Current timestamp after deadline
    function test_success_advertiserFinalizingToFinalizedAfterDeadline(
        address advertiser,
        address campaign,
        string memory metadata,
        uint256 currentTime
    ) public virtual;

    // ========================================
    // ATTRIBUTION DEADLINE TESTING
    // ========================================

    /// @dev Sets attribution deadline when transitioning to FINALIZING with attribution window
    /// @param caller Authorized caller address
    /// @param campaign Campaign address with attribution window
    /// @param metadata Status update metadata
    /// @param attributionWindow Campaign attribution window in seconds
    function test_setsAttributionDeadline(
        address caller,
        address campaign,
        string memory metadata,
        uint48 attributionWindow
    ) public virtual;

    /// @dev Does not set attribution deadline when transitioning to FINALIZING with zero window
    /// @param caller Authorized caller address
    /// @param campaign Campaign address with zero attribution window
    /// @param metadata Status update metadata
    function test_noDeadlineWithZeroWindow(address caller, address campaign, string memory metadata) public virtual;

    /// @dev Calculates correct attribution deadline timestamp
    /// @param caller Authorized caller address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    /// @param attributionWindow Campaign attribution window in seconds
    /// @param currentTime Current block timestamp
    function test_calculatesCorrectDeadline(
        address caller,
        address campaign,
        string memory metadata,
        uint48 attributionWindow,
        uint256 currentTime
    ) public virtual;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles status transition with empty metadata
    /// @param caller Authorized caller address
    /// @param campaign Campaign address
    /// @param fromStatus Current valid status
    /// @param toStatus Target valid status
    function test_edge_emptyMetadata(address caller, address campaign, uint8 fromStatus, uint8 toStatus)
        public
        virtual;

    /// @dev Handles attribution deadline exactly at current timestamp
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in FINALIZING status
    /// @param metadata Status update metadata
    /// @param exactDeadlineTime Timestamp exactly at attribution deadline
    function test_edge_exactDeadlineTime(
        address advertiser,
        address campaign,
        string memory metadata,
        uint256 exactDeadlineTime
    ) public virtual;

    /// @dev Handles maximum attribution window value
    /// @param caller Authorized caller address
    /// @param campaign Campaign address with maximum attribution window
    /// @param metadata Status update metadata
    function test_edge_maximumAttributionWindow(address caller, address campaign, string memory metadata)
        public
        virtual;

    /// @dev Handles same attribution provider and advertiser address
    /// @param sameAddress Address for both attribution provider and advertiser
    /// @param campaign Campaign address
    /// @param fromStatus Current status
    /// @param toStatus Target status
    /// @param metadata Status update metadata
    function test_edge_sameProviderAndAdvertiser(
        address sameAddress,
        address campaign,
        uint8 fromStatus,
        uint8 toStatus,
        string memory metadata
    ) public virtual;

    // ========================================
    // EVENT TESTING
    // ========================================

    /// @dev Emits AttributionDeadlineUpdated event when entering FINALIZING with attribution window
    /// @param caller Authorized caller address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    /// @param attributionWindow Campaign attribution window
    function test_emitsAttributionDeadlineUpdated(
        address caller,
        address campaign,
        string memory metadata,
        uint48 attributionWindow
    ) public virtual;

    /// @dev Does not emit AttributionDeadlineUpdated when attribution window is zero
    /// @param caller Authorized caller address
    /// @param campaign Campaign address with zero attribution window
    /// @param metadata Status update metadata
    function test_noEventWithZeroWindow(address caller, address campaign, string memory metadata) public virtual;

    /// @dev Does not emit AttributionDeadlineUpdated for non-FINALIZING transitions
    /// @param caller Authorized caller address
    /// @param campaign Campaign address
    /// @param fromStatus Non-FINALIZING source status
    /// @param toStatus Non-FINALIZING target status
    /// @param metadata Status update metadata
    function test_noEventForNonFinalizingTransitions(
        address caller,
        address campaign,
        uint8 fromStatus,
        uint8 toStatus,
        string memory metadata
    ) public virtual;

    // ========================================
    // COMPLEX TRANSITION SCENARIOS
    // ========================================

    /// @dev Tests complete campaign lifecycle transitions
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    /// @param attributionWindow Campaign attribution window
    function test_completeCampaignLifecycle(
        address attributionProvider,
        address advertiser,
        address campaign,
        string memory metadata,
        uint48 attributionWindow
    ) public virtual;

    /// @dev Tests attribution provider can bypass advertiser deadline wait
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in FINALIZING status
    /// @param metadata Status update metadata
    /// @param currentTime Time before attribution deadline
    function test_providerBypassesDeadline(
        address attributionProvider,
        address advertiser,
        address campaign,
        string memory metadata,
        uint256 currentTime
    ) public virtual;
}

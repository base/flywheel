// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

contract OnUpdateStatusTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES - UNAUTHORIZED TRANSITIONS
    // ========================================

    /// @dev Reverts when attribution provider tries unauthorized INACTIVE → FINALIZED transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_onUpdateStatus_revert_providerInactiveToFinalized(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Reverts when attribution provider tries unauthorized ACTIVE → INACTIVE transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_revert_providerActiveToInactive(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Reverts when advertiser tries unauthorized INACTIVE → ACTIVE transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_onUpdateStatus_revert_advertiserInactiveToActive(
        address advertiser,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Reverts when advertiser tries unauthorized ACTIVE → INACTIVE transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_revert_advertiserActiveToInactive(
        address advertiser,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Reverts when advertiser tries unauthorized ACTIVE → FINALIZED transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_revert_advertiserActiveToFinalized(
        address advertiser,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Reverts when advertiser tries FINALIZING → FINALIZED before attribution deadline
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in FINALIZING status
    /// @param metadata Status update metadata
    /// @param currentTime Current timestamp before deadline
    function test_onUpdateStatus_revert_advertiserFinalizingToFinalizedBeforeDeadline(
        address advertiser,
        address campaign,
        string memory metadata,
        uint256 currentTime
    ) public;

    /// @dev Reverts when unauthorized caller attempts any status transition
    /// @param unauthorizedCaller Unauthorized caller address
    /// @param campaign Campaign address
    /// @param fromStatus Current campaign status
    /// @param toStatus Target campaign status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_revert_unauthorizedCaller(
        address unauthorizedCaller,
        address campaign,
        uint8 fromStatus,
        uint8 toStatus,
        string memory metadata
    ) public;

    // ========================================
    // SUCCESS CASES - ATTRIBUTION PROVIDER TRANSITIONS
    // ========================================

    /// @dev Successfully allows attribution provider INACTIVE → ACTIVE transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_onUpdateStatus_success_providerInactiveToActive(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Successfully allows attribution provider ACTIVE → FINALIZING transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_success_providerActiveToFinalizing(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Successfully allows attribution provider FINALIZING → FINALIZED transition
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in FINALIZING status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_success_providerFinalizingToFinalized(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public;

    // ========================================
    // SUCCESS CASES - ADVERTISER TRANSITIONS
    // ========================================

    /// @dev Successfully allows advertiser INACTIVE → FINALIZED transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_onUpdateStatus_success_advertiserInactiveToFinalized(
        address advertiser,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Successfully allows advertiser ACTIVE → FINALIZING transition
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_success_advertiserActiveToFinalizing(
        address advertiser,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Successfully allows advertiser FINALIZING → FINALIZED after attribution deadline
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in FINALIZING status
    /// @param metadata Status update metadata
    /// @param currentTime Current timestamp after deadline
    function test_onUpdateStatus_success_advertiserFinalizingToFinalizedAfterDeadline(
        address advertiser,
        address campaign,
        string memory metadata,
        uint256 currentTime
    ) public;

    // ========================================
    // ATTRIBUTION DEADLINE TESTING
    // ========================================

    /// @dev Sets attribution deadline when transitioning to FINALIZING with attribution window
    /// @param caller Authorized caller address
    /// @param campaign Campaign address with attribution window
    /// @param metadata Status update metadata
    /// @param attributionWindow Campaign attribution window in seconds
    function test_onUpdateStatus_setsAttributionDeadline(
        address caller,
        address campaign,
        string memory metadata,
        uint48 attributionWindow
    ) public;

    /// @dev Does not set attribution deadline when transitioning to FINALIZING with zero window
    /// @param caller Authorized caller address
    /// @param campaign Campaign address with zero attribution window
    /// @param metadata Status update metadata
    function test_onUpdateStatus_noDeadlineWithZeroWindow(
        address caller,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Calculates correct attribution deadline timestamp
    /// @param caller Authorized caller address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    /// @param attributionWindow Campaign attribution window in seconds
    /// @param currentTime Current block timestamp
    function test_onUpdateStatus_calculatesCorrectDeadline(
        address caller,
        address campaign,
        string memory metadata,
        uint48 attributionWindow,
        uint256 currentTime
    ) public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles status transition with empty metadata
    /// @param caller Authorized caller address
    /// @param campaign Campaign address
    /// @param fromStatus Current valid status
    /// @param toStatus Target valid status
    function test_onUpdateStatus_edge_emptyMetadata(
        address caller,
        address campaign,
        uint8 fromStatus,
        uint8 toStatus
    ) public;

    /// @dev Handles status transition with very long metadata
    /// @param caller Authorized caller address
    /// @param campaign Campaign address
    /// @param fromStatus Current valid status
    /// @param toStatus Target valid status
    /// @param longMetadata Very long metadata string
    function test_onUpdateStatus_edge_longMetadata(
        address caller,
        address campaign,
        uint8 fromStatus,
        uint8 toStatus,
        string memory longMetadata
    ) public;

    /// @dev Handles attribution deadline exactly at current timestamp
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in FINALIZING status
    /// @param metadata Status update metadata
    /// @param exactDeadlineTime Timestamp exactly at attribution deadline
    function test_onUpdateStatus_edge_exactDeadlineTime(
        address advertiser,
        address campaign,
        string memory metadata,
        uint256 exactDeadlineTime
    ) public;

    /// @dev Handles maximum attribution window value
    /// @param caller Authorized caller address
    /// @param campaign Campaign address with maximum attribution window
    /// @param metadata Status update metadata
    function test_onUpdateStatus_edge_maximumAttributionWindow(
        address caller,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Handles same attribution provider and advertiser address
    /// @param sameAddress Address for both attribution provider and advertiser
    /// @param campaign Campaign address
    /// @param fromStatus Current status
    /// @param toStatus Target status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_edge_sameProviderAndAdvertiser(
        address sameAddress,
        address campaign,
        uint8 fromStatus,
        uint8 toStatus,
        string memory metadata
    ) public;

    // ========================================
    // EVENT TESTING
    // ========================================

    /// @dev Emits AttributionDeadlineUpdated event when entering FINALIZING with attribution window
    /// @param caller Authorized caller address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    /// @param attributionWindow Campaign attribution window
    function test_onUpdateStatus_emitsAttributionDeadlineUpdated(
        address caller,
        address campaign,
        string memory metadata,
        uint48 attributionWindow
    ) public;

    /// @dev Does not emit AttributionDeadlineUpdated when attribution window is zero
    /// @param caller Authorized caller address
    /// @param campaign Campaign address with zero attribution window
    /// @param metadata Status update metadata
    function test_onUpdateStatus_noEventWithZeroWindow(
        address caller,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Does not emit AttributionDeadlineUpdated for non-FINALIZING transitions
    /// @param caller Authorized caller address
    /// @param campaign Campaign address
    /// @param fromStatus Non-FINALIZING source status
    /// @param toStatus Non-FINALIZING target status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_noEventForNonFinalizingTransitions(
        address caller,
        address campaign,
        uint8 fromStatus,
        uint8 toStatus,
        string memory metadata
    ) public;

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies attribution deadline is correctly stored in campaign state
    /// @param caller Authorized caller address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    /// @param attributionWindow Campaign attribution window
    function test_onUpdateStatus_storesCorrectDeadline(
        address caller,
        address campaign,
        string memory metadata,
        uint48 attributionWindow
    ) public;

    /// @dev Verifies campaign state remains unchanged for unauthorized transitions
    /// @param unauthorizedCaller Unauthorized caller address
    /// @param campaign Campaign address
    /// @param fromStatus Current campaign status
    /// @param toStatus Target campaign status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_preservesStateOnUnauthorized(
        address unauthorizedCaller,
        address campaign,
        uint8 fromStatus,
        uint8 toStatus,
        string memory metadata
    ) public;

    // ========================================
    // COMPLEX TRANSITION SCENARIOS
    // ========================================

    /// @dev Tests complete campaign lifecycle transitions
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    /// @param attributionWindow Campaign attribution window
    function test_onUpdateStatus_completeCampaignLifecycle(
        address attributionProvider,
        address advertiser,
        address campaign,
        string memory metadata,
        uint48 attributionWindow
    ) public;

    /// @dev Tests attribution provider can bypass advertiser deadline wait
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in FINALIZING status
    /// @param metadata Status update metadata
    /// @param currentTime Time before attribution deadline
    function test_onUpdateStatus_providerBypassesDeadline(
        address attributionProvider,
        address advertiser,
        address campaign,
        string memory metadata,
        uint256 currentTime
    ) public;

    // ========================================
    // SECURITY STATE TRANSITION TESTS
    // ========================================

    /// @dev Tests attribution window bypass vulnerability prevention (ACTIVE → FINALIZED attack)
    /// @param advertiser Advertiser address attempting bypass
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_security_preventsAttributionWindowBypass(
        address advertiser,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Tests that legitimate state transitions still work after security fix
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    /// @param attributionWindow Campaign attribution window
    function test_onUpdateStatus_security_legitimateTransitionsStillWork(
        address advertiser,
        address campaign,
        string memory metadata,
        uint48 attributionWindow
    ) public;

    /// @dev Tests attribution provider privileges are preserved after security fix
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param metadata Status update metadata
    function test_onUpdateStatus_security_attributionProviderPrivilegesPreserved(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Tests that no party can pause active campaigns (security improvement)
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_security_noPausingAllowed(
        address attributionProvider,
        address advertiser,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Tests malicious pause attacks are prevented
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_security_maliciousPausePrevented(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Tests only attribution provider can activate campaigns
    /// @param attributionProvider Attribution provider address
    /// @param advertiser Advertiser address
    /// @param randomUser Random unauthorized user
    /// @param campaign Campaign address in INACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_security_onlyAttributionProviderCanActivate(
        address attributionProvider,
        address advertiser,
        address randomUser,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Tests attribution provider can bypass FINALIZING (ACTIVE → FINALIZED allowed)
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in ACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_security_attributionProviderCanBypassFinalizing(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Tests INACTIVE → FINALIZED is allowed for fund recovery
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address in INACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_security_inactiveToFinalizedAllowed(
        address advertiser,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Tests attribution provider cannot do fund recovery (INACTIVE → FINALIZED blocked)
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in INACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_security_attributionProviderCannotDoFundRecovery(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public;

    /// @dev Tests attribution provider cannot skip ACTIVE phase (INACTIVE → FINALIZING blocked)
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address in INACTIVE status
    /// @param metadata Status update metadata
    function test_onUpdateStatus_security_attributionProviderCannotSkipActivePhase(
        address attributionProvider,
        address campaign,
        string memory metadata
    ) public;
}
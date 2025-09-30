// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

contract AddAllowedPublisherRefCodeTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when caller is not the advertiser
    /// @param unauthorizedCaller Unauthorized caller address (not advertiser)
    /// @param campaign Campaign address
    /// @param publisherRefCode Publisher reference code to add
    function test_addAllowedPublisherRefCode_revert_unauthorizedCaller(
        address unauthorizedCaller,
        address campaign,
        string memory publisherRefCode
    ) public;

    /// @dev Reverts when publisher ref code is not registered in BuilderCodes registry
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param unregisteredRefCode Unregistered publisher reference code
    function test_addAllowedPublisherRefCode_revert_unregisteredRefCode(
        address advertiser,
        address campaign,
        string memory unregisteredRefCode
    ) public;

    /// @dev Reverts when campaign does not have an allowlist (hasAllowlist = false)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address without allowlist
    /// @param publisherRefCode Registered publisher reference code
    function test_addAllowedPublisherRefCode_revert_noAllowlist(
        address advertiser,
        address campaign,
        string memory publisherRefCode
    ) public;

    /// @dev Reverts when trying to add empty ref code
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    function test_addAllowedPublisherRefCode_revert_emptyRefCode(
        address advertiser,
        address campaign
    ) public;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully adds registered publisher ref code to campaign allowlist
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode Registered publisher reference code
    function test_addAllowedPublisherRefCode_success_addToAllowlist(
        address advertiser,
        address campaign,
        string memory publisherRefCode
    ) public;

    /// @dev Successfully adds multiple publisher ref codes to campaign allowlist
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode1 First registered publisher reference code
    /// @param publisherRefCode2 Second registered publisher reference code
    function test_addAllowedPublisherRefCode_success_addMultiple(
        address advertiser,
        address campaign,
        string memory publisherRefCode1,
        string memory publisherRefCode2
    ) public;

    /// @dev Successfully adds publisher ref code that was previously removed
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode Registered publisher reference code
    function test_addAllowedPublisherRefCode_success_addPreviouslyRemoved(
        address advertiser,
        address campaign,
        string memory publisherRefCode
    ) public;

    /// @dev Successfully handles adding same ref code multiple times (idempotent)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode Registered publisher reference code
    function test_addAllowedPublisherRefCode_success_idempotent(
        address advertiser,
        address campaign,
        string memory publisherRefCode
    ) public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles adding ref code with maximum length (32 characters)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param maxLengthRefCode 32-character publisher reference code
    function test_addAllowedPublisherRefCode_edge_maxLength(
        address advertiser,
        address campaign,
        string memory maxLengthRefCode
    ) public;

    /// @dev Handles adding ref code with single character
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param singleCharRefCode Single-character publisher reference code
    function test_addAllowedPublisherRefCode_edge_singleCharacter(
        address advertiser,
        address campaign,
        string memory singleCharRefCode
    ) public;

    /// @dev Handles adding ref code with special allowed characters
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param specialCharRefCode Publisher ref code with underscores and numbers
    function test_addAllowedPublisherRefCode_edge_specialCharacters(
        address advertiser,
        address campaign,
        string memory specialCharRefCode
    ) public;

    /// @dev Handles adding large number of ref codes to same campaign
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param manyRefCodes Large array of registered publisher reference codes
    function test_addAllowedPublisherRefCode_edge_manyRefCodes(
        address advertiser,
        address campaign,
        string[] memory manyRefCodes
    ) public;

    // ========================================
    // EVENT TESTING
    // ========================================

    /// @dev Emits PublisherAddedToAllowlist event with correct parameters
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode Registered publisher reference code
    function test_addAllowedPublisherRefCode_emitsPublisherAddedToAllowlist(
        address advertiser,
        address campaign,
        string memory publisherRefCode
    ) public;

    /// @dev Emits multiple events when adding multiple ref codes
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode1 First registered publisher reference code
    /// @param publisherRefCode2 Second registered publisher reference code
    function test_addAllowedPublisherRefCode_emitsMultipleEvents(
        address advertiser,
        address campaign,
        string memory publisherRefCode1,
        string memory publisherRefCode2
    ) public;

    /// @dev Does not emit event when adding already allowed ref code
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode Already allowed publisher reference code
    function test_addAllowedPublisherRefCode_noEventForDuplicate(
        address advertiser,
        address campaign,
        string memory publisherRefCode
    ) public;

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies allowlist mapping is correctly updated
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode Registered publisher reference code
    function test_addAllowedPublisherRefCode_updatesAllowlistMapping(
        address advertiser,
        address campaign,
        string memory publisherRefCode
    ) public;

    /// @dev Verifies allowlist state persists across multiple additions
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode1 First registered publisher reference code
    /// @param publisherRefCode2 Second registered publisher reference code
    function test_addAllowedPublisherRefCode_persistsAcrossAdditions(
        address advertiser,
        address campaign,
        string memory publisherRefCode1,
        string memory publisherRefCode2
    ) public;

    /// @dev Verifies BuilderCodes registry integration works correctly
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode Publisher reference code registered in BuilderCodes
    function test_addAllowedPublisherRefCode_integratesWithBuilderCodes(
        address advertiser,
        address campaign,
        string memory publisherRefCode
    ) public;

    /// @dev Verifies redundant calls are idempotent (no duplicate events)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param publisherRefCode Publisher reference code to add twice
    function test_addAllowedPublisherRefCode_redundantCall(
        address advertiser,
        address campaign,
        string memory publisherRefCode
    ) public;
}
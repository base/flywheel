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
    /// @param codeSeed Publisher reference code seed to add
    function test_addAllowedPublisherRefCode_revert_unauthorizedCaller(
        address unauthorizedCaller,
        address campaign,
        uint256 codeSeed
    ) public;

    /// @dev Reverts when publisher ref code is not registered in BuilderCodes registry
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address
    /// @param unregisteredCodeSeed Unregistered publisher reference code seed
    function test_addAllowedPublisherRefCode_revert_unregisteredRefCode(
        address advertiser,
        address campaign,
        uint256 unregisteredCodeSeed
    ) public;

    /// @dev Reverts when campaign does not have an allowlist (hasAllowlist = false)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address without allowlist
    /// @param codeSeed Registered publisher reference code seed
    function test_addAllowedPublisherRefCode_revert_noAllowlist(address advertiser, address campaign, uint256 codeSeed)
        public;

    /// @dev Reverts when trying to add empty ref code
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    function test_addAllowedPublisherRefCode_revert_emptyRefCode(address advertiser, address campaign) public;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully adds registered publisher ref code to campaign allowlist
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param codeSeed Registered publisher reference code seed
    function test_addAllowedPublisherRefCode_success_addToAllowlist(
        address advertiser,
        address campaign,
        uint256 codeSeed
    ) public;

    /// @dev Successfully adds multiple publisher ref codes to campaign allowlist
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param codeSeed1 First registered publisher reference code seed
    /// @param codeSeed2 Second registered publisher reference code seed
    function test_addAllowedPublisherRefCode_success_addMultiple(
        address advertiser,
        address campaign,
        uint256 codeSeed1,
        uint256 codeSeed2
    ) public;

    /// @dev Successfully handles adding same ref code multiple times (idempotent)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param codeSeed Registered publisher reference code seed
    function test_addAllowedPublisherRefCode_success_idempotent(address advertiser, address campaign, uint256 codeSeed)
        public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles adding ref code with maximum length (32 characters)
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param maxLengthRefCodeSeed 32-character publisher reference code seed
    function test_addAllowedPublisherRefCode_edge_maxLength(
        address advertiser,
        address campaign,
        uint256 maxLengthRefCodeSeed
    ) public;

    /// @dev Handles adding ref code with single character
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param singleCharRefCodeSeed Single-character publisher reference code seed
    function test_addAllowedPublisherRefCode_edge_singleCharacter(
        address advertiser,
        address campaign,
        uint256 singleCharRefCodeSeed
    ) public;

    /// @dev Handles adding ref code with special allowed characters
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param specialCharRefCodeSeed Publisher ref code with underscores and numbers seed
    function test_addAllowedPublisherRefCode_edge_specialCharacters(
        address advertiser,
        address campaign,
        uint256 specialCharRefCodeSeed
    ) public;

    // ========================================
    // EVENT TESTING
    // ========================================

    /// @dev Emits PublisherAddedToAllowlist event with correct parameters
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param codeSeed Registered publisher reference code seed
    function test_addAllowedPublisherRefCode_emitsPublisherAddedToAllowlist(
        address advertiser,
        address campaign,
        uint256 codeSeed
    ) public;

    /// @dev Emits multiple events when adding multiple ref codes
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param codeSeed1 First registered publisher reference code seed
    /// @param codeSeed2 Second registered publisher reference code seed
    function test_addAllowedPublisherRefCode_emitsMultipleEvents(
        address advertiser,
        address campaign,
        uint256 codeSeed1,
        uint256 codeSeed2
    ) public;

    /// @dev Does not emit event when adding already allowed ref code
    /// @param advertiser Advertiser address
    /// @param campaign Campaign address with allowlist
    /// @param codeSeed Already allowed publisher reference code seed
    function test_addAllowedPublisherRefCode_noEventForDuplicate(address advertiser, address campaign, uint256 codeSeed)
        public;
}

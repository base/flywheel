// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.tokenURI
contract TokenURITest is BuilderCodesTest {
    /// @notice Test that tokenURI reverts when token ID does not exist
    ///
    /// @param tokenId The token ID
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_tokenURI_revert_tokenDoesNotExist(
        uint256 tokenId,
        address initialOwner,
        address initialPayoutAddress
    ) public {}

    /// @notice Test that tokenURI returns correct URI for registered token when base URI is set
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_tokenURI_success_returnsCorrectURIWithBaseURI(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {}

    /// @notice Test that tokenURI returns empty string when base URI is not set
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_tokenURI_success_returnsEmptyStringWithoutBaseURI(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {}

    /// @notice Test that tokenURI returns same result as codeURI for equivalent inputs
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_tokenURI_success_matchesCodeURI(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {}

    /// @notice Test that tokenURI reflects updated base URI
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    /// @param newBaseURI The new base URI
    function test_tokenURI_success_reflectsUpdatedBaseURI(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress,
        string memory newBaseURI
    ) public {}
}
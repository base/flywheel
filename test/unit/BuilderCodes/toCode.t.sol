// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.toCode
contract ToCodeTest is BuilderCodesTest {
    /// @notice Test that toCode reverts when token ID represents empty code
    ///
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toCode_revert_emptyCode(
        address initialOwner,
        address initialPayoutAddress
    ) public {}

    /// @notice Test that toCode reverts when token ID represents code with invalid characters
    ///
    /// @param tokenId The token ID representing invalid code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toCode_revert_codeContainsInvalidCharacters(
        uint256 tokenId,
        address initialOwner,
        address initialPayoutAddress
    ) public {}

    /// @notice Test that toCode reverts when token ID does not normalize properly
    ///
    /// @param tokenId The token ID with invalid normalization
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toCode_revert_invalidNormalization(
        uint256 tokenId,
        address initialOwner,
        address initialPayoutAddress
    ) public {}

    /// @notice Test that toCode returns correct code for valid token ID
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toCode_success_returnsCorrectCode(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {}
}
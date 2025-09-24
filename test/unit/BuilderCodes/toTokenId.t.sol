// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.toTokenId
contract ToTokenIdTest is BuilderCodesTest {
    /// @notice Test that toTokenId reverts when code is empty
    ///
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toTokenId_revert_emptyCode(
        address initialOwner,
        address initialPayoutAddress
    ) public {}

    /// @notice Test that toTokenId reverts when code is over 32 characters
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toTokenId_revert_codeOver32Characters(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {}

    /// @notice Test that toTokenId reverts when code contains invalid characters
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toTokenId_revert_codeContainsInvalidCharacters(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {}

    /// @notice Test that toTokenId returns correct token ID for valid code
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toTokenId_success_returnsCorrectTokenId(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {}
}
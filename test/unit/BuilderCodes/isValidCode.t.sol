// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.isValidCode
contract IsValidCodeTest is BuilderCodesTest {
    /// @notice Test that isValidCode returns false for empty code
    ///
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_isValidCode_false_emptyCode(
        address initialOwner,
        address initialPayoutAddress
    ) public {
        assertFalse(builderCodes.isValidCode(""));
    }

    /// @notice Test that isValidCode returns false for code over 32 characters
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_isValidCode_false_codeOver32Characters(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {
        string memory longCode = _generateLongCode(codeSeed);
        assertFalse(builderCodes.isValidCode(longCode));
    }

    /// @notice Test that isValidCode returns false for code with invalid characters
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_isValidCode_false_invalidCharacters(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {
        string memory invalidCode = _generateInvalidCode(codeSeed);
        assertFalse(builderCodes.isValidCode(invalidCode));
    }

    /// @notice Test that isValidCode returns true for valid code
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_isValidCode_true_validCode(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {
        string memory validCode = _generateValidCode(codeSeed);
        assertTrue(builderCodes.isValidCode(validCode));
    }

    /// @notice Test that isValidCode returns true for single character valid code
    ///
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_isValidCode_true_singleCharacter(
        address initialOwner,
        address initialPayoutAddress
    ) public {
        assertTrue(builderCodes.isValidCode("a"));
        assertTrue(builderCodes.isValidCode("0"));
        assertTrue(builderCodes.isValidCode("_"));
    }

    /// @notice Test that isValidCode returns true for 32 character valid code
    ///
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_isValidCode_true_32Characters(
        address initialOwner,
        address initialPayoutAddress
    ) public {
        string memory code32 = "abcdefghijklmnopqrstuvwxyz012345";
        assertTrue(builderCodes.isValidCode(code32));
    }

    /// @notice Test that isValidCode returns true for code with underscores
    ///
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_isValidCode_true_underscores(
        address initialOwner,
        address initialPayoutAddress
    ) public {
        assertTrue(builderCodes.isValidCode("test_code"));
        assertTrue(builderCodes.isValidCode("_underscore_"));
    }

    /// @notice Test that isValidCode returns true for numeric only code
    ///
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_isValidCode_true_numericOnly(
        address initialOwner,
        address initialPayoutAddress
    ) public {
        assertTrue(builderCodes.isValidCode("1234567890"));
    }

    /// @notice Test that isValidCode returns true for alphabetic only code
    ///
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_isValidCode_true_alphabeticOnly(
        address initialOwner,
        address initialPayoutAddress
    ) public {
        assertTrue(builderCodes.isValidCode("abcdefghijklmnopqrstuvwxyz"));
    }
}
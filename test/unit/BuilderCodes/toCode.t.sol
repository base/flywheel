// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {LibString} from "solady/utils/LibString.sol";

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";
import {BuilderCodes} from "../../../src/BuilderCodes.sol";

/// @notice Unit tests for BuilderCodes.toCode
contract ToCodeTest is BuilderCodesTest {
    /// @notice Test that toCode reverts when token ID represents empty code
    ///
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toCode_revert_emptyCode(address initialOwner, address initialPayoutAddress) public {
        uint256 emptyTokenId = 0;
        vm.expectRevert(abi.encodeWithSelector(BuilderCodes.InvalidCode.selector, ""));
        builderCodes.toCode(emptyTokenId);
    }

    /// @notice Test that toCode reverts when token ID represents code with invalid characters
    ///
    /// @param tokenId The token ID representing invalid code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toCode_revert_codeContainsInvalidCharacters(
        uint256 tokenId,
        address initialOwner,
        address initialPayoutAddress
    ) public {
        // Use a token ID that would convert to invalid characters
        string memory invalidCode = _generateInvalidCode(tokenId);
        uint256 invalidTokenId = uint256(bytes32(bytes(invalidCode)));
        vm.expectRevert(abi.encodeWithSelector(BuilderCodes.InvalidCode.selector, invalidCode));
        builderCodes.toCode(invalidTokenId);
    }

    /// @notice Test that toCode reverts when token ID does not normalize properly
    ///
    /// @param tokenId The token ID with invalid normalization
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toCode_revert_invalidNormalization(
        uint256 tokenId,
        address initialOwner,
        address initialPayoutAddress
    ) public {
        uint256 invalidTokenId = _generateInvalidTokenId(tokenId);
        vm.expectRevert(
            abi.encodeWithSelector(
                BuilderCodes.InvalidCode.selector, LibString.fromSmallString(bytes32(invalidTokenId))
            )
        );
        builderCodes.toCode(invalidTokenId);
    }

    /// @notice Test that toCode returns correct code for valid token ID
    ///
    /// @param codeSeed The seed for generating the code
    /// @param initialOwner The initial owner address
    /// @param initialPayoutAddress The initial payout address
    function test_toCode_success_returnsCorrectCode(
        uint256 codeSeed,
        address initialOwner,
        address initialPayoutAddress
    ) public {
        string memory validCode = _generateValidCode(codeSeed);
        uint256 tokenId = builderCodes.toTokenId(validCode);

        string memory retrievedCode = builderCodes.toCode(tokenId);
        assertEq(retrievedCode, validCode);
    }
}

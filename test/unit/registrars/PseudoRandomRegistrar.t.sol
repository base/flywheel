// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodes} from "../../../src/BuilderCodes.sol";
import {PseudoRandomRegistrar} from "../../../src/registrars/PseudoRandomRegistrar.sol";

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for PseudoRandomRegistrar
contract PseudoRandomRegistrarTest is BuilderCodesTest {
    PseudoRandomRegistrar pseudoRandomRegistrar;

    function setUp() public override {
        super.setUp();

        pseudoRandomRegistrar = new PseudoRandomRegistrar(address(builderCodes));

        // Grant REGISTER_ROLE to the PseudoRandomRegistrar so it can register codes
        vm.prank(owner);
        builderCodes.grantRole(keccak256("REGISTER_ROLE"), address(pseudoRandomRegistrar));
    }

    /// @notice Test that register reverts when the payout address is zero address
    function test_register_revert_zeroPayoutAddress() public {
        vm.expectRevert(abi.encodeWithSelector(BuilderCodes.ZeroAddress.selector));
        pseudoRandomRegistrar.register(address(0));
    }

    /// @notice Test that register successfully sets the sender as the code owner
    ///
    /// @param sender The sender address
    function test_register_success_setSenderCodeOwner(address sender) public {
        sender = _boundNonZeroAddress(sender);

        vm.prank(sender);
        string memory code = pseudoRandomRegistrar.register(sender);

        uint256 tokenId = builderCodes.toTokenId(code);
        assertEq(builderCodes.ownerOf(tokenId), sender);
    }

    /// @notice Test that register successfully sets the payout address
    ///
    /// @param payoutAddress The payout address
    function test_register_success_setPayoutAddress(address payoutAddress) public {
        payoutAddress = _boundNonZeroAddress(payoutAddress);

        string memory code = pseudoRandomRegistrar.register(payoutAddress);

        assertEq(builderCodes.payoutAddress(code), payoutAddress);
    }

    /// @notice Test that register successfully prefixes the code
    ///
    /// @param payoutAddress The payout address
    function test_register_success_codePrefixed(address payoutAddress) public {
        payoutAddress = _boundNonZeroAddress(payoutAddress);

        string memory code = pseudoRandomRegistrar.register(payoutAddress);

        // Check that code starts with the PREFIX "bc_"
        bytes memory codeBytes = bytes(code);
        bytes memory prefix = bytes(pseudoRandomRegistrar.PREFIX());

        assertTrue(codeBytes.length >= prefix.length);
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(codeBytes[i], prefix[i]);
        }
    }

    /// @notice Test that register successfully sets the code suffix to alphanumeric
    ///
    /// @param payoutAddress The payout address
    function test_register_success_codeSuffixAlphanumeric(address payoutAddress) public {
        payoutAddress = _boundNonZeroAddress(payoutAddress);

        string memory code = pseudoRandomRegistrar.register(payoutAddress);

        // Extract suffix by removing prefix
        bytes memory codeBytes = bytes(code);
        bytes memory prefix = bytes(pseudoRandomRegistrar.PREFIX());
        bytes memory allowedChars = bytes(pseudoRandomRegistrar.ALPHANUMERIC());

        // Check each character in the suffix is alphanumeric
        for (uint256 i = prefix.length; i < codeBytes.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < allowedChars.length; j++) {
                if (codeBytes[i] == allowedChars[j]) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "Suffix contains non-alphanumeric character");
        }
    }

    /// @notice Test that register successfully sets the code suffix to fixed length
    ///
    /// @param payoutAddress The payout address
    function test_register_success_codeSuffixFixedLength(address payoutAddress) public {
        payoutAddress = _boundNonZeroAddress(payoutAddress);

        string memory code = pseudoRandomRegistrar.register(payoutAddress);

        // Check that total code length is PREFIX_LENGTH + SUFFIX_LENGTH
        bytes memory prefix = bytes(pseudoRandomRegistrar.PREFIX());
        uint256 expectedLength = prefix.length + pseudoRandomRegistrar.SUFFIX_LENGTH();

        assertEq(bytes(code).length, expectedLength);
    }

    /// @notice Test that register successfully changes the nonce
    ///
    /// @param payoutAddress The payout address
    function test_register_success_nonceChanged(address payoutAddress) public {
        payoutAddress = _boundNonZeroAddress(payoutAddress);

        uint256 initialNonce = pseudoRandomRegistrar.nonce();

        pseudoRandomRegistrar.register(payoutAddress);

        uint256 finalNonce = pseudoRandomRegistrar.nonce();
        assertTrue(finalNonce > initialNonce, "Nonce should increase after registration");
    }

    /// @notice Test that repeated registrations produce different codes
    ///
    /// @param payoutAddress The payout address
    function test_register_success_repeatedRegistrationsDiffer(address payoutAddress) public {
        payoutAddress = _boundNonZeroAddress(payoutAddress);

        string memory code1 = pseudoRandomRegistrar.register(payoutAddress);
        string memory code2 = pseudoRandomRegistrar.register(payoutAddress);

        // Codes should be different
        assertFalse(
            keccak256(bytes(code1)) == keccak256(bytes(code2)), "Repeated registrations should produce different codes"
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

import {PseudoRandomRegistrar} from "../../../src/registrars/PseudoRandomRegistrar.sol";

/// @notice Unit tests for PseudoRandomRegistrar
contract PseudoRandomRegistrarTest is BuilderCodesTest {
    PseudoRandomRegistrar pseudoRandomRegistrar;

    function setUp() public override {
        super.setUp();

        pseudoRandomRegistrar = new PseudoRandomRegistrar(address(builderCodes));
    }

    /// @notice Test that register reverts when the payout address is zero address
    function test_register_revert_zeroPayoutAddress() public {}

    /// @notice Test that register successfully sets the sender as the code owner
    ///
    /// @param payoutAddress The payout address
    function test_register_success_setSenderCodeOwner(address payoutAddress) public {}

    /// @notice Test that register successfully sets the payout address
    ///
    /// @param payoutAddress The payout address
    function test_register_success_setPayoutAddress(address payoutAddress) public {}

    /// @notice Test that register successfully prefixes the code
    ///
    /// @param payoutAddress The payout address
    function test_register_success_codePrefixed(address payoutAddress) public {}

    /// @notice Test that register successfully sets the code suffix to alphanumeric
    ///
    /// @param payoutAddress The payout address
    function test_register_success_codeSuffixAlphanumeric(address payoutAddress) public {}

    /// @notice Test that register successfully sets the code suffix to fixed length
    ///
    /// @param payoutAddress The payout address
    function test_register_success_codeSuffixFixedLength(address payoutAddress) public {}

    /// @notice Test that register successfully changes the nonce
    ///
    /// @param payoutAddress The payout address
    function test_register_success_nonceChanged(address payoutAddress) public {}

    /// @notice Test that register successfully sets the code suffix to fixed length
    ///
    /// @param payoutAddress The payout address
    function test_register_success_repeatedRegistrationsDiffer(address payoutAddress) public {}
}

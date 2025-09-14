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

    /**
     * register reverts
     */
    function test_register_revert_zeroPayoutAddress() public {}

    /**
     * register success conditions
     */
    function test_register_success_setSenderCodeOwner(address payoutAddress) public {}

    function test_register_success_setPayoutAddress(address payoutAddress) public {}

    function test_register_success_codePrefixed(address payoutAddress) public {}

    function test_register_success_codeSuffixAlphanumeric(address payoutAddress) public {}

    function test_register_success_codeSuffixFixedLength(address payoutAddress) public {}

    function test_register_success_nonceChanged(address payoutAddress) public {}

    function test_register_success_repeatedRegistrationsDiffer(address payoutAddress) public {}
}

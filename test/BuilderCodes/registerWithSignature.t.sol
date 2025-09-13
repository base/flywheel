// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesBase} from "./BuilderCodesBase.sol";

/// @notice Tests for BuilderCodes.registerWithSignature
contract RegisterWithSignatureTest is BuilderCodesBase {
    /**
     * registerWithSignature reverts
     */
    function test_registerWithSignature_revert_afterRegistrationDeadline(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_revert_registrarInvalidRole(
        address initialOwner,
        address payoutAddress,
        uint48 deadline,
        address registrar
    ) public {}

    function test_registerWithSignature_revert_invalidSignature(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    /**
     * _register reverts
     */
    function test_registerWithSignature_revert_emptyCode(address initialOwner, address payoutAddress, uint48 deadline)
        public
    {}

    function test_registerWithSignature_revert_codeOver32Characters(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_revert_codeContainsInvalidCharacters(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_revert_zeroInitialOwner(address payoutAddress, uint48 deadline) public {}

    function test_registerWithSignature_revert_alreadyRegistered(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_revert_zeroPayoutAddress(address initialOwner, uint48 deadline) public {}

    /**
     * registerWithSignature success variants
     */
    function test_registerWithSignature_success_contractSignatureSupport(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    /**
     * registerWithSignature EIP-712 compliance
     */
    function test_registerWithSignature_success_contractSignatureSupport(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    /**
     * _register success conditions
     */
    function test_registerWithSignature_success_mintsToken(address initialOwner, address payoutAddress, uint48 deadline)
        public
    {}

    function test_registerWithSignature_success_setsPayoutAddress(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    /**
     * _register event emission
     */
    function test_registerWithSignature_success_emitsERC721Transfer(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_success_emitsCodeRegistered(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_success_emitsPayoutAddressUpdated(
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}
}

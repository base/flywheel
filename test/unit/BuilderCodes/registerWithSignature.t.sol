// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.registerWithSignature
contract RegisterWithSignatureTest is BuilderCodesTest {
    /**
     * registerWithSignature reverts
     */
    function test_registerWithSignature_revert_afterRegistrationDeadline(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_revert_registrarInvalidRole(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline,
        address registrar
    ) public {}

    function test_registerWithSignature_revert_invalidSignature(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    /**
     * _register reverts
     */
    function test_registerWithSignature_revert_emptyCode(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_revert_codeOver32Characters(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_revert_codeContainsInvalidCharacters(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_revert_zeroInitialOwner(
        uint256 codeSeed,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_revert_zeroPayoutAddress(
        uint256 codeSeed,
        address initialOwner,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_revert_alreadyRegistered(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    /**
     * registerWithSignature success conditions
     */
    function test_registerWithSignature_success_contractSignatureSupport(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_success_eip712Compliance(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    /**
     * _register success conditions
     */
    function test_registerWithSignature_success_mintsToken(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_success_setsPayoutAddress(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    /**
     * _register event emission
     */
    function test_registerWithSignature_success_emitsERC721Transfer(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_success_emitsCodeRegistered(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}

    function test_registerWithSignature_success_emitsPayoutAddressUpdated(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress,
        uint48 deadline
    ) public {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesBase} from "./BuilderCodesBase.sol";

/// @notice Tests for BuilderCodes.register
contract RegisterTest is BuilderCodesBase {
    /**
     * register reverts
     */
    function test_register_revert_senderInvalidRole(address sender, address initialOwner, address payoutAddress)
        public
    {}

    /**
     * _register reverts
     */
    function test_register_revert_emptyCode(address initialOwner, address payoutAddress) public {}

    function test_register_revert_codeOver32Characters(address initialOwner, address payoutAddress) public {}

    function test_register_revert_codeContainsInvalidCharacters(address initialOwner, address payoutAddress) public {}

    function test_register_revert_zeroInitialOwner(address payoutAddress) public {}

    function test_register_revert_alreadyRegistered(address initialOwner, address payoutAddress) public {}

    function test_register_revert_zeroPayoutAddress(address initialOwner) public {}

    /**
     * _register success conditions
     */
    function test_register_success_mintsToken(address initialOwner, address payoutAddress) public {}

    function test_register_success_setsPayoutAddress(address initialOwner, address payoutAddress) public {}

    /**
     * _register success events
     */
    function test_register_success_emitsERC721Transfer(address initialOwner, address payoutAddress) public {}

    function test_register_success_emitsCodeRegistered(address initialOwner, address payoutAddress) public {}

    function test_register_success_emitsPayoutAddressUpdated(address initialOwner, address payoutAddress) public {}
}

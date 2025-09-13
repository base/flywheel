// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesCommon} from "../../common/BuilderCodesCommon.sol";

/// @notice Unit tests for BuilderCodes.register
contract RegisterTest is BuilderCodesCommon {
    /**
     * register reverts
     */
    function test_register_revert_senderInvalidRole(
        address sender,
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress
    ) public {}

    /**
     * _register reverts
     */
    function test_register_revert_emptyCode(address initialOwner, address payoutAddress) public {}

    function test_register_revert_codeOver32Characters(uint256 codeSeed, address initialOwner, address payoutAddress)
        public
    {}

    function test_register_revert_codeContainsInvalidCharacters(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress
    ) public {}

    function test_register_revert_zeroInitialOwner(uint256 codeSeed, address payoutAddress) public {}

    function test_register_revert_zeroPayoutAddress(uint256 codeSeed, address initialOwner) public {}

    function test_register_revert_alreadyRegistered(uint256 codeSeed, address initialOwner, address payoutAddress)
        public
    {}

    /**
     * _register success conditions
     */
    function test_register_success_mintsToken(uint256 codeSeed, address initialOwner, address payoutAddress) public {}

    function test_register_success_setsPayoutAddress(uint256 codeSeed, address initialOwner, address payoutAddress)
        public
    {}

    /**
     * _register success events
     */
    function test_register_success_emitsERC721Transfer(uint256 codeSeed, address initialOwner, address payoutAddress)
        public
    {}

    function test_register_success_emitsCodeRegistered(uint256 codeSeed, address initialOwner, address payoutAddress)
        public
    {}

    function test_register_success_emitsPayoutAddressUpdated(
        uint256 codeSeed,
        address initialOwner,
        address payoutAddress
    ) public {}
}

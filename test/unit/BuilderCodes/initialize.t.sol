// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.initialize
contract InitializeTest is BuilderCodesTest {
    /**
     * initialize reverts
     */
    function test_initialize_revert_zeroInitialOwnerAddress() public {}

    /**
     * initialize success conditions
     */
    function test_initialize_success_setName() public {}

    function test_initialize_success_setSymbol() public {}

    function test_initialize_success_setInitialOwner() public {}

    function test_initialize_success_setURIPrefix() public {}

    function test_initialize_success_setInitialRegistrar() public {}
}

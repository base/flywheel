// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.initialize
contract InitializeTest is BuilderCodesTest {
    /// @notice Test that initialize reverts when a zero address is provided as the initial owner
    ///
    /// @param initialRegistrar The initial registrar address
    /// @param uriPrefix The URI prefix
    function test_initialize_revert_zeroInitialOwnerAddress(address initialRegistrar, string memory uriPrefix) public {}

    /// @notice Test that initialize sets the name to "Builder Codes"
    ///
    /// @param initialOwner The initial owner address
    /// @param initialRegistrar The initial registrar address
    /// @param uriPrefix The URI prefix
    function test_initialize_success_setName(address initialOwner, address initialRegistrar, string memory uriPrefix)
        public
    {}

    /// @notice Test that initialize sets the symbol to "BUILDERCODE"
    ///
    /// @param initialOwner The initial owner address
    /// @param initialRegistrar The initial registrar address
    /// @param uriPrefix The URI prefix
    function test_initialize_success_setSymbol(address initialOwner, address initialRegistrar, string memory uriPrefix)
        public
    {}

    /// @notice Test that initialize sets the initial owner
    ///
    /// @param initialOwner The initial owner address
    /// @param initialRegistrar The initial registrar address
    /// @param uriPrefix The URI prefix
    function test_initialize_success_setInitialOwner(
        address initialOwner,
        address initialRegistrar,
        string memory uriPrefix
    ) public {}

    /// @notice Test that initialize sets the initial registrar when a non-zero address is provided
    ///
    /// @param initialOwner The initial owner address
    /// @param initialRegistrar The initial registrar address
    /// @param uriPrefix The URI prefix
    function test_initialize_success_setNonZeroInitialRegistrar(
        address initialOwner,
        address initialRegistrar,
        string memory uriPrefix
    ) public {}

    /// @notice Test that initialize ignores a zero initial registrar
    ///
    /// @param initialOwner The initial owner address
    /// @param uriPrefix The URI prefix
    function test_initialize_success_ignoresZeroInitialRegistrar(address initialOwner, string memory uriPrefix)
        public
    {}

    /// @notice Test that initialize sets the URI prefix
    ///
    /// @param initialOwner The initial owner address
    /// @param initialRegistrar The initial registrar address
    /// @param uriPrefix The URI prefix
    function test_initialize_success_setURIPrefix(
        address initialOwner,
        address initialRegistrar,
        string memory uriPrefix
    ) public {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.updateBaseURI
contract UpdateBaseURITest is BuilderCodesTest {
    /// @notice Test that updateBaseURI reverts when sender doesn't have required role
    ///
    /// @param uriPrefix The URI prefix to test
    function test_updateBaseURI_revert_senderInvalidRole(string memory uriPrefix) public {}

    /// @notice Test that updateBaseURI successfully updates the token URI
    ///
    /// @param uriPrefix The URI prefix to test
    function test_updateBaseURI_success_tokenURIUpdated(string memory uriPrefix) public {}

    /// @notice Test that updateBaseURI successfully updates the code URI
    ///
    /// @param uriPrefix The URI prefix to test
    function test_updateBaseURI_success_codeURIUpdated(string memory uriPrefix) public {}

    /// @notice Test that updateBaseURI successfully updates the contract URI
    ///
    /// @param uriPrefix The URI prefix to test
    function test_updateBaseURI_success_contractURIUpdated(string memory uriPrefix) public {}

    /// @notice Test that updateBaseURI emits the ERC4906 BatchMetadataUpdate event
    ///
    /// @param uriPrefix The URI prefix to test
    function test_updateBaseURI_success_emitsERC4906BatchMetadataUpdate(string memory uriPrefix) public {}

    /// @notice Test that updateBaseURI emits the ERC7572 ContractURIUpdated event
    ///
    /// @param uriPrefix The URI prefix to test
    function test_updateBaseURI_success_emitsERC7572ContractURIUpdated(string memory uriPrefix) public {}
}

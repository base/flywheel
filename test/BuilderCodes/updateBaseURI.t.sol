// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesBase} from "./BuilderCodesBase.sol";

/// @notice Tests for BuilderCodes.updateBaseURI
contract UpdateBaseURITest is BuilderCodesBase {
    /**
     * updateBaseURI reverts
     */
    function test_updateBaseURI_revert_senderInvalidRole(string memory uriPrefix) public {}

    /**
     * updateBaseURI success conditions
     */
    function test_updateBaseURI_success_tokenURIUpdated(string memory uriPrefix) public {}

    function test_updateBaseURI_success_codeURIUpdated(string memory uriPrefix) public {}

    function test_updateBaseURI_success_contractURIUpdated(string memory uriPrefix) public {}

    /**
     * updateBaseURI event emission
     */
    function test_updateBaseURI_success_emitsERC4906BatchMetadataUpdate(string memory uriPrefix) public {}

    function test_updateBaseURI_success_emitsERC7572ContractURIUpdated(string memory uriPrefix) public {}
}

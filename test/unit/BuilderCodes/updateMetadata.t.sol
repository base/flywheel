// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesBase} from "./BuilderCodesBase.sol";

/// @notice Tests for BuilderCodes.updateMetadata
contract UpdateMetadataTest is BuilderCodesBase {
    /**
     * updateMetadata reverts
     */
    function test_updateMetadata_revert_senderInvalidRole() public {}

    function test_updateMetadata_revert_codeNotRegistered() public {}

    /**
     * updateMetadata success conditions
     */
    function test_updateMetadata_success_tokenURIUnchanged() public {}

    function test_updateMetadata_success_codeURIUnchanged() public {}

    /**
     * updateMetadata event emission
     */
    function test_updateMetadata_success_emitsERC4906MetadataUpdate() public {}
}

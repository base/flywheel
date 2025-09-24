// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.updateMetadata
contract UpdateMetadataTest is BuilderCodesTest {
    /// @notice Test that updateMetadata reverts when sender doesn't have required role
    function test_updateMetadata_revert_senderInvalidRole() public {}

    /// @notice Test that updateMetadata reverts when the code is not registered
    function test_updateMetadata_revert_codeNotRegistered() public {}

    /// @notice Test that updateMetadata succeeds and token URI remains unchanged
    function test_updateMetadata_success_tokenURIUnchanged() public {}

    /// @notice Test that updateMetadata succeeds and code URI remains unchanged
    function test_updateMetadata_success_codeURIUnchanged() public {}

    /// @notice Test that updateMetadata emits the ERC4906 MetadataUpdate event
    function test_updateMetadata_success_emitsERC4906MetadataUpdate() public {}
}

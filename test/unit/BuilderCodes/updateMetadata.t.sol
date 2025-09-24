// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";
import {BuilderCodes} from "../../../src/BuilderCodes.sol";

/// @notice Unit tests for BuilderCodes.updateMetadata
contract UpdateMetadataTest is BuilderCodesTest {
    /// @notice ERC4906 MetadataUpdate event
    event MetadataUpdate(uint256 _tokenId);
    /// @notice Test that updateMetadata reverts when sender doesn't have required role
    function test_updateMetadata_revert_senderInvalidRole() public {
        string memory validCode = _generateValidCode(123);
        address unauthorizedUser = makeAddr("unauthorized");
        
        // Register a code first
        vm.prank(registrar);
        builderCodes.register(validCode, owner, owner);
        
        uint256 tokenId = builderCodes.toTokenId(validCode);
        
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        builderCodes.updateMetadata(tokenId);
    }

    /// @notice Test that updateMetadata reverts when the code is not registered
    function test_updateMetadata_revert_codeNotRegistered() public {
        string memory validCode = _generateValidCode(456);
        uint256 tokenId = builderCodes.toTokenId(validCode);
        
        vm.prank(owner);
        vm.expectRevert("ERC721: invalid token ID");
        builderCodes.updateMetadata(tokenId);
    }

    /// @notice Test that updateMetadata allows owner to update
    function test_updateMetadata_success_ownerCanUpdate() public {
        string memory validCode = _generateValidCode(789);
        
        // Register a code first
        vm.prank(registrar);
        builderCodes.register(validCode, owner, owner);
        
        uint256 tokenId = builderCodes.toTokenId(validCode);
        
        // Owner should be able to update metadata
        vm.prank(owner);
        builderCodes.updateMetadata(tokenId);
    }

    /// @notice Test that updateMetadata succeeds and token URI remains unchanged
    function test_updateMetadata_success_tokenURIUnchanged() public {
        string memory validCode = _generateValidCode(101112);
        
        // Register a code first
        vm.prank(registrar);
        builderCodes.register(validCode, owner, owner);
        
        uint256 tokenId = builderCodes.toTokenId(validCode);
        string memory uriBefore = builderCodes.tokenURI(tokenId);
        
        vm.prank(owner);
        builderCodes.updateMetadata(tokenId);
        
        string memory uriAfter = builderCodes.tokenURI(tokenId);
        assertEq(uriBefore, uriAfter);
    }

    /// @notice Test that updateMetadata succeeds and code URI remains unchanged
    function test_updateMetadata_success_codeURIUnchanged() public {
        string memory validCode = _generateValidCode(131415);
        
        // Register a code first
        vm.prank(registrar);
        builderCodes.register(validCode, owner, owner);
        
        string memory uriBefore = builderCodes.codeURI(validCode);
        uint256 tokenId = builderCodes.toTokenId(validCode);
        
        vm.prank(owner);
        builderCodes.updateMetadata(tokenId);
        
        string memory uriAfter = builderCodes.codeURI(validCode);
        assertEq(uriBefore, uriAfter);
    }

    /// @notice Test that updateMetadata emits the ERC4906 MetadataUpdate event
    function test_updateMetadata_success_emitsERC4906MetadataUpdate() public {
        string memory validCode = _generateValidCode(161718);
        
        // Register a code first
        vm.prank(registrar);
        builderCodes.register(validCode, owner, owner);
        
        uint256 tokenId = builderCodes.toTokenId(validCode);
        
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(tokenId);
        
        vm.prank(owner);
        builderCodes.updateMetadata(tokenId);
    }
}

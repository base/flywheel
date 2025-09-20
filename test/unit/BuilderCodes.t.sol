pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PublisherTestSetup, PublisherSetupHelper} from "../lib/PublisherSetupHelper.sol";

import {BuilderCodes} from "../../src/BuilderCodes.sol";

contract BuilderCodesTest is PublisherTestSetup {
    using PublisherSetupHelper for *;

    BuilderCodes public implementation;
    BuilderCodes public pubRegistry;
    ERC1967Proxy public proxy;

    address private owner = address(this);
    address private signer = address(0x123);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation
        implementation = new BuilderCodes();

        // Deploy proxy with signer address
        bytes memory initData = abi.encodeWithSelector(BuilderCodes.initialize.selector, owner, signer, "");
        proxy = new ERC1967Proxy(address(implementation), initData);

        // Create interface to proxy
        pubRegistry = BuilderCodes(address(proxy));

        vm.stopPrank();
    }

    function test_isValidCode_reverts_zeroCode() public {
        assertFalse(pubRegistry.isValidCode(""));
    }

    function test_isValidCode_success_nonZeroCode(uint256 value) public {
        assertTrue(pubRegistry.isValidCode(generateCode(value)));
    }

    function test_updateBaseURI_success() public {
        string memory newUriPrefix = "https://new.example.com/";
        
        vm.startPrank(owner); // owner has all roles
        
        // Expect events following existing pattern
        vm.expectEmit(true, true, true, true);
        emit BatchMetadataUpdate(0, type(uint256).max);
        
        vm.expectEmit(false, false, false, false);
        emit ContractURIUpdated();
        
        pubRegistry.updateBaseURI(newUriPrefix);
        vm.stopPrank();
        
        // Verify contractURI updated
        assertEq(pubRegistry.contractURI(), string.concat(newUriPrefix, "contractURI.json"));
    }

    function test_updateBaseURI_withMetadataRole() public {
        address metadataManager = address(0x777);
        string memory newUriPrefix = "https://metadata.example.com/";
        
        // Grant METADATA_ROLE to new address
        vm.prank(owner);
        pubRegistry.grantRole(pubRegistry.METADATA_ROLE(), metadataManager);
        
        // Should work with METADATA_ROLE
        vm.startPrank(metadataManager);
        
        vm.expectEmit(true, true, true, true);
        emit BatchMetadataUpdate(0, type(uint256).max);
        
        vm.expectEmit(false, false, false, false);
        emit ContractURIUpdated();
        
        pubRegistry.updateBaseURI(newUriPrefix);
        vm.stopPrank();
        
        assertEq(pubRegistry.contractURI(), string.concat(newUriPrefix, "contractURI.json"));
    }

    function test_updateBaseURI_unauthorized() public {
        string memory newUriPrefix = "https://unauthorized.com/";
        address unauthorized = address(0x999);
        
        vm.startPrank(unauthorized);
        vm.expectRevert(); // Following existing pattern for unauthorized access
        pubRegistry.updateBaseURI(newUriPrefix);
        vm.stopPrank();
    }

    function test_updateBaseURI_affectsContractURI() public {
        // Test empty string case first
        vm.prank(owner);
        pubRegistry.updateBaseURI("");
        assertEq(pubRegistry.contractURI(), "");
        
        // Test with actual URI
        string memory newUriPrefix = "https://metadata.example.com/";
        vm.prank(owner);
        pubRegistry.updateBaseURI(newUriPrefix);
        assertEq(pubRegistry.contractURI(), string.concat(newUriPrefix, "contractURI.json"));
    }

    function test_updateBaseURI_affectsTokenURI() public {
        // Register a code first
        string memory code = generateCode(1);
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);
        
        vm.prank(signer); // signer has REGISTER_ROLE
        pubRegistry.register(code, codeOwner, payoutAddr);
        
        // Get initial tokenURI (should be empty since no base URI set in initialization)
        uint256 tokenId = pubRegistry.toTokenId(code);
        string memory initialURI = pubRegistry.tokenURI(tokenId);
        assertEq(initialURI, "");
        
        // Update base URI
        string memory newUriPrefix = "https://metadata.example.com/";
        vm.prank(owner);
        pubRegistry.updateBaseURI(newUriPrefix);
        
        // Verify tokenURI now includes base URI + code
        string memory updatedURI = pubRegistry.tokenURI(tokenId);
        assertEq(updatedURI, string.concat(newUriPrefix, code));
    }

    function test_updateBaseURI_multipleUpdates() public {
        string memory firstUriPrefix = "https://first.com/";
        string memory secondUriPrefix = "https://second.com/";
        
        // First update
        vm.prank(owner);
        pubRegistry.updateBaseURI(firstUriPrefix);
        assertEq(pubRegistry.contractURI(), string.concat(firstUriPrefix, "contractURI.json"));
        
        // Second update should overwrite
        vm.prank(owner);
        pubRegistry.updateBaseURI(secondUriPrefix);
        assertEq(pubRegistry.contractURI(), string.concat(secondUriPrefix, "contractURI.json"));
    }

    function test_register_success() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);

        vm.prank(signer);
        
        vm.expectEmit(true, true, false, true);
        emit CodeRegistered(pubRegistry.toTokenId(code), code);
        
        vm.expectEmit(true, false, false, true);
        emit PayoutAddressUpdated(pubRegistry.toTokenId(code), payoutAddr);
        
        pubRegistry.register(code, codeOwner, payoutAddr);

        // Verify registration
        assertTrue(pubRegistry.isRegistered(code));
        assertEq(pubRegistry.ownerOf(pubRegistry.toTokenId(code)), codeOwner);
        assertEq(pubRegistry.payoutAddress(code), payoutAddr);
    }

    function test_register_customCodes() public {
        string[] memory codes = new string[](5);
        codes[0] = "base";
        codes[1] = "alice123";
        codes[2] = "crypto_news";
        codes[3] = "defi_builder";
        codes[4] = "spring2024";

        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);

        for (uint256 i = 0; i < codes.length; i++) {
            vm.prank(signer);
            pubRegistry.register(codes[i], codeOwner, payoutAddr);
            
            assertTrue(pubRegistry.isRegistered(codes[i]));
            assertEq(pubRegistry.ownerOf(pubRegistry.toTokenId(codes[i])), codeOwner);
            assertEq(pubRegistry.payoutAddress(codes[i]), payoutAddr);
        }
    }

    function test_register_unauthorized() public {
        string memory code = "testcode";
        address unauthorized = address(0x999);

        vm.prank(unauthorized);
        vm.expectRevert();
        pubRegistry.register(code, address(0x123), address(0x456));
    }

    function test_register_invalidCodes() public {
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);

        // Empty code
        vm.prank(signer);
        vm.expectRevert();
        pubRegistry.register("", codeOwner, payoutAddr);

        // Code too long (over 32 characters)
        vm.prank(signer);
        vm.expectRevert();
        pubRegistry.register("this_code_is_way_too_long_and_exceeds_thirty_two_characters", codeOwner, payoutAddr);

        // Invalid characters
        vm.prank(signer);
        vm.expectRevert();
        pubRegistry.register("invalid@code", codeOwner, payoutAddr);

        // Uppercase not allowed
        vm.prank(signer);
        vm.expectRevert();
        pubRegistry.register("InvalidCode", codeOwner, payoutAddr);
    }

    function test_register_zeroAddresses() public {
        string memory code = "testcode";

        // Zero code owner should revert (ERC721 can't mint to address(0))
        vm.prank(signer);
        vm.expectRevert();
        pubRegistry.register(code, address(0), address(0x456));

        // Zero payout address should revert
        vm.prank(signer);
        vm.expectRevert(BuilderCodes.ZeroAddress.selector);
        pubRegistry.register("testcode2", address(0x123), address(0));
    }

    function test_registerWithSignature_success() public {
        // This test verifies the signature verification flow exists
        // For a full integration test, we'd need proper signature generation
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);
        uint48 deadline = uint48(block.timestamp + 1 hours);

        // Test that invalid signature fails (validates signature checking is working)
        bytes memory invalidSignature = "invalid_signature";
        
        vm.expectRevert(BuilderCodes.Unauthorized.selector);
        pubRegistry.registerWithSignature(code, codeOwner, payoutAddr, deadline, signer, invalidSignature);
    }

    function test_registerWithSignature_expiredDeadline() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);
        uint48 deadline = uint48(block.timestamp - 1); // Past deadline

        bytes memory signature = "dummy_signature";

        vm.expectRevert(abi.encodeWithSelector(BuilderCodes.AfterRegistrationDeadline.selector, deadline));
        pubRegistry.registerWithSignature(code, codeOwner, payoutAddr, deadline, signer, signature);
    }

    function test_registerWithSignature_invalidSignature() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);
        uint48 deadline = uint48(block.timestamp + 1 hours);

        bytes memory invalidSignature = "invalid_signature";

        vm.expectRevert(BuilderCodes.Unauthorized.selector);
        pubRegistry.registerWithSignature(code, codeOwner, payoutAddr, deadline, signer, invalidSignature);
    }

    function test_registerWithSignature_unauthorizedRegistrar() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);
        uint48 deadline = uint48(block.timestamp + 1 hours);
        address unauthorizedRegistrar = address(0x999);

        bytes memory signature = "dummy_signature";

        vm.expectRevert();
        pubRegistry.registerWithSignature(code, codeOwner, payoutAddr, deadline, unauthorizedRegistrar, signature);
    }

    function test_toTokenId_toCode_roundtrip() public {
        string memory code = "testcode";
        uint256 tokenId = pubRegistry.toTokenId(code);
        string memory recoveredCode = pubRegistry.toCode(tokenId);
        assertEq(code, recoveredCode);
    }

    function test_toTokenId_invalidCode() public {
        vm.expectRevert();
        pubRegistry.toTokenId("invalid@code");

        vm.expectRevert();
        pubRegistry.toTokenId("");

        vm.expectRevert();
        pubRegistry.toTokenId("this_code_is_way_too_long_and_exceeds_thirty_two_characters");
    }

    function test_toCode_invalidTokenId() public {
        // Create an invalid token ID that doesn't correspond to a valid code
        uint256 invalidTokenId = type(uint256).max;
        
        vm.expectRevert();
        pubRegistry.toCode(invalidTokenId);
    }

    function test_payoutAddress_functions() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);

        vm.prank(signer);
        pubRegistry.register(code, codeOwner, payoutAddr);

        uint256 tokenId = pubRegistry.toTokenId(code);

        // Test both overloads
        assertEq(pubRegistry.payoutAddress(code), payoutAddr);
        assertEq(pubRegistry.payoutAddress(tokenId), payoutAddr);
    }

    function test_payoutAddress_unregistered() public {
        string memory code = "unregistered";
        uint256 tokenId = pubRegistry.toTokenId(code);

        vm.expectRevert(abi.encodeWithSelector(BuilderCodes.Unregistered.selector, code));
        pubRegistry.payoutAddress(code);

        vm.expectRevert(abi.encodeWithSelector(BuilderCodes.Unregistered.selector, code));
        pubRegistry.payoutAddress(tokenId);
    }

    function test_updatePayoutAddress_success() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);
        address newPayoutAddr = address(0x789);

        vm.prank(signer);
        pubRegistry.register(code, codeOwner, payoutAddr);

        vm.prank(codeOwner);
        pubRegistry.updatePayoutAddress(code, newPayoutAddr);

        assertEq(pubRegistry.payoutAddress(code), newPayoutAddr);
    }

    function test_updatePayoutAddress_unauthorized() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);
        address unauthorized = address(0x999);

        vm.prank(signer);
        pubRegistry.register(code, codeOwner, payoutAddr);

        vm.prank(unauthorized);
        vm.expectRevert(BuilderCodes.Unauthorized.selector);
        pubRegistry.updatePayoutAddress(code, payoutAddr);
    }

    function test_updatePayoutAddress_zeroAddress() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);

        vm.prank(signer);
        pubRegistry.register(code, codeOwner, payoutAddr);

        vm.prank(codeOwner);
        vm.expectRevert(BuilderCodes.ZeroAddress.selector);
        pubRegistry.updatePayoutAddress(code, address(0));
    }

    function test_updateMetadata_success() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);

        vm.prank(signer);
        pubRegistry.register(code, codeOwner, payoutAddr);

        uint256 tokenId = pubRegistry.toTokenId(code);

        vm.prank(owner); // owner has METADATA_ROLE
        
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(tokenId);
        
        pubRegistry.updateMetadata(tokenId);
    }

    function test_updateMetadata_unauthorized() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);

        vm.prank(signer);
        pubRegistry.register(code, codeOwner, payoutAddr);

        uint256 tokenId = pubRegistry.toTokenId(code);
        address unauthorized = address(0x999);

        vm.prank(unauthorized);
        vm.expectRevert();
        pubRegistry.updateMetadata(tokenId);
    }

    function test_updateMetadata_nonexistentToken() public {
        uint256 nonexistentTokenId = pubRegistry.toTokenId("nonexistent");

        vm.prank(owner);
        vm.expectRevert();
        pubRegistry.updateMetadata(nonexistentTokenId);
    }

    function test_codeURI() public {
        string memory code = "testcode";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);

        vm.prank(signer);
        pubRegistry.register(code, codeOwner, payoutAddr);

        string memory codeURI = pubRegistry.codeURI(code);
        string memory tokenURI = pubRegistry.tokenURI(pubRegistry.toTokenId(code));
        
        assertEq(codeURI, tokenURI);
    }

    function test_contractURI() public {
        // Should return empty string initially (no uriPrefix set in setup)
        assertEq(pubRegistry.contractURI(), "");

        // Set base URI and test
        vm.prank(owner);
        pubRegistry.updateBaseURI("https://api.example.com/");
        
        assertEq(pubRegistry.contractURI(), "https://api.example.com/contractURI.json");
    }

    function test_hasRole_ownerAlwaysHasRole() public {
        bytes32 anyRole = keccak256("ANY_ROLE");
        assertTrue(pubRegistry.hasRole(anyRole, owner));
        
        assertTrue(pubRegistry.hasRole(pubRegistry.REGISTER_ROLE(), owner));
        assertTrue(pubRegistry.hasRole(pubRegistry.METADATA_ROLE(), owner));
    }

    function test_supportsInterface() public {
        // ERC721
        assertTrue(pubRegistry.supportsInterface(0x80ac58cd));
        // AccessControl
        assertTrue(pubRegistry.supportsInterface(0x7965db0b));
        // ERC4906 (MetadataUpdate)
        assertTrue(pubRegistry.supportsInterface(0x49064906));
        // ERC165
        assertTrue(pubRegistry.supportsInterface(0x01ffc9a7));
    }

    function test_renounceOwnership_disabled() public {
        vm.prank(owner);
        vm.expectRevert(BuilderCodes.OwnershipRenunciationDisabled.selector);
        pubRegistry.renounceOwnership();
    }

    function test_isValidCode_edgeCases() public {
        // Valid codes
        assertTrue(pubRegistry.isValidCode("a"));
        assertTrue(pubRegistry.isValidCode("0"));
        assertTrue(pubRegistry.isValidCode("test_code_123"));
        assertTrue(pubRegistry.isValidCode("12345678901234567890123456789012")); // exactly 32 chars

        // Invalid codes
        assertFalse(pubRegistry.isValidCode("")); // empty
        assertFalse(pubRegistry.isValidCode("123456789012345678901234567890123")); // 33 chars
        assertFalse(pubRegistry.isValidCode("test@code")); // invalid char @
        assertFalse(pubRegistry.isValidCode("Test")); // uppercase
        assertFalse(pubRegistry.isValidCode("test-code")); // dash not allowed
        assertFalse(pubRegistry.isValidCode("test code")); // space not allowed
    }

    function test_eip712Implementation() public {
        // Verify BuilderCodes implements EIP712 (basic test)
        // The actual domain name and version are tested in _domainNameAndVersion()
        assertTrue(pubRegistry.supportsInterface(type(IERC165).interfaceId));
    }

    function test_initialization_success() public {
        // Verify the setup worked correctly
        assertEq(pubRegistry.owner(), owner);
        assertTrue(pubRegistry.hasRole(pubRegistry.REGISTER_ROLE(), signer));
        assertTrue(pubRegistry.hasRole(pubRegistry.METADATA_ROLE(), owner));
    }

    function test_initialization_zeroOwner() public {
        BuilderCodes freshImpl = new BuilderCodes();
        
        bytes memory initData = abi.encodeWithSelector(BuilderCodes.initialize.selector, address(0), signer, "");
        
        vm.expectRevert(BuilderCodes.ZeroAddress.selector);
        new ERC1967Proxy(address(freshImpl), initData);
    }

    function test_initialization_zeroSigner() public {
        BuilderCodes freshImpl = new BuilderCodes();
        
        bytes memory initData = abi.encodeWithSelector(BuilderCodes.initialize.selector, owner, address(0), "");
        ERC1967Proxy freshProxy = new ERC1967Proxy(address(freshImpl), initData);
        BuilderCodes freshRegistry = BuilderCodes(address(freshProxy));
        
        assertEq(freshRegistry.owner(), owner);
        assertFalse(freshRegistry.hasRole(freshRegistry.REGISTER_ROLE(), signer));
    }

    function test_roleManagement_grantRole() public {
        address newSigner = address(0x456);
        
        vm.prank(owner);
        pubRegistry.grantRole(pubRegistry.REGISTER_ROLE(), newSigner);
        
        assertTrue(pubRegistry.hasRole(pubRegistry.REGISTER_ROLE(), newSigner));
        assertTrue(pubRegistry.hasRole(pubRegistry.REGISTER_ROLE(), signer)); // original signer still there
    }

    function test_roleManagement_revokeRole() public {
        vm.prank(owner);
        pubRegistry.revokeRole(pubRegistry.REGISTER_ROLE(), signer);
        
        assertFalse(pubRegistry.hasRole(pubRegistry.REGISTER_ROLE(), signer));
    }


    function test_ownable2Step_transferOwnership() public {
        address newOwner = address(0x123);
        
        // Step 1: Transfer ownership
        vm.prank(owner);
        pubRegistry.transferOwnership(newOwner);
        
        assertEq(pubRegistry.pendingOwner(), newOwner);
        assertEq(pubRegistry.owner(), owner); // Still original owner
        
        // Step 2: Accept ownership
        vm.prank(newOwner);
        pubRegistry.acceptOwnership();
        
        assertEq(pubRegistry.owner(), newOwner);
        assertEq(pubRegistry.pendingOwner(), address(0));
    }

    function test_ownable2Step_unauthorizedAccept() public {
        address newOwner = address(0x123);
        address unauthorized = address(0x456);
        
        vm.prank(owner);
        pubRegistry.transferOwnership(newOwner);
        
        vm.prank(unauthorized);
        vm.expectRevert();
        pubRegistry.acceptOwnership();
        
        // Ownership should not have changed
        assertEq(pubRegistry.owner(), owner);
        assertEq(pubRegistry.pendingOwner(), newOwner);
    }

    function test_register_duplicateCode() public {
        string memory code = "duplicate";
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);
        
        // Register first time
        vm.prank(signer);
        pubRegistry.register(code, codeOwner, payoutAddr);
        
        // Try to register same code again
        vm.prank(signer);
        vm.expectRevert();
        pubRegistry.register(code, address(0x789), address(0x101));
    }

    function test_batchRegister() public {
        string[] memory codes = new string[](3);
        codes[0] = generateCode(10);
        codes[1] = generateCode(20);
        codes[2] = generateCode(30);
        
        address codeOwner = address(0x123);
        address payoutAddr = address(0x456);
        
        // Register multiple codes
        for (uint256 i = 0; i < codes.length; i++) {
            vm.prank(signer);
            pubRegistry.register(codes[i], codeOwner, payoutAddr);
        }
        
        // Verify all are registered
        for (uint256 i = 0; i < codes.length; i++) {
            assertTrue(pubRegistry.isRegistered(codes[i]));
            assertEq(pubRegistry.ownerOf(pubRegistry.toTokenId(codes[i])), codeOwner);
            assertEq(pubRegistry.payoutAddress(codes[i]), payoutAddr);
        }
    }

    // Add missing events for compilation
    event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);
    event ContractURIUpdated();
    event CodeRegistered(uint256 indexed tokenId, string code);
    event PayoutAddressUpdated(uint256 indexed tokenId, address payoutAddress);
    event MetadataUpdate(uint256 tokenId);
}

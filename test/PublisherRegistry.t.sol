pragma solidity 0.8.29;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ReferralCodeRegistry} from "../src/ReferralCodeRegistry.sol";

contract ReferralCodeRegistryTest is Test {
    ReferralCodeRegistry public implementation;
    ReferralCodeRegistry public pubRegistry;
    ERC1967Proxy public proxy;

    address private owner = address(this);
    address private signer = address(0x123);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation
        implementation = new ReferralCodeRegistry();

        // Deploy proxy with signer address
        bytes memory initData = abi.encodeWithSelector(ReferralCodeRegistry.initialize.selector, owner, signer);
        proxy = new ERC1967Proxy(address(implementation), initData);

        // Create interface to proxy
        pubRegistry = ReferralCodeRegistry(address(proxy));

        vm.stopPrank();
    }

    function test_constructor() public {
        assertEq(pubRegistry.owner(), owner);
        assertTrue(pubRegistry.hasRole(implementation.SIGNER_ROLE(), signer));
    }

    function test_initializeWithZeroOwner() public {
        // Deploy fresh implementation
        ReferralCodeRegistry freshImpl = new ReferralCodeRegistry();

        // Try to initialize with zero owner
        bytes memory initData = abi.encodeWithSelector(ReferralCodeRegistry.initialize.selector, address(0), address(0));

        vm.expectRevert(ReferralCodeRegistry.ZeroAddress.selector);
        new ERC1967Proxy(address(freshImpl), initData);
    }

    function test_initializeWithZeroSigner() public {
        // Deploy fresh implementation
        ReferralCodeRegistry freshImpl = new ReferralCodeRegistry();

        // Initialize with zero signer (should be allowed)
        bytes memory initData = abi.encodeWithSelector(ReferralCodeRegistry.initialize.selector, owner, address(0));
        ERC1967Proxy freshProxy = new ERC1967Proxy(address(freshImpl), initData);
        ReferralCodeRegistry freshRegistry = ReferralCodeRegistry(address(freshProxy));

        assertEq(freshRegistry.owner(), owner);
        assertFalse(freshRegistry.hasRole(implementation.SIGNER_ROLE(), address(0x123))); // No signers
    }

    function test_grantSignerRole() public {
        address newSigner = address(0x456);

        vm.startPrank(owner);

        // Expect the event before calling the function
        vm.expectEmit(true, true, false, false);
        emit IAccessControl.RoleGranted(implementation.SIGNER_ROLE(), newSigner, owner);

        pubRegistry.grantRole(implementation.SIGNER_ROLE(), newSigner);

        vm.stopPrank();

        assertTrue(pubRegistry.hasRole(implementation.SIGNER_ROLE(), newSigner));
        assertTrue(pubRegistry.hasRole(implementation.SIGNER_ROLE(), signer)); // original signer still there
    }

    // todo: something is not working here for some reason
    // function test_grantSignerRole_Unauthorized(address account, address newSigner) public {
    //     vm.assume(account != pubRegistry.owner());
    //     vm.assume(!pubRegistry.hasRole(pubRegistry.getRoleAdmin(pubRegistry.SIGNER_ROLE()), account));
    //     vm.assume(newSigner != owner);
    //     vm.assume(newSigner != signer);

    //     vm.startPrank(account);
    //     vm.expectRevert(); //)abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", account, pubRegistry.SIGNER_ROLE()));
    //     pubRegistry.grantRole(pubRegistry.SIGNER_ROLE(), newSigner);
    //     vm.stopPrank();
    // }

    function test_revokeSignerRole() public {
        vm.startPrank(owner);

        // First verify signer has role
        assertTrue(pubRegistry.hasRole(implementation.SIGNER_ROLE(), signer));

        vm.expectEmit(true, true, false, false);
        emit IAccessControl.RoleRevoked(implementation.SIGNER_ROLE(), signer, owner);

        pubRegistry.revokeRole(pubRegistry.SIGNER_ROLE(), signer);

        vm.stopPrank();

        assertFalse(pubRegistry.hasRole(implementation.SIGNER_ROLE(), signer));
    }

    function test_registerCustom_BySigner() public {
        string memory customRefCode = "custom123";
        address publisherOwner = address(0x789);
        string memory metadataUrl = "https://example.com";
        address defaultPayout = address(0x101);

        vm.startPrank(signer);

        // Expect the event before calling the function
        vm.expectEmit(true, true, true, true);
        emit ReferralCodeRegistry.ReferralCodeRegistered(
            customRefCode, publisherOwner, defaultPayout, metadataUrl, true
        );

        pubRegistry.registerCustom(customRefCode, publisherOwner, defaultPayout, metadataUrl);

        vm.stopPrank();

        // Verify the publisher was registered
        assertEq(pubRegistry.getOwner(customRefCode), publisherOwner);
        assertEq(pubRegistry.getMetadataUrl(customRefCode), metadataUrl);
        assertEq(pubRegistry.getPayoutRecipient(customRefCode), defaultPayout);
        assertEq(pubRegistry.isReferralCodeRegistered(customRefCode), true);
    }

    function test_registerCustom_ByOwner() public {
        string memory customRefCode = "owner123";
        address publisherOwner = address(0x789);
        string memory metadataUrl = "https://example.com";
        address defaultPayout = address(0x101);

        vm.startPrank(owner);

        pubRegistry.registerCustom(customRefCode, publisherOwner, defaultPayout, metadataUrl);

        vm.stopPrank();

        // Verify the publisher was registered
        assertEq(pubRegistry.getOwner(customRefCode), publisherOwner);
        assertEq(pubRegistry.getMetadataUrl(customRefCode), metadataUrl);
        assertEq(pubRegistry.getPayoutRecipient(customRefCode), defaultPayout);
        assertEq(pubRegistry.isReferralCodeRegistered(customRefCode), true);
    }

    function test_registerCustom_Unauthorized() public {
        string memory customRefCode = "unauth123";
        address unauthorized = address(0x999);

        vm.startPrank(unauthorized);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, pubRegistry.SIGNER_ROLE()
            )
        );
        pubRegistry.registerCustom(customRefCode, address(0x789), address(0x101), "https://example.com");

        vm.stopPrank();
    }

    function test_registerCustom_WithZeroSigner() public {
        // Deploy registry with zero signer
        ReferralCodeRegistry freshImpl = new ReferralCodeRegistry();
        bytes memory initData = abi.encodeWithSelector(ReferralCodeRegistry.initialize.selector, owner, address(0));
        ERC1967Proxy freshProxy = new ERC1967Proxy(address(freshImpl), initData);
        ReferralCodeRegistry freshRegistry = ReferralCodeRegistry(address(freshProxy));

        string memory customRefCode = "zero123";

        // Only owner should be able to call when signer is zero
        vm.startPrank(owner);
        freshRegistry.registerCustom(customRefCode, address(0x789), address(0x101), "https://example.com");
        vm.stopPrank();

        // Verify it worked
        assertEq(freshRegistry.getOwner(customRefCode), address(0x789));
        assertEq(freshRegistry.getPayoutRecipient(customRefCode), address(0x101));
        assertEq(freshRegistry.getMetadataUrl(customRefCode), "https://example.com");
        assertEq(freshRegistry.isReferralCodeRegistered(customRefCode), true);

        // Unauthorized address should fail
        vm.startPrank(address(0x999));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(0x999), freshRegistry.SIGNER_ROLE()
            )
        );
        freshRegistry.registerCustom("fail123", address(0x789), address(0x101), "https://example.com");
        vm.stopPrank();
    }

    string private publisherMetadataUrl = "https://example.com";
    address private publisherOwner = address(1e6);
    address private defaultPayout = address(1e7);
    uint256 private optimismChainId = 10;
    address private optimismPayout = address(1e8);

    function registerDefaultPublisher() internal returns (string memory) {
        vm.startPrank(publisherOwner);
        string memory refCode = pubRegistry.register(defaultPayout, publisherMetadataUrl);
        vm.stopPrank();

        return refCode;
    }

    function test_registerPublisher() public {
        // Then execute the registration
        vm.startPrank(publisherOwner);
        string memory refCode = pubRegistry.register(defaultPayout, publisherMetadataUrl);
        vm.stopPrank();

        // Verify state changes
        assertEq(pubRegistry.getOwner(refCode), publisherOwner);
        assertEq(pubRegistry.getMetadataUrl(refCode), publisherMetadataUrl);
        assertEq(pubRegistry.getPayoutRecipient(refCode), defaultPayout);
        assertEq(pubRegistry.isReferralCodeRegistered(refCode), true);
        assertEq(pubRegistry.computeReferralCode(pubRegistry.nonce()), refCode);
    }

    function test_updateMetadataUrl() public {
        string memory refCode = registerDefaultPublisher();
        string memory newDimsUrl = "https://new.com";

        vm.startPrank(publisherOwner);

        // Expect the event before calling the function
        vm.expectEmit(true, true, true, true);
        emit ReferralCodeRegistry.ReferralCodeMetadataUrlUpdated(refCode, newDimsUrl);

        pubRegistry.updateMetadataUrl(refCode, newDimsUrl);

        vm.stopPrank();

        assertEq(pubRegistry.getMetadataUrl(refCode), newDimsUrl);
    }

    function test_updatePublisherDefaultPayout() public {
        string memory refCode = registerDefaultPublisher();
        address newDefaultPayout = address(0x999);

        vm.startPrank(publisherOwner);

        // Expect the event before calling the function
        vm.expectEmit(true, true, true, true);
        emit ReferralCodeRegistry.ReferralCodePayoutRecipientUpdated(refCode, newDefaultPayout);

        pubRegistry.updatePayoutRecipient(refCode, newDefaultPayout);

        vm.stopPrank();

        assertEq(pubRegistry.getPayoutRecipient(refCode), newDefaultPayout);

        // non-publisher cannot update default payout
        vm.startPrank(address(0x123));
        vm.expectRevert(ReferralCodeRegistry.Unauthorized.selector);
        pubRegistry.updatePayoutRecipient(refCode, newDefaultPayout);
        vm.stopPrank();
    }

    function test_changePublisherOwner() public {
        string memory refCode = registerDefaultPublisher();
        address newOwner = address(0x999);
        vm.startPrank(publisherOwner);
        pubRegistry.updateOwner(refCode, newOwner);

        vm.stopPrank();

        assertEq(pubRegistry.getOwner(refCode), newOwner);

        // non-publisher cannot update owner
        vm.startPrank(address(0x123));
        vm.expectRevert(ReferralCodeRegistry.Unauthorized.selector);
        pubRegistry.updateOwner(refCode, newOwner);
        vm.stopPrank();
    }

    function test_computeReferralCode() public {
        registerDefaultPublisher();
        string memory refCode1 = pubRegistry.computeReferralCode(1);
        console.log("xxx ref code 1", refCode1);

        string memory refCode2 = pubRegistry.computeReferralCode(2);
        console.log("xxx ref code 2", refCode2);

        string memory refCode3 = pubRegistry.computeReferralCode(3);
        console.log("xxx ref code 3", refCode3);

        string memory refCode4333 = pubRegistry.computeReferralCode(4333);
        console.log("xxx ref code 4333", refCode4333);
    }

    function test_refCodeCollision() public {
        // These nonces are known to generate the first collision
        uint256 nonce1 = 2_397_017;
        uint256 nonce2 = 3_210_288;

        // Verify they actually generate the same ref code
        string memory refCode1 = pubRegistry.computeReferralCode(nonce1);
        string memory refCode2 = pubRegistry.computeReferralCode(nonce2);
        assertEq(refCode1, refCode2, "Test setup error: nonces should generate same ref code");
        console.log("xxx ref code 1", refCode1);
        console.log("xxx ref code 2", refCode2);

        // Force the nextPublisherNonce to be just before the first collision
        vm.store(
            address(pubRegistry),
            bytes32(uint256(1)), // slot 1 contains nextPublisherNonce
            bytes32(nonce1)
        );

        // Register first publisher - should get the ref code from nonce1
        vm.startPrank(publisherOwner);
        string memory firstRefCode = pubRegistry.register(defaultPayout, "first.com");
        uint256 firstNonce = pubRegistry.nonce();

        // Register second publisher - should skip the collision and generate a new unique code
        string memory secondRefCode = pubRegistry.register(defaultPayout, "second.com");
        uint256 secondNonce = pubRegistry.nonce();
        vm.stopPrank();

        console.log("xxx first registered ref code", firstRefCode);
        console.log("xxx second registered ref code", secondRefCode);

        // Verify we got different ref codes
        assertTrue(
            keccak256(abi.encode(firstRefCode)) != keccak256(abi.encode(secondRefCode)),
            "Should generate different ref codes"
        );

        assertEq(firstRefCode, pubRegistry.computeReferralCode(firstNonce), "First ref code mismatch");
        assertEq(secondRefCode, pubRegistry.computeReferralCode(secondNonce), "Second ref code mismatch");

        // Verify both publishers were registered with their respective ref codes
        assertEq(pubRegistry.getOwner(firstRefCode), publisherOwner, "First publisher not registered correctly");
        assertEq(pubRegistry.getOwner(secondRefCode), publisherOwner, "Second publisher not registered correctly");
    }

    function test_registerCustom() public {
        string memory customRefCode = "custom123";
        address customOwner = address(0x123);
        string memory customMetadataUrl = "https://custom.com";
        address customDefaultPayout = address(0x456);

        vm.startPrank(owner);

        // Expect events before calling the function
        vm.expectEmit(true, true, true, true);
        emit ReferralCodeRegistry.ReferralCodeRegistered(
            customRefCode, customOwner, customDefaultPayout, customMetadataUrl, true
        );

        pubRegistry.registerCustom(customRefCode, customOwner, customDefaultPayout, customMetadataUrl);

        vm.stopPrank();

        assertEq(pubRegistry.getOwner(customRefCode), customOwner);
        assertEq(pubRegistry.getMetadataUrl(customRefCode), customMetadataUrl);
        assertEq(pubRegistry.getPayoutRecipient(customRefCode), customDefaultPayout);
        assertEq(pubRegistry.isReferralCodeRegistered(customRefCode), true);
    }

    function test_registerCustom_RefCodeTaken() public {
        string memory customRefCode = "custom123";

        // Register first publisher
        vm.startPrank(owner);
        pubRegistry.registerCustom(customRefCode, address(0x123), address(0x456), "https://first.com");

        // Try to register second publisher with same ref code
        vm.expectRevert(ReferralCodeRegistry.AlreadyRegistered.selector);
        pubRegistry.registerCustom(customRefCode, address(0x789), address(0x101), "https://second.com");
        vm.stopPrank();
    }

    function test_updatePublisherOwner_Unauthorized() public {
        string memory refCode = registerDefaultPublisher();
        address newOwner = address(0x999);

        // Try to update owner from unauthorized address
        vm.startPrank(address(0x123));
        vm.expectRevert(ReferralCodeRegistry.Unauthorized.selector);
        pubRegistry.updateOwner(refCode, newOwner);
        vm.stopPrank();
    }

    function test_updatePublisherOwner_NewOwnerCanUpdate() public {
        string memory refCode = registerDefaultPublisher();
        address newOwner = address(0x999);

        // Current owner updates to new owner
        vm.startPrank(publisherOwner);
        pubRegistry.updateOwner(refCode, newOwner);
        vm.stopPrank();

        // Verify new owner can make updates
        vm.startPrank(newOwner);
        string memory newMetadataUrl = "https://newowner.com";
        pubRegistry.updateMetadataUrl(refCode, newMetadataUrl);
        vm.stopPrank();

        // Verify old owner cannot make updates
        vm.startPrank(publisherOwner);
        vm.expectRevert(ReferralCodeRegistry.Unauthorized.selector);
        pubRegistry.updateMetadataUrl(refCode, "https://oldowner.com");
        vm.stopPrank();

        // Verify metadata was updated by new owner
        assertEq(pubRegistry.getMetadataUrl(refCode), newMetadataUrl);
    }

    function test_updatePublisherOwner_RevertOnZeroAddress() public {
        string memory refCode = registerDefaultPublisher();

        // Try to update owner to address(0)
        vm.startPrank(publisherOwner);
        vm.expectRevert(ReferralCodeRegistry.ZeroAddress.selector);
        pubRegistry.updateOwner(refCode, address(0));
        vm.stopPrank();
    }

    function test_getPayoutRecipient() public {
        string memory refCode = registerDefaultPublisher();

        address payoutAddress = pubRegistry.getPayoutRecipient(refCode);
        assertEq(payoutAddress, defaultPayout, "Should return default payout address");
    }

    // Tests for missing coverage lines

    /// @notice Test renounceOwnership function should revert
    function test_renounceOwnership_shouldRevert() public {
        vm.prank(owner);
        vm.expectRevert(ReferralCodeRegistry.OwnershipRenunciationDisabled.selector);
        pubRegistry.renounceOwnership();
    }

    /// @notice Test return statement in _generateUniqueRefCode with no collision
    function test_generateUniqueRefCode_firstTrySuccess() public {
        // This tests the return statement on line 250 when no collision occurs
        // Register a publisher, which calls _generateUniqueRefCode internally
        vm.startPrank(publisherOwner);
        string memory refCode = pubRegistry.register(defaultPayout, publisherMetadataUrl);
        vm.stopPrank();

        // Verify the ref code was generated correctly
        assertEq(refCode, pubRegistry.computeReferralCode(pubRegistry.nonce()), "Ref code should match generated nonce");

        // Verify publisher was registered with the generated ref code
        assertEq(
            pubRegistry.getOwner(refCode), publisherOwner, "Publisher should be registered with generated ref code"
        );
    }

    // Ownable2Step transfer ownership tests

    /// @notice Test complete ownership transfer flow
    function test_ownable2Step_transferOwnership_complete() public {
        address newOwner = address(0x123);

        // Step 1: Current owner transfers ownership
        vm.prank(owner);
        pubRegistry.transferOwnership(newOwner);

        // Verify pending owner is set but owner hasn't changed yet
        assertEq(pubRegistry.pendingOwner(), newOwner, "Pending owner should be set");
        assertEq(pubRegistry.owner(), owner, "Original owner should still be owner");

        // Step 2: New owner accepts ownership
        vm.prank(newOwner);
        pubRegistry.acceptOwnership();

        // Verify ownership has been transferred
        assertEq(pubRegistry.owner(), newOwner, "New owner should be owner");
        assertEq(pubRegistry.pendingOwner(), address(0), "Pending owner should be cleared");
    }

    /// @notice Test only pending owner can accept ownership
    function test_ownable2Step_acceptOwnership_onlyPendingOwner() public {
        address newOwner = address(0x123);
        address unauthorized = address(0x456);

        // Transfer ownership
        vm.prank(owner);
        pubRegistry.transferOwnership(newOwner);

        // Try to accept from unauthorized address
        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", unauthorized));
        pubRegistry.acceptOwnership();

        // Verify ownership hasn't changed
        assertEq(pubRegistry.owner(), owner, "Owner should not have changed");
        assertEq(pubRegistry.pendingOwner(), newOwner, "Pending owner should still be set");
    }

    /// @notice Test transfer ownership to zero address (renunciation via 2-step)
    function test_ownable2Step_transferOwnership_zeroAddress() public {
        vm.prank(owner);
        // OpenZeppelin 5.x allows transferring to zero address (effectively renouncing ownership)
        // This sets pendingOwner to zero address, and acceptOwnership would complete the renunciation
        pubRegistry.transferOwnership(address(0));

        // Verify pending owner is set to zero address
        assertEq(pubRegistry.pendingOwner(), address(0), "Pending owner should be zero address");
        assertEq(pubRegistry.owner(), owner, "Original owner should still be owner until accepted");

        // Accept ownership (renunciation)
        vm.prank(address(0));
        pubRegistry.acceptOwnership();

        // Verify ownership has been renounced
        assertEq(pubRegistry.owner(), address(0), "Owner should be zero address after renunciation");
        assertEq(pubRegistry.pendingOwner(), address(0), "Pending owner should be cleared");
    }

    /// @notice Test overwriting pending owner before acceptance
    function test_ownable2Step_transferOwnership_overwrite() public {
        address firstNewOwner = address(0x123);
        address secondNewOwner = address(0x456);

        // Transfer to first new owner
        vm.prank(owner);
        pubRegistry.transferOwnership(firstNewOwner);

        assertEq(pubRegistry.pendingOwner(), firstNewOwner, "First pending owner should be set");

        // Transfer to second new owner (overwrites first)
        vm.prank(owner);
        pubRegistry.transferOwnership(secondNewOwner);

        assertEq(pubRegistry.pendingOwner(), secondNewOwner, "Second pending owner should overwrite first");

        // First owner cannot accept anymore
        vm.prank(firstNewOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", firstNewOwner));
        pubRegistry.acceptOwnership();

        // Second owner can accept
        vm.prank(secondNewOwner);
        pubRegistry.acceptOwnership();

        assertEq(pubRegistry.owner(), secondNewOwner, "Second owner should become owner");
    }

    /// @notice Test that only current owner can transfer ownership
    function test_ownable2Step_transferOwnership_onlyOwner() public {
        address unauthorized = address(0x123);
        address newOwner = address(0x456);

        vm.prank(unauthorized);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", unauthorized));
        pubRegistry.transferOwnership(newOwner);
    }

    /// @notice Test new owner can perform owner functions after acceptance
    function test_ownable2Step_newOwnerCanPerformOwnerFunctions() public {
        address newOwner = address(0x123);

        // Transfer and accept ownership
        vm.prank(owner);
        pubRegistry.transferOwnership(newOwner);

        vm.prank(newOwner);
        pubRegistry.acceptOwnership();

        // New owner should be able to register custom publishers
        vm.prank(newOwner);
        pubRegistry.registerCustom("newowner123", address(0x789), address(0x101), "https://newowner.com");

        // Verify custom publisher was registered
        assertEq(pubRegistry.getOwner("newowner123"), address(0x789));
        assertEq(pubRegistry.getPayoutRecipient("newowner123"), address(0x101));
        assertEq(pubRegistry.getMetadataUrl("newowner123"), "https://newowner.com");
        assertEq(pubRegistry.isReferralCodeRegistered("newowner123"), true);
    }

    /// @notice Test old owner cannot perform owner functions after transfer
    function test_ownable2Step_oldOwnerCannotPerformOwnerFunctions() public {
        address newOwner = address(0x123);

        // Transfer and accept ownership
        vm.prank(owner);
        pubRegistry.transferOwnership(newOwner);

        vm.prank(newOwner);
        pubRegistry.acceptOwnership();

        // Old owner should not be able to register custom publishers
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, owner, pubRegistry.SIGNER_ROLE()
            )
        );
        pubRegistry.registerCustom("oldowner123", address(0x789), address(0x101), "https://oldowner.com");
    }
}

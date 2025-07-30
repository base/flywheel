pragma solidity 0.8.29;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {
    FlywheelPublisherRegistry,
    Unauthorized,
    RefCodeAlreadyTaken,
    OwnershipRenunciationDisabled,
    InvalidAddress
} from "../src/FlywheelPublisherRegistry.sol";
import {
    PublisherRegistered,
    UpdatePublisherDefaultPayoutAddress,
    UpdateMetadataUrl
} from "../src/FlywheelPublisherRegistry.sol";

contract FlywheelPublisherRegistryTest is Test {
    FlywheelPublisherRegistry public implementation;
    FlywheelPublisherRegistry public pubRegistry;
    ERC1967Proxy public proxy;

    address private owner = address(this);
    address private signer = address(0x123);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation
        implementation = new FlywheelPublisherRegistry();

        // Deploy proxy with signer address
        bytes memory initData = abi.encodeWithSelector(FlywheelPublisherRegistry.initialize.selector, owner, signer);
        proxy = new ERC1967Proxy(address(implementation), initData);

        // Create interface to proxy
        pubRegistry = FlywheelPublisherRegistry(address(proxy));

        vm.stopPrank();
    }

    function test_constructor() public {
        assertEq(pubRegistry.owner(), owner);
        assertTrue(pubRegistry.hasRole(implementation.SIGNER_ROLE(), signer));
    }

    function test_initializeWithZeroOwner() public {
        // Deploy fresh implementation
        FlywheelPublisherRegistry freshImpl = new FlywheelPublisherRegistry();

        // Try to initialize with zero owner
        bytes memory initData =
            abi.encodeWithSelector(FlywheelPublisherRegistry.initialize.selector, address(0), address(0));

        vm.expectRevert(InvalidAddress.selector);
        new ERC1967Proxy(address(freshImpl), initData);
    }

    function test_initializeWithZeroSigner() public {
        // Deploy fresh implementation
        FlywheelPublisherRegistry freshImpl = new FlywheelPublisherRegistry();

        // Initialize with zero signer (should be allowed)
        bytes memory initData = abi.encodeWithSelector(FlywheelPublisherRegistry.initialize.selector, owner, address(0));
        ERC1967Proxy freshProxy = new ERC1967Proxy(address(freshImpl), initData);
        FlywheelPublisherRegistry freshRegistry = FlywheelPublisherRegistry(address(freshProxy));

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

    function test_registerPublisherCustom_BySigner() public {
        string memory customRefCode = "custom123";
        address publisherOwner = address(0x789);
        string memory metadataUrl = "https://example.com";
        address defaultPayout = address(0x101);

        vm.startPrank(signer);

        // Expect the event before calling the function
        vm.expectEmit(true, true, true, true);
        emit PublisherRegistered(publisherOwner, defaultPayout, customRefCode, metadataUrl, true);

        pubRegistry.registerPublisherCustom(customRefCode, publisherOwner, metadataUrl, defaultPayout);

        vm.stopPrank();

        // Verify the publisher was registered
        (address registeredOwner, string memory registeredMetadataUrl, address registeredDefaultPayout) =
            pubRegistry.publishers(customRefCode);
        assertEq(registeredOwner, publisherOwner);
        assertEq(registeredMetadataUrl, metadataUrl);
        assertEq(registeredDefaultPayout, defaultPayout);
    }

    function test_registerPublisherCustom_ByOwner() public {
        string memory customRefCode = "owner123";
        address publisherOwner = address(0x789);
        string memory metadataUrl = "https://example.com";
        address defaultPayout = address(0x101);

        vm.startPrank(owner);

        pubRegistry.registerPublisherCustom(customRefCode, publisherOwner, metadataUrl, defaultPayout);

        vm.stopPrank();

        // Verify the publisher was registered
        (address registeredOwner,,) = pubRegistry.publishers(customRefCode);
        assertEq(registeredOwner, publisherOwner);
    }

    function test_registerPublisherCustom_Unauthorized() public {
        string memory customRefCode = "unauth123";
        address unauthorized = address(0x999);

        vm.startPrank(unauthorized);

        vm.expectRevert(Unauthorized.selector);
        pubRegistry.registerPublisherCustom(customRefCode, address(0x789), "https://example.com", address(0x101));

        vm.stopPrank();
    }

    function test_registerPublisherCustom_WithZeroSigner() public {
        // Deploy registry with zero signer
        FlywheelPublisherRegistry freshImpl = new FlywheelPublisherRegistry();
        bytes memory initData = abi.encodeWithSelector(FlywheelPublisherRegistry.initialize.selector, owner, address(0));
        ERC1967Proxy freshProxy = new ERC1967Proxy(address(freshImpl), initData);
        FlywheelPublisherRegistry freshRegistry = FlywheelPublisherRegistry(address(freshProxy));

        string memory customRefCode = "zero123";

        // Only owner should be able to call when signer is zero
        vm.startPrank(owner);
        freshRegistry.registerPublisherCustom(customRefCode, address(0x789), "https://example.com", address(0x101));
        vm.stopPrank();

        // Verify it worked
        (address registeredOwner,,) = freshRegistry.publishers(customRefCode);
        assertEq(registeredOwner, address(0x789));

        // Unauthorized address should fail
        vm.startPrank(address(0x999));
        vm.expectRevert(Unauthorized.selector);
        freshRegistry.registerPublisherCustom("fail123", address(0x789), "https://example.com", address(0x101));
        vm.stopPrank();
    }

    string private publisherMetadataUrl = "https://example.com";
    address private publisherOwner = address(0x6);
    address private defaultPayout = address(0x7);
    uint256 private optimismChainId = 10;
    address private optimismPayout = address(0x8);

    function registerDefaultPublisher() internal returns (string memory, uint256) {
        vm.startPrank(publisherOwner);
        (string memory refCode, uint256 publisherNonce) =
            pubRegistry.registerPublisher(publisherMetadataUrl, defaultPayout);
        vm.stopPrank();

        return (refCode, publisherNonce);
    }

    function test_registerPublisher() public {
        // Then execute the registration
        vm.startPrank(publisherOwner);
        (string memory refCode, uint256 publisherNonce) =
            pubRegistry.registerPublisher(publisherMetadataUrl, defaultPayout);
        vm.stopPrank();

        // Verify state changes
        (address _registeredOwner, string memory _registeredMetadataUrl, address _registeredDefaultPayout) =
            pubRegistry.publishers(refCode);

        assertTrue(_registeredOwner == publisherOwner, "owner mismatch");
        assertEq(_registeredMetadataUrl, publisherMetadataUrl, "metadata url mismatch");
        assertTrue(_registeredDefaultPayout == defaultPayout, "default payout mismatch");

        assertTrue(
            keccak256(abi.encode(refCode)) == keccak256(abi.encode(pubRegistry.getRefCode(publisherNonce))),
            "ref code mismatch"
        );
    }

    function test_updateMetadataUrl() public {
        (string memory refCode, uint256 publisherNonce) = registerDefaultPublisher();
        string memory newDimsUrl = "https://new.com";

        vm.startPrank(publisherOwner);

        // Expect the event before calling the function
        vm.expectEmit(true, true, true, true);
        emit UpdateMetadataUrl(refCode, newDimsUrl);

        pubRegistry.updateMetadataUrl(refCode, newDimsUrl);

        vm.stopPrank();

        (address _registeredOwner, string memory _registeredMetadataUrl, address _registeredDefaultPayout) =
            pubRegistry.publishers(refCode);

        assertEq(_registeredMetadataUrl, newDimsUrl, "metadata url mismatch");
    }

    function test_updatePublisherDefaultPayout() public {
        (string memory refCode, uint256 publisherNonce) = registerDefaultPublisher();
        address newDefaultPayout = address(0x999);

        vm.startPrank(publisherOwner);

        // Expect the event before calling the function
        vm.expectEmit(true, true, true, true);
        emit UpdatePublisherDefaultPayoutAddress(refCode, newDefaultPayout);

        pubRegistry.updatePublisherDefaultPayout(refCode, newDefaultPayout);

        vm.stopPrank();

        (address _registeredOwner, string memory _registeredMetadataUrl, address _registeredDefaultPayout) =
            pubRegistry.publishers(refCode);

        assertTrue(_registeredDefaultPayout == newDefaultPayout);

        // non-publisher cannot update default payout
        vm.startPrank(address(0x123));
        vm.expectRevert(Unauthorized.selector);
        pubRegistry.updatePublisherDefaultPayout(refCode, newDefaultPayout);
        vm.stopPrank();
    }

    function test_changePublisherOwner() public {
        (string memory refCode, uint256 publisherNonce) = registerDefaultPublisher();
        address newOwner = address(0x999);
        vm.startPrank(publisherOwner);

        pubRegistry.updatePublisherOwner(refCode, newOwner);

        (address _registeredOwner, string memory _registeredMetadataUrl, address _registeredDefaultPayout) =
            pubRegistry.publishers(refCode);

        vm.stopPrank();

        assertTrue(_registeredOwner == newOwner);

        // non-publisher cannot update owner
        vm.startPrank(address(0x123));
        vm.expectRevert(Unauthorized.selector);
        pubRegistry.updatePublisherOwner(refCode, newOwner);
        vm.stopPrank();
    }

    function test_getRefCode() public {
        registerDefaultPublisher();
        string memory refCode1 = pubRegistry.getRefCode(1);
        console.log("xxx ref code 1", refCode1);

        string memory refCode2 = pubRegistry.getRefCode(2);
        console.log("xxx ref code 2", refCode2);

        string memory refCode3 = pubRegistry.getRefCode(3);
        console.log("xxx ref code 3", refCode3);

        string memory refCode4333 = pubRegistry.getRefCode(4333);
        console.log("xxx ref code 4333", refCode4333);
    }

    function test_refCodeCollision() public {
        // These nonces are known to generate the first collision
        uint256 nonce1 = 2_397_017;
        uint256 nonce2 = 3_210_288;

        // Verify they actually generate the same ref code
        string memory refCode1 = pubRegistry.getRefCode(nonce1);
        string memory refCode2 = pubRegistry.getRefCode(nonce2);
        assertEq(refCode1, refCode2, "Test setup error: nonces should generate same ref code");
        console.log("xxx ref code 1", refCode1);
        console.log("xxx ref code 2", refCode2);

        // Force the nextPublisherNonce to be just before the first collision
        vm.store(
            address(pubRegistry),
            bytes32(uint256(1)), // slot 1 contains nextPublisherNonce
            bytes32(nonce1 - 1)
        );

        // Register first publisher - should get the ref code from nonce1
        vm.startPrank(publisherOwner);
        (string memory firstRefCode, uint256 firstNonce) = pubRegistry.registerPublisher("first.com", defaultPayout);

        // Register second publisher - should skip the collision and generate a new unique code
        (string memory secondRefCode, uint256 secondNonce) = pubRegistry.registerPublisher("second.com", defaultPayout);
        vm.stopPrank();

        console.log("xxx first registered ref code", firstRefCode);
        console.log("xxx second registered ref code", secondRefCode);

        // Verify we got different ref codes
        assertTrue(
            keccak256(abi.encode(firstRefCode)) != keccak256(abi.encode(secondRefCode)),
            "Should generate different ref codes"
        );

        assertEq(firstRefCode, pubRegistry.getRefCode(firstNonce), "First ref code mismatch");
        assertEq(secondRefCode, pubRegistry.getRefCode(secondNonce), "Second ref code mismatch");

        // Verify both publishers were registered with their respective ref codes
        (address owner1,,) = pubRegistry.publishers(firstRefCode);
        (address owner2,,) = pubRegistry.publishers(secondRefCode);

        assertEq(owner1, publisherOwner, "First publisher not registered correctly");
        assertEq(owner2, publisherOwner, "Second publisher not registered correctly");
    }

    function test_registerPublisherCustom() public {
        string memory customRefCode = "custom123";
        address customOwner = address(0x123);
        string memory customMetadataUrl = "https://custom.com";
        address customDefaultPayout = address(0x456);

        vm.startPrank(owner);

        // Expect events before calling the function
        vm.expectEmit(true, true, true, true);
        emit PublisherRegistered(customOwner, customDefaultPayout, customRefCode, customMetadataUrl, true);

        pubRegistry.registerPublisherCustom(customRefCode, customOwner, customMetadataUrl, customDefaultPayout);

        vm.stopPrank();

        (address registeredOwner, string memory registeredMetadataUrl, address registeredDefaultPayout) =
            pubRegistry.publishers(customRefCode);

        assertEq(registeredOwner, customOwner, "Custom owner mismatch");
        assertEq(registeredMetadataUrl, customMetadataUrl, "Custom metadata url mismatch");
        assertEq(registeredDefaultPayout, customDefaultPayout, "Custom default payout mismatch");
    }

    function test_registerPublisherCustom_RefCodeTaken() public {
        string memory customRefCode = "custom123";

        // Register first publisher
        vm.startPrank(owner);
        pubRegistry.registerPublisherCustom(customRefCode, address(0x123), "https://first.com", address(0x456));

        // Try to register second publisher with same ref code
        vm.expectRevert(RefCodeAlreadyTaken.selector);
        pubRegistry.registerPublisherCustom(customRefCode, address(0x789), "https://second.com", address(0x101));
        vm.stopPrank();
    }

    function test_updatePublisherOwner_Unauthorized() public {
        (string memory refCode,) = registerDefaultPublisher();
        address newOwner = address(0x999);

        // Try to update owner from unauthorized address
        vm.startPrank(address(0x123));
        vm.expectRevert(Unauthorized.selector);
        pubRegistry.updatePublisherOwner(refCode, newOwner);
        vm.stopPrank();
    }

    function test_updatePublisherOwner_NewOwnerCanUpdate() public {
        (string memory refCode,) = registerDefaultPublisher();
        address newOwner = address(0x999);

        // Current owner updates to new owner
        vm.startPrank(publisherOwner);
        pubRegistry.updatePublisherOwner(refCode, newOwner);
        vm.stopPrank();

        // Verify new owner can make updates
        vm.startPrank(newOwner);
        string memory newMetadataUrl = "https://newowner.com";
        pubRegistry.updateMetadataUrl(refCode, newMetadataUrl);
        vm.stopPrank();

        // Verify old owner cannot make updates
        vm.startPrank(publisherOwner);
        vm.expectRevert(Unauthorized.selector);
        pubRegistry.updateMetadataUrl(refCode, "https://oldowner.com");
        vm.stopPrank();

        // Verify metadata was updated by new owner
        (, string memory registeredMetadataUrl,) = pubRegistry.publishers(refCode);
        assertEq(registeredMetadataUrl, newMetadataUrl, "New owner's update failed");
    }

    function test_updatePublisherOwner_RevertOnZeroAddress() public {
        (string memory refCode,) = registerDefaultPublisher();

        // Try to update owner to address(0)
        vm.startPrank(publisherOwner);
        vm.expectRevert(InvalidAddress.selector);
        pubRegistry.updatePublisherOwner(refCode, address(0));
        vm.stopPrank();
    }

    function test_getPublisherPayoutAddress() public {
        (string memory refCode,) = registerDefaultPublisher();

        address payoutAddress = pubRegistry.getPublisherPayoutAddress(refCode);
        assertEq(payoutAddress, defaultPayout, "Should return default payout address");
    }

    // Tests for missing coverage lines

    /// @notice Test renounceOwnership function should revert
    function test_renounceOwnership_shouldRevert() public {
        vm.prank(owner);
        vm.expectRevert(OwnershipRenunciationDisabled.selector);
        pubRegistry.renounceOwnership();
    }

    /// @notice Test return statement in _generateUniqueRefCode with no collision
    function test_generateUniqueRefCode_firstTrySuccess() public {
        // This tests the return statement on line 250 when no collision occurs
        // Register a publisher, which calls _generateUniqueRefCode internally
        vm.startPrank(publisherOwner);
        (string memory refCode, uint256 publisherNonce) =
            pubRegistry.registerPublisher(publisherMetadataUrl, defaultPayout);
        vm.stopPrank();

        // Verify the ref code was generated correctly
        assertEq(refCode, pubRegistry.getRefCode(publisherNonce), "Ref code should match generated nonce");

        // Verify publisher was registered with the generated ref code
        (address registeredOwner,,) = pubRegistry.publishers(refCode);
        assertEq(registeredOwner, publisherOwner, "Publisher should be registered with generated ref code");
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
        pubRegistry.registerPublisherCustom("newowner123", address(0x789), "https://newowner.com", address(0x101));

        // Verify custom publisher was registered
        (address registeredOwner,,) = pubRegistry.publishers("newowner123");
        assertEq(registeredOwner, address(0x789), "Custom publisher should be registered by new owner");
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
        vm.expectRevert(Unauthorized.selector);
        pubRegistry.registerPublisherCustom("oldowner123", address(0x789), "https://oldowner.com", address(0x101));
    }
}

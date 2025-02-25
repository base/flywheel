pragma solidity 0.8.28;

import "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { FlywheelPublisherRegistry, Unauthorized, RefCodeAlreadyTaken } from "../src/FlywheelPublisherRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { PublisherRegistered, UpdatePublisherChainPayoutAddress, UpdatePublisherDefaultPayoutAddress, UpdateMetadataUrl } from "../src/FlywheelPublisherRegistry.sol";

contract FlywheelPublisherRegistryTest is Test {
  FlywheelPublisherRegistry public implementation;
  FlywheelPublisherRegistry public pubRegistry;
  ERC1967Proxy public proxy;

  address private owner = address(this);

  function setUp() public {
    vm.startPrank(owner);

    // Deploy implementation
    implementation = new FlywheelPublisherRegistry();

    // Deploy proxy
    bytes memory initData = abi.encodeWithSelector(FlywheelPublisherRegistry.initialize.selector, owner);
    proxy = new ERC1967Proxy(address(implementation), initData);

    // Create interface to proxy
    pubRegistry = FlywheelPublisherRegistry(address(proxy));

    vm.stopPrank();
  }

  function test_constructor() public {
    assertEq(pubRegistry.owner(), owner);
  }

  string private publisherMetadataUrl = "https://example.com";
  address private publisherOwner = address(0x6);
  address private defaultPayout = address(0x7);
  uint256 private optimismChainId = 10;
  address private optimismPayout = address(0x8);

  function registerDefaultPublisher() internal returns (string memory, uint256) {
    FlywheelPublisherRegistry.OverridePublisherPayout[]
      memory overridePayouts = new FlywheelPublisherRegistry.OverridePublisherPayout[](1);

    overridePayouts[0] = FlywheelPublisherRegistry.OverridePublisherPayout(optimismChainId, optimismPayout);

    vm.startPrank(publisherOwner);
    (string memory refCode, uint256 publisherNonce) = pubRegistry.registerPublisher(
      publisherMetadataUrl,
      defaultPayout,
      overridePayouts
    );
    vm.stopPrank();

    return (refCode, publisherNonce);
  }

  function test_registerPublisher() public {
    FlywheelPublisherRegistry.OverridePublisherPayout[]
      memory overridePayouts = new FlywheelPublisherRegistry.OverridePublisherPayout[](1);

    overridePayouts[0] = FlywheelPublisherRegistry.OverridePublisherPayout(optimismChainId, optimismPayout);

    // Then execute the registration
    vm.startPrank(publisherOwner);
    (string memory refCode, uint256 publisherNonce) = pubRegistry.registerPublisher(
      publisherMetadataUrl,
      defaultPayout,
      overridePayouts
    );
    vm.stopPrank();

    // Verify state changes
    (address _registeredOwner, string memory _registeredMetadataUrl, address _registeredDefaultPayout) = pubRegistry
      .publishers(refCode);

    assertTrue(_registeredOwner == publisherOwner, "owner mismatch");
    assertEq(_registeredMetadataUrl, publisherMetadataUrl, "metadata url mismatch");
    assertTrue(_registeredDefaultPayout == defaultPayout, "default payout mismatch");

    assertTrue(
      keccak256(abi.encode(refCode)) == keccak256(abi.encode(pubRegistry.getRefCode(publisherNonce))),
      "ref code mismatch"
    );
    assertTrue(
      pubRegistry.getPublisherOverridePayout(refCode, optimismChainId) == optimismPayout,
      "override payout mismatch"
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

    (address _registeredOwner, string memory _registeredMetadataUrl, address _registeredDefaultPayout) = pubRegistry
      .publishers(refCode);

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

    (address _registeredOwner, string memory _registeredMetadataUrl, address _registeredDefaultPayout) = pubRegistry
      .publishers(refCode);

    assertTrue(_registeredDefaultPayout == newDefaultPayout);

    // non-publisher cannot update default payout
    vm.startPrank(address(0x123));
    vm.expectRevert(Unauthorized.selector);
    pubRegistry.updatePublisherDefaultPayout(refCode, newDefaultPayout);
    vm.stopPrank();
  }

  function test_updateOverridePayout() public {
    (string memory refCode, uint256 publisherNonce) = registerDefaultPublisher();
    address newOverridePayout = address(0x999);

    vm.startPrank(publisherOwner);

    // Expect the event before calling the function
    vm.expectEmit(true, true, true, true);
    emit UpdatePublisherChainPayoutAddress(refCode, optimismChainId, newOverridePayout);

    pubRegistry.updatePublisherOverridePayout(refCode, optimismChainId, newOverridePayout);

    vm.stopPrank();

    // Existing state check
    assertTrue(pubRegistry.getPublisherOverridePayout(refCode, optimismChainId) == newOverridePayout);

    // non-publisher cannot update default payout
    vm.startPrank(address(0x123));
    vm.expectRevert(Unauthorized.selector);
    pubRegistry.updatePublisherOverridePayout(refCode, optimismChainId, newOverridePayout);
    vm.stopPrank();
  }

  function test_changePublisherOwner() public {
    (string memory refCode, uint256 publisherNonce) = registerDefaultPublisher();
    address newOwner = address(0x999);
    vm.startPrank(publisherOwner);

    pubRegistry.updatePublisherOwner(refCode, newOwner);

    (address _registeredOwner, string memory _registeredMetadataUrl, address _registeredDefaultPayout) = pubRegistry
      .publishers(refCode);

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
    FlywheelPublisherRegistry.OverridePublisherPayout[]
      memory overridePayouts = new FlywheelPublisherRegistry.OverridePublisherPayout[](0);

    vm.startPrank(publisherOwner);
    (string memory firstRefCode, uint256 firstNonce) = pubRegistry.registerPublisher(
      "first.com",
      defaultPayout,
      overridePayouts
    );

    // Register second publisher - should skip the collision and generate a new unique code
    (string memory secondRefCode, uint256 secondNonce) = pubRegistry.registerPublisher(
      "second.com",
      defaultPayout,
      overridePayouts
    );
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
    (address owner1, , ) = pubRegistry.publishers(firstRefCode);
    (address owner2, , ) = pubRegistry.publishers(secondRefCode);

    assertEq(owner1, publisherOwner, "First publisher not registered correctly");
    assertEq(owner2, publisherOwner, "Second publisher not registered correctly");
  }

  function test_registerPublisherCustom() public {
    string memory customRefCode = "custom123";
    address customOwner = address(0x123);
    string memory customMetadataUrl = "https://custom.com";
    address customDefaultPayout = address(0x456);

    FlywheelPublisherRegistry.OverridePublisherPayout[]
      memory overridePayouts = new FlywheelPublisherRegistry.OverridePublisherPayout[](1);
    overridePayouts[0] = FlywheelPublisherRegistry.OverridePublisherPayout(optimismChainId, optimismPayout);

    vm.startPrank(owner);

    // Expect events before calling the function
    vm.expectEmit(true, true, true, true);
    emit PublisherRegistered(customOwner, customDefaultPayout, customRefCode, customMetadataUrl, true);

    pubRegistry.registerPublisherCustom(
      customRefCode,
      customOwner,
      customMetadataUrl,
      customDefaultPayout,
      overridePayouts
    );

    vm.stopPrank();

    (address registeredOwner, string memory registeredMetadataUrl, address registeredDefaultPayout) = pubRegistry
      .publishers(customRefCode);

    assertEq(registeredOwner, customOwner, "Custom owner mismatch");
    assertEq(registeredMetadataUrl, customMetadataUrl, "Custom metadata url mismatch");
    assertEq(registeredDefaultPayout, customDefaultPayout, "Custom default payout mismatch");
    assertEq(
      pubRegistry.getPublisherOverridePayout(customRefCode, optimismChainId),
      optimismPayout,
      "Custom override payout mismatch"
    );
  }

  function test_registerPublisherCustom_RefCodeTaken() public {
    string memory customRefCode = "custom123";

    // Register first publisher
    vm.startPrank(owner);
    pubRegistry.registerPublisherCustom(
      customRefCode,
      address(0x123),
      "https://first.com",
      address(0x456),
      new FlywheelPublisherRegistry.OverridePublisherPayout[](0)
    );

    // Try to register second publisher with same ref code
    vm.expectRevert(RefCodeAlreadyTaken.selector);
    pubRegistry.registerPublisherCustom(
      customRefCode,
      address(0x789),
      "https://second.com",
      address(0x101),
      new FlywheelPublisherRegistry.OverridePublisherPayout[](0)
    );
    vm.stopPrank();
  }

  function test_updatePublisherOwner_Unauthorized() public {
    (string memory refCode, ) = registerDefaultPublisher();
    address newOwner = address(0x999);

    // Try to update owner from unauthorized address
    vm.startPrank(address(0x123));
    vm.expectRevert(Unauthorized.selector);
    pubRegistry.updatePublisherOwner(refCode, newOwner);
    vm.stopPrank();
  }

  function test_updatePublisherOwner_NewOwnerCanUpdate() public {
    (string memory refCode, ) = registerDefaultPublisher();
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
    (, string memory registeredMetadataUrl, ) = pubRegistry.publishers(refCode);
    assertEq(registeredMetadataUrl, newMetadataUrl, "New owner's update failed");
  }
}

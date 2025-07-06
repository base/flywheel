// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { FlywheelCampaigns } from "../../src/archive/FlywheelCampaigns.sol";
import { IFlywheelCampaigns } from "../../src/archive/interfaces/IFlywheelCampaigns.sol";
import { DummyERC20 } from "../../src/archive/test/DummyERC20.sol";
import { CampaignBalance } from "../../src/archive/CampaignBalance.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { FlywheelPublisherRegistry } from "../../src/FlywheelPublisherRegistry.sol";
import { Flywheel } from "../../src/Flywheel.sol";
import { AdvertisementConversion } from "../../src/hooks/AdvertisementConversion.sol";

contract GasBenchmarkTest is Test {
  FlywheelCampaigns implementation;
  FlywheelCampaigns fwCampaigns;
  DummyERC20 dummyToken;
  FlywheelPublisherRegistry publisherRegistryImplementation;
  FlywheelPublisherRegistry publisherRegistry;
  Flywheel flywheel;
  AdvertisementConversion hook;
  address campaign;

  address private owner = address(this);
  address private treasury = address(0x3);
  address private advertiser = address(0x4);
  address private spdApOwner = address(0x5);
  address private spdApSigner = address(0x6);
  address private attributor = address(0x7);
  uint256 private spdApId = 1;
  uint256 private totalFunded = 1000000 * 10 ** 18;
  string[] private emptyPubAllowlist = new string[](0);

  // Default publisher addresses and ref codes
  address private publisher1Address = address(0x123);
  address private publisher2Address = address(0x456);
  address private publisher3Address = address(0x789);
  string private publisher1RefCode = "TEST123";
  string private publisher2RefCode = "TEST456";
  string private publisher3RefCode = "TEST789";

  address private publisherOwner = address(0x111);

  address private campaignBalanceAddress;
  uint256 private campaignId;
  string private campaignMetadataUrl = "https://example.com/campaign/metadata";

  function setUp() public {
    // Setup token
    address[] memory initialHolders = new address[](2);
    initialHolders[0] = owner;
    initialHolders[1] = advertiser;
    dummyToken = new DummyERC20(initialHolders);

    address[] memory allowedTokenAddresses = new address[](1);
    allowedTokenAddresses[0] = address(dummyToken);

    IFlywheelCampaigns.AttributionProvider[] memory providers = new IFlywheelCampaigns.AttributionProvider[](1);
    providers[0] = IFlywheelCampaigns.AttributionProvider({ ownerAddress: spdApOwner, signerAddress: spdApSigner });

    // Deploy publisher registry implementation
    publisherRegistryImplementation = new FlywheelPublisherRegistry();

    // Deploy publisher registry proxy
    bytes memory publisherRegistryInitData = abi.encodeCall(FlywheelPublisherRegistry.initialize, (owner, address(0)));

    ERC1967Proxy publisherRegistryProxy = new ERC1967Proxy(
      address(publisherRegistryImplementation),
      publisherRegistryInitData
    );
    publisherRegistry = FlywheelPublisherRegistry(address(publisherRegistryProxy));

    // Assert that the test contract is the owner of the proxy
    assertEq(publisherRegistry.owner(), address(this), "Test contract is not the owner of the registry proxy");

    // Register publishers
    FlywheelPublisherRegistry.OverridePublisherPayout[]
      memory overridePayouts = new FlywheelPublisherRegistry.OverridePublisherPayout[](0);
    publisherRegistry.registerPublisherCustom(
      publisher1RefCode,
      publisherOwner,
      "https://example.com",
      publisher1Address,
      overridePayouts
    );
    publisherRegistry.registerPublisherCustom(
      publisher2RefCode,
      publisherOwner,
      "https://example.com",
      publisher2Address,
      overridePayouts
    );
    publisherRegistry.registerPublisherCustom(
      publisher3RefCode,
      publisherOwner,
      "https://example.com",
      publisher3Address,
      overridePayouts
    );

    // Deploy implementation and proxy
    implementation = new FlywheelCampaigns();
    bytes memory initData = abi.encodeCall(
      FlywheelCampaigns.initialize,
      (owner, treasury, allowedTokenAddresses, providers, address(publisherRegistry))
    );
    ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);
    fwCampaigns = FlywheelCampaigns(address(proxyContract));

    // Create and fund campaign
    vm.startPrank(advertiser);
    FlywheelCampaigns.ConversionConfigInput[] memory conversionEvents = new FlywheelCampaigns.ConversionConfigInput[](
      2
    );
    conversionEvents[0] = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.OFFCHAIN,
      eventName: "click",
      conversionMetadataUrl: "https://example.com",
      publisherBidValue: 100,
      userBidValue: 0,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE,
      cadenceType: IFlywheelCampaigns.CadenceEventType.ONE_TIME
    });
    conversionEvents[1] = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.ONCHAIN,
      eventName: "stake",
      conversionMetadataUrl: "https://example.com",
      publisherBidValue: 100,
      userBidValue: 0,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE,
      cadenceType: IFlywheelCampaigns.CadenceEventType.ONE_TIME
    });

    (campaignId, campaignBalanceAddress, ) = fwCampaigns.createCampaign(
      address(dummyToken),
      spdApId,
      true,
      campaignMetadataUrl,
      conversionEvents,
      emptyPubAllowlist
    );

    dummyToken.transfer(campaignBalanceAddress, totalFunded);
    vm.stopPrank();

    // Activate campaign
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    // NEW //

    // Deploy Flywheel
    flywheel = new Flywheel();

    // Deploy hook
    hook = new AdvertisementConversion(address(flywheel), address(this));

    // Create campaign
    initData = ""; // Empty init data for this test
    vm.prank(advertiser);
    campaign = flywheel.createCampaign(attributor, address(hook), initData);
    dummyToken.transfer(campaign, totalFunded);

    // Only attributor can open the campaign, and only once
    vm.prank(attributor);
    flywheel.openCampaign(campaign);
  }

  function test_benchmark_100_offchain_events() public {
    vm.startPrank(spdApSigner);
    FlywheelCampaigns.OffchainEvent[] memory events = new FlywheelCampaigns.OffchainEvent[](100);

    for (uint256 i = 0; i < 100; i++) {
      events[i] = IFlywheelCampaigns.OffchainEvent({
        conversionConfigId: 1,
        eventId: bytes16(0x1234567890abcdef1234567890abcdef),
        payoutAddress: address(0), // Unique addresses
        payoutAmount: 1000 * 10 ** 18,
        recipientType: 1,
        publisherRefCode: publisher1RefCode,
        clickId: string(abi.encodePacked("CLICK", uint8(i))),
        timestamp: uint32(1734565000 + i)
      });
    }

    uint256 gasBefore = gasleft();
    fwCampaigns.attributeOffchainEvents(campaignId, events);
    uint256 gasUsed = gasBefore - gasleft();
    _reportCosts("100 Offchain Events", gasUsed);

    vm.stopPrank();
  }

  function test_benchmark_100_offchain_events_NEW() public {
    AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](100);

    AdvertisementConversion.Conversion memory conversion = AdvertisementConversion.Conversion({
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      clickId: "click",
      conversionConfigId: 1,
      publisherRefCode: publisher1RefCode,
      timestamp: uint32(block.timestamp),
      recipientType: 1
    });

    Flywheel.Payout memory payout = Flywheel.Payout({
      recipient: address(0),
      amount: 1000e18 // 100 tokens
    });

    for (uint256 i = 0; i < 100; i++) {
      attributions[i] = AdvertisementConversion.Attribution({
        payout: payout,
        conversion: conversion,
        logBytes: "" // Empty for offchain
      });
    }

    uint256 gasBefore = gasleft();
    vm.prank(attributor);
    flywheel.attribute(campaign, address(dummyToken), abi.encode(attributions));
    uint256 gasUsed = gasBefore - gasleft();
    _reportCosts("100 Offchain Events NEW", gasUsed);
  }

  function test_benchmark_100_onchain_events() public {
    uint256 gasBefore = gasleft();

    vm.startPrank(spdApSigner);
    FlywheelCampaigns.OnchainEvent[] memory events = new FlywheelCampaigns.OnchainEvent[](100);

    bytes32[100] memory txHashes = _generateRealisticTxHashes();

    for (uint256 i = 0; i < 100; i++) {
      events[i] = IFlywheelCampaigns.OnchainEvent({
        conversionConfigId: 2,
        eventId: bytes16(0x1234567890abcdef1234567890abcdef),
        payoutAddress: address(0), // Unique addresses
        payoutAmount: 1000 * 10 ** 18,
        recipientType: 1,
        publisherRefCode: publisher1RefCode,
        clickId: string(abi.encodePacked("CLICK", uint8(i))),
        userAddress: address(0x999),
        timestamp: uint32(1734565000 + i),
        txHash: txHashes[i],
        txChainId: 1,
        txEventLogIndex: i
      });
    }

    fwCampaigns.attributeOnchainEvents(campaignId, events);
    uint256 gasUsed = gasBefore - gasleft();
    _reportCosts("100 Onchain Events", gasUsed);

    vm.stopPrank();
  }

  function test_benchmark_100_onchain_events_NEW() public {
    AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](100);

    AdvertisementConversion.Conversion memory conversion = AdvertisementConversion.Conversion({
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      clickId: "click",
      conversionConfigId: 1,
      publisherRefCode: publisher1RefCode,
      timestamp: uint32(block.timestamp),
      recipientType: 1
    });

    Flywheel.Payout memory payout = Flywheel.Payout({
      recipient: address(0),
      amount: 1000e18 // 100 tokens
    });

    bytes32[100] memory txHashes = _generateRealisticTxHashes();
    AdvertisementConversion.Log memory log = AdvertisementConversion.Log({
      chainId: 1,
      transactionHash: txHashes[0],
      index: 0
    });

    for (uint256 i = 0; i < 100; i++) {
      attributions[i] = AdvertisementConversion.Attribution({
        payout: payout,
        conversion: conversion,
        logBytes: abi.encode(log)
      });
    }

    uint256 gasBefore = gasleft();
    vm.prank(attributor);
    flywheel.attribute(campaign, address(dummyToken), abi.encode(attributions));
    uint256 gasUsed = gasBefore - gasleft();
    _reportCosts("100 Onchain Events NEW", gasUsed);
  }

  function _generateRealisticTxHashes() internal pure returns (bytes32[100] memory hashes) {
    // Some example realistic base transaction prefixes
    bytes32[5] memory prefixes = [
      bytes32(0xf07a373683523d00bfb5c356bb3cfaa66d4a99fa562a7ea9a00adf7f887ecdac),
      bytes32(0xe31c0ed5ee04f6b0c1c3457cefa304c78bf0e7aca77c485e7a219311b2f0a679),
      bytes32(0xd29c5cbd3069ea0eb1c9f3c85f89623e98aff85b1e45c69ac4c8ebf28226d9ab),
      bytes32(0xc18d9122d893ab664d82105c1f430288d511c35b758869bd5100e7a7679c2789),
      bytes32(0xb27d4c15dd4a8cf59a544bfe45bb4c7447c54f0b0e1c6a7c864641e71b8a1567)
    ];

    for (uint256 i = 0; i < 100; i++) {
      // Use a prefix and modify last few bytes to create unique but realistic looking hashes
      bytes32 baseHash = prefixes[i % 5];
      bytes32 uniqueHash = bytes32(uint256(baseHash) ^ (i + 1));
      hashes[i] = uniqueHash;
    }

    return hashes;
  }

  function _reportCosts(string memory testName, uint256 gasUsed) internal view {
    // Current network gas prices (in wei)
    uint256 baseGasPrice = 0.0349 * 1e9; // 0.0349 gwei = 34900000 wei
    uint256 optimismGasPrice = 0.001 * 1e9; // 0.001 gwei = 1000000 wei
    uint256 arbitrumGasPrice = 0.043 * 1e9; // 0.043 gwei = 4300000 wei

    // Current ETH price in USD (with 18 decimals for precision)
    uint256 ethPrice = 3200 * 1e18; // $3,200 per ETH

    // Calculate costs in ETH (wei)
    uint256 baseCostWei = gasUsed * baseGasPrice;
    uint256 optimismCostWei = gasUsed * optimismGasPrice;
    uint256 arbitrumCostWei = gasUsed * arbitrumGasPrice;

    // Convert to USD with proper decimal handling
    uint256 baseUSD = (baseCostWei * ethPrice) / (1e18 * 1e18);
    uint256 optimismUSD = (optimismCostWei * ethPrice) / (1e18 * 1e18);
    uint256 arbitrumUSD = (arbitrumCostWei * ethPrice) / (1e18 * 1e18);

    console.log("=== Cost Report for:", testName, "===");
    console.log("Gas Used:", gasUsed);
    console.log("Base Cost: $%s.%s", baseUSD, _formatDecimals(baseCostWei * ethPrice, 36));
    console.log("Optimism Cost: $%s.%s", optimismUSD, _formatDecimals(optimismCostWei * ethPrice, 36));
    console.log("Arbitrum Cost: $%s.%s", arbitrumUSD, _formatDecimals(arbitrumCostWei * ethPrice, 36));
    console.log("=====================================");
  }

  // Helper function to format decimals
  function _formatDecimals(uint256 value, uint256 maybePrecision) internal pure returns (string memory) {
    uint256 precision = maybePrecision > 0 ? maybePrecision : 18;
    if (value == 0) return "00";

    uint256 decimalPart = value % (1 * 10 ** precision);
    string memory result = "";

    // Convert to 2 decimal places
    decimalPart = (decimalPart * 100) / (10 ** precision);

    // Ensure we always show 2 decimal places
    if (decimalPart < 10) {
      result = string(abi.encodePacked("0", vm.toString(decimalPart)));
    } else {
      result = vm.toString(decimalPart);
    }

    return result;
  }
}

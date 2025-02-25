// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { console } from "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";
import { FlywheelCampaigns } from "../src/FlywheelCampaigns.sol";
import { IFlywheelCampaigns } from "../src/interfaces/IFlywheelCampaigns.sol";
import { DummyERC20 } from "../src/test/DummyERC20.sol";
import { CampaignBalance } from "../src/CampaignBalance.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GasBenchmarkTest is Test {
  FlywheelCampaigns implementation;
  FlywheelCampaigns fwCampaigns;
  DummyERC20 dummyToken;

  address private owner = address(this);
  address private treasury = address(0x3);
  address private advertiser = address(0x4);
  address private spdApOwner = address(0x5);
  address private spdApSigner = address(0x6);
  uint256 private spdApId = 1;
  uint256 private totalFunded = 1000000 * 10 ** 18;
  string[] private emptyPubAllowlist = new string[](0);

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

    // Deploy implementation and proxy
    implementation = new FlywheelCampaigns();
    bytes memory initData = abi.encodeCall(
      FlywheelCampaigns.initialize,
      (owner, treasury, allowedTokenAddresses, providers)
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
  }

  function test_benchmark_100_offchain_events() public {
    uint256 gasBefore = gasleft();

    vm.startPrank(spdApSigner);
    FlywheelCampaigns.OffchainEvent[] memory events = new FlywheelCampaigns.OffchainEvent[](100);

    for (uint i = 0; i < 100; i++) {
      events[i] = IFlywheelCampaigns.OffchainEvent({
        conversionConfigId: 1,
        eventId: bytes16(0x1234567890abcdef1234567890abcdef),
        payoutAddress: address(uint160(0x1000 + i)), // Unique addresses
        payoutAmount: 1000 * 10 ** 18,
        recipientType: 1,
        publisherRefCode: string(abi.encodePacked("PUB", uint8(i))),
        clickId: string(abi.encodePacked("CLICK", uint8(i))),
        timestamp: uint32(1734565000 + i)
      });
    }

    fwCampaigns.attributeOffchainEvents(campaignId, events);
    vm.stopPrank();

    uint256 gasUsed = gasBefore - gasleft();
    _reportCosts("100 Offchain Events", gasUsed);
  }

  function test_benchmark_100_onchain_events() public {
    uint256 gasBefore = gasleft();

    vm.startPrank(spdApSigner);
    FlywheelCampaigns.OnchainEvent[] memory events = new FlywheelCampaigns.OnchainEvent[](100);

    bytes32[100] memory txHashes = _generateRealisticTxHashes();

    for (uint i = 0; i < 100; i++) {
      events[i] = IFlywheelCampaigns.OnchainEvent({
        conversionConfigId: 2,
        eventId: bytes16(0x1234567890abcdef1234567890abcdef),
        payoutAddress: address(uint160(0x1000 + i)), // Unique addresses
        payoutAmount: 1000 * 10 ** 18,
        recipientType: 1,
        publisherRefCode: string(abi.encodePacked("PUB", uint8(i))),
        clickId: string(abi.encodePacked("CLICK", uint8(i))),
        userAddress: address(0x999),
        timestamp: uint32(1734565000 + i),
        txHash: txHashes[i],
        txChainId: 1,
        txEventLogIndex: i
      });
    }

    fwCampaigns.attributeOnchainEvents(campaignId, events);
    vm.stopPrank();

    uint256 gasUsed = gasBefore - gasleft();
    _reportCosts("100 Onchain Events", gasUsed);
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

    for (uint i = 0; i < 100; i++) {
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

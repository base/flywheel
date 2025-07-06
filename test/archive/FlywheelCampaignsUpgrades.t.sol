pragma solidity 0.8.29;

import "forge-std/console.sol";
import { FlywheelCampaigns } from "../../src/archive/FlywheelCampaigns.sol";
import { IFlywheelCampaigns } from "../../src/archive/interfaces/IFlywheelCampaigns.sol";
import { Test } from "forge-std/Test.sol";
import { DummyERC20 } from "../../src/archive/test/DummyERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { FlywheelCampaignsV2 } from "../../src/archive/test/DummyUpgrades.sol";
import { FlywheelPublisherRegistry } from "../../src/archive/FlywheelPublisherRegistry.sol";
import { FlywheelPublisherRegistryV2 } from "../../src/archive/test/DummyUpgrades.sol";

contract FlywheelCampaignsUpgradesTest is Test {
  FlywheelCampaigns implementation;
  FlywheelCampaigns fwCampaigns;
  DummyERC20 dummyToken;
  FlywheelPublisherRegistry publisherRegistryImplementation;
  FlywheelPublisherRegistry publisherRegistry;
  FlywheelPublisherRegistryV2 publisherRegistryV2;

  address private owner = address(this);
  address private treasury = address(0x3);
  address private advertiser = address(0x4);
  address private spdApOwner = address(0x5); // attribution provider owner
  address private spdApSigner = address(0x6); // attribution provider signer
  string[] private emptyPubAllowlist1 = new string[](0);

  uint256 private spdApId = 1;
  uint256 private campaignId1;
  FlywheelCampaignsV2 public implementationV2;

  string private campaignMetadataUrl1 = "https://example.com/campaign/metadata";

  function setUp() public {
    vm.startPrank(owner);
    address[] memory initialHolders = new address[](2);
    initialHolders[0] = owner;
    initialHolders[1] = advertiser;
    dummyToken = new DummyERC20(initialHolders);

    address[] memory allowedTokenAddresses = new address[](1);
    allowedTokenAddresses[0] = address(dummyToken);

    FlywheelCampaigns.AttributionProvider[] memory providers = new FlywheelCampaigns.AttributionProvider[](1);
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

    // Deploy implementation
    implementation = new FlywheelCampaigns();

    // Deploy proxy
    bytes memory initData = abi.encodeCall(
      FlywheelCampaigns.initialize,
      (owner, treasury, allowedTokenAddresses, providers, address(publisherRegistry))
    );

    ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);

    // Get interface of implementation at proxy address
    fwCampaigns = FlywheelCampaigns(address(proxyContract));

    // Create a campaign to test state preservation
    FlywheelCampaigns.ConversionConfigInput[] memory conversionConfigs = new FlywheelCampaigns.ConversionConfigInput[](
      1
    );
    conversionConfigs[0] = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.OFFCHAIN,
      eventName: "TestEvent",
      conversionMetadataUrl: "https://example.com",
      publisherBidValue: 1000,
      userBidValue: 0,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE,
      cadenceType: IFlywheelCampaigns.CadenceEventType.ONE_TIME
    });

    (campaignId1, , ) = fwCampaigns.createCampaign(
      address(dummyToken),
      spdApId,
      true,
      campaignMetadataUrl1,
      conversionConfigs,
      emptyPubAllowlist1
    );

    // Deploy V2 implementations
    implementationV2 = new FlywheelCampaignsV2();
    publisherRegistryV2 = new FlywheelPublisherRegistryV2();

    vm.stopPrank();
  }

  function test_basic_upgrade() public {
    address originalFwCampaigns = address(fwCampaigns);
    address originalPublisherRegistry = address(publisherRegistry);

    // Store initial state to verify after upgrade
    address initialOwner = fwCampaigns.owner();
    address initialTreasury = fwCampaigns.treasuryAddress();
    address initialPublisherRegistry = fwCampaigns.publisherRegistryAddress();

    // Get initial campaign info
    (
      FlywheelCampaigns.CampaignStatus status,
      address campaignBalanceAddress,
      address tokenAddress,
      uint256 attributionProviderId,
      address manager,
      uint256 conversionEventCount,
      string memory campaignMetadataUrl,
      uint256 totalAmountClaimed,
      uint256 totalAmountAllocated,
      uint256 protocolFeesBalance,
      bool isAllowlistSet
    ) = fwCampaigns.campaigns(campaignId1);

    vm.startPrank(owner);
    // Perform upgrades
    UUPSUpgradeable(address(fwCampaigns)).upgradeToAndCall(address(implementationV2), "");
    UUPSUpgradeable(address(publisherRegistry)).upgradeToAndCall(address(publisherRegistryV2), "");

    // Cast to V2 to access new functionality
    FlywheelCampaignsV2 fwCampaignsV2 = FlywheelCampaignsV2(address(fwCampaigns));
    FlywheelPublisherRegistryV2 publisherRegistryV2Instance = FlywheelPublisherRegistryV2(address(publisherRegistry));

    // Test new V2 functionality
    assertEq(fwCampaignsV2.totalCampaignsCreated(), 0, "Initial total campaigns should be 0");
    assertEq(publisherRegistryV2Instance.totalPublishersCreated(), 0, "Initial total publishers should be 0");

    fwCampaignsV2.incrementTotalCampaigns();
    publisherRegistryV2Instance.incrementTotalPublishers();

    assertEq(fwCampaignsV2.totalCampaignsCreated(), 1, "Should be able to increment campaigns");
    assertEq(publisherRegistryV2Instance.totalPublishersCreated(), 1, "Should be able to increment publishers");

    vm.stopPrank();

    // Verify core state was preserved after upgrade
    assertEq(fwCampaigns.owner(), initialOwner, "Owner should be preserved after upgrade");
    assertEq(fwCampaigns.treasuryAddress(), initialTreasury, "Treasury should be preserved after upgrade");
    assertEq(
      fwCampaigns.publisherRegistryAddress(),
      initialPublisherRegistry,
      "Publisher registry should be preserved after upgrade"
    );

    // Verify campaign state was preserved
    (
      FlywheelCampaigns.CampaignStatus statusAfter,
      address campaignBalanceAddressAfter,
      address tokenAddressAfter,
      uint256 attributionProviderIdAfter,
      address managerAfter,
      uint256 conversionEventCountAfter,
      string memory campaignMetadataUrlAfter,
      uint256 totalAmountClaimedAfter,
      uint256 totalAmountAllocatedAfter,
      uint256 protocolFeesBalanceAfter,
      bool isAllowlistSetAfter
    ) = fwCampaigns.campaigns(campaignId1);

    assertEq(uint8(statusAfter), uint8(status), "Campaign status should be preserved");
    assertEq(campaignBalanceAddressAfter, campaignBalanceAddress, "Balance location should be preserved");
    assertEq(tokenAddressAfter, tokenAddress, "Token address should be preserved");
    assertEq(totalAmountClaimedAfter, totalAmountClaimed, "Total amount claimed should be preserved");
    assertEq(totalAmountAllocatedAfter, totalAmountAllocated, "Total amount attributed should be preserved");
    assertEq(attributionProviderIdAfter, attributionProviderId, "Attribution provider ID should be preserved");
    assertEq(managerAfter, manager, "Manager should be preserved");
    assertEq(conversionEventCountAfter, conversionEventCount, "Conversion event count should be preserved");
    assertEq(campaignMetadataUrlAfter, campaignMetadataUrl1, "Campaign metadata URL should be preserved");
    assertEq(protocolFeesBalanceAfter, protocolFeesBalance, "Accumulated protocol fees should be preserved");

    // Test that only owner can use new functionality
    vm.startPrank(address(0x123));
    vm.expectRevert("Only owner can increment");
    fwCampaignsV2.incrementTotalCampaigns();
    vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0x123)));
    publisherRegistryV2Instance.incrementTotalPublishers();
    vm.stopPrank();

    assertEq(address(fwCampaigns), originalFwCampaigns, "Proxy address should not change");
    assertEq(
      address(publisherRegistry),
      originalPublisherRegistry,
      "Publisher registry proxy address should not change"
    );
    assertEq(isAllowlistSetAfter, isAllowlistSet, "Allowlist should be preserved");
  }

  function test_upgradeUnauthorized() public {
    vm.startPrank(address(0xbad));

    // Expect the custom error OwnableUnauthorizedAccount with the caller's address
    vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0xbad)));
    fwCampaigns.upgradeToAndCall(address(implementationV2), "");

    vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0xbad)));
    publisherRegistry.upgradeToAndCall(address(publisherRegistryV2), "");

    vm.stopPrank();
  }
}

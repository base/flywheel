// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/console.sol";
import { FlywheelCampaigns } from "../src/FlywheelCampaigns.sol";
import { IFlywheelCampaigns } from "../src/interfaces/IFlywheelCampaigns.sol";
import { Test, Vm } from "forge-std/Test.sol";
import { DummyERC20 } from "../src/test/DummyERC20.sol";
import { CampaignBalance } from "../src/CampaignBalance.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract FlywheelCampaignsTest is Test {
  FlywheelCampaigns implementation;
  FlywheelCampaigns fwCampaigns;
  DummyERC20 dummyToken;

  address private owner = address(this);
  address private signer = address(0x2);
  address private treasury = address(0x3);
  address private advertiser = address(0x4);
  address private spdApOwner = address(0x5); // attribution provider owner
  address private spdApSigner = address(0x6); // attribution provider signer
  address private randomAddress1 = address(0x777);
  uint256 private spdApId = 1;
  uint256 private totalFunded1 = 1000 * 10 ** 18;
  string[] private emptyPubAllowlist1 = new string[](0);

  address private campaignBalanceAddress1;
  uint256 private campaignId1;
  string private campaignMetadataUrl1 = "https://example.com/campaign/metadata";

  IFlywheelCampaigns.ConversionConfigInput[] dummyConversionEvents1;

  function setUp() public {
    vm.startPrank(owner);
    dummyConversionEvents1 = new IFlywheelCampaigns.ConversionConfigInput[](2);
    address[] memory initialHolders = new address[](2);
    initialHolders[0] = owner;
    initialHolders[1] = advertiser;
    dummyToken = new DummyERC20(initialHolders);

    address[] memory allowedTokenAddresses = new address[](1);
    allowedTokenAddresses[0] = address(dummyToken);

    IFlywheelCampaigns.AttributionProvider[] memory providers = new IFlywheelCampaigns.AttributionProvider[](1);
    providers[0] = IFlywheelCampaigns.AttributionProvider({ ownerAddress: spdApOwner, signerAddress: spdApSigner });

    // Deploy implementation
    implementation = new FlywheelCampaigns();

    // Deploy proxy
    bytes memory initData = abi.encodeCall(
      FlywheelCampaigns.initialize,
      (owner, treasury, allowedTokenAddresses, providers)
    );

    ERC1967Proxy proxyContract = new ERC1967Proxy(address(implementation), initData);

    // Get interface of implementation at proxy address
    fwCampaigns = FlywheelCampaigns(address(proxyContract));

    dummyConversionEvents1[0] = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.OFFCHAIN,
      eventName: "TestEvent",
      conversionMetadataUrl: "https://example.com",
      publisherBidValue: 1000,
      userBidValue: 0,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE,
      cadenceType: IFlywheelCampaigns.CadenceEventType.ONE_TIME
    });

    dummyConversionEvents1[1] = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.ONCHAIN,
      eventName: "TestEvent2",
      conversionMetadataUrl: "https://example.com",
      publisherBidValue: 1000,
      userBidValue: 0,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE,
      cadenceType: IFlywheelCampaigns.CadenceEventType.ONE_TIME
    });

    vm.stopPrank();

    (address _campaignBalanceAddress, uint256 _campaignId) = _createAndFundCampaign(
      address(dummyToken),
      spdApId,
      totalFunded1,
      true
    );

    campaignBalanceAddress1 = _campaignBalanceAddress;
    campaignId1 = _campaignId;
  }

  // Update all test functions to use proxy instead of fwCampaigns
  function test_constructor() public {
    assertEq(fwCampaigns.owner(), owner);
    assertEq(fwCampaigns.treasuryAddress(), treasury);
  }

  function test_campaignBasics() public {
    (, , , , , uint256 conversionEventCount, string memory metadataUrl, , , , ) = fwCampaigns.campaigns(campaignId1);

    assertEq(metadataUrl, campaignMetadataUrl1);
    assertEq(conversionEventCount, 2);
  }

  function test_registerAttributionProvider() public {
    address randomAddress1 = address(0x1112222);
    address randomSigner = address(0x3334444);

    uint256 providerId = fwCampaigns.nextAttributionProviderId();

    // expect the event to be emitted
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.RegisterAttributionProvider(providerId + 1, randomAddress1, randomSigner);

    vm.startPrank(randomAddress1);
    fwCampaigns.registerAttributionProvider(randomSigner);
  }

  function test_updateAttributionProvider() public {
    vm.startPrank(spdApOwner);
    address randomSigner = address(0x3334444);

    // test emit
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.UpdateAttributionProviderSigner(spdApId, randomSigner);

    // expect the event to be emitted
    fwCampaigns.updateAttributionProviderSigner(spdApId, randomSigner);

    (, address updatedSignerAddress) = fwCampaigns.attributionProviders(spdApId);
    assertEq(updatedSignerAddress, randomSigner);
  }

  function test_updateAttributionProvider_unauthorized() public {
    vm.startPrank(randomAddress1);
    address randomSigner = address(0x3334444);

    // expect the event to be emitted
    vm.expectRevert(IFlywheelCampaigns.Unauthorized.selector);
    fwCampaigns.updateAttributionProviderSigner(spdApId, randomSigner);
  }

  function test_registerAttributionProvider_invalidSigner() public {
    address randomAddress1 = address(0x1112222);

    vm.startPrank(randomAddress1);
    vm.expectRevert(IFlywheelCampaigns.InvalidAddress.selector);
    fwCampaigns.registerAttributionProvider(address(0));
  }

  function test_updateAttributionProviderSigner_invalidSigner() public {
    address randomAddress1 = address(0x1112222);
    address randomSigner = address(0x3334444);

    vm.startPrank(randomAddress1);

    uint256 providerId = fwCampaigns.registerAttributionProvider(randomSigner);
    (address ownerAddress, address signerAddress) = fwCampaigns.attributionProviders(providerId);
    assertEq(signerAddress, randomSigner);

    vm.expectRevert(IFlywheelCampaigns.InvalidAddress.selector);
    fwCampaigns.updateAttributionProviderSigner(spdApId, address(0));
  }

  function test_updateTreasuryAddress() public {
    address newTreasury = address(0x4444);
    fwCampaigns.updateTreasuryAddress(newTreasury);
    assertEq(fwCampaigns.treasuryAddress(), newTreasury);
  }

  function test_updateTreasuryAddress_unauthorized() public {
    vm.startPrank(randomAddress1);
    address newTreasury = address(0x4444);
    vm.expectRevert();
    fwCampaigns.updateTreasuryAddress(newTreasury);
  }

  function test_updateTreasuryAddress_invalidAddress() public {
    vm.startPrank(owner);
    vm.expectRevert(IFlywheelCampaigns.InvalidAddress.selector);
    fwCampaigns.updateTreasuryAddress(address(0));
  }

  function test_getBasicConversionEvent() public view {
    uint8 conversionConfigId = 1;
    IFlywheelCampaigns.ConversionConfig memory conversionConfig = fwCampaigns.getConversionConfig(
      campaignId1,
      conversionConfigId
    );
    assertEq(conversionConfig.eventName, dummyConversionEvents1[0].eventName);
    assertEq(uint8(conversionConfig.eventType), uint8(dummyConversionEvents1[0].eventType));
    assertEq(conversionConfig.publisherBidValue, dummyConversionEvents1[0].publisherBidValue);
    assertEq(conversionConfig.userBidValue, dummyConversionEvents1[0].userBidValue);
    assertEq(uint8(conversionConfig.rewardType), uint8(dummyConversionEvents1[0].rewardType));
    assertEq(uint8(conversionConfig.cadenceType), uint8(dummyConversionEvents1[0].cadenceType));
    assertEq(conversionConfig.conversionMetadataUrl, dummyConversionEvents1[0].conversionMetadataUrl);

    uint8 conversionConfigId2 = 2;
    IFlywheelCampaigns.ConversionConfig memory conversionConfig2 = fwCampaigns.getConversionConfig(
      campaignId1,
      conversionConfigId2
    );
    assertEq(conversionConfig2.eventName, dummyConversionEvents1[1].eventName);
    assertEq(uint8(conversionConfig2.eventType), uint8(dummyConversionEvents1[1].eventType));
    assertEq(conversionConfig2.publisherBidValue, dummyConversionEvents1[1].publisherBidValue);
    assertEq(conversionConfig2.userBidValue, dummyConversionEvents1[1].userBidValue);
    assertEq(uint8(conversionConfig2.rewardType), uint8(dummyConversionEvents1[1].rewardType));
    assertEq(uint8(conversionConfig2.cadenceType), uint8(dummyConversionEvents1[1].cadenceType));
    assertEq(conversionConfig2.conversionMetadataUrl, dummyConversionEvents1[1].conversionMetadataUrl);
  }

  function test_attributeOffchainEvents() public {
    address tokenAddress = address(dummyToken);
    uint256 fundAmount = 1000 * 10 ** 18; // 1000 tokens
    address recipient = address(0x123);
    uint256 amount = 1000;

    uint8 publisherType = 1;
    // Create a sample OffchainEvent
    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient,
      payoutAmount: amount,
      recipientType: publisherType,
      publisherRefCode: "1",
      clickId: "123",
      timestamp: 1734565000
    });

    vm.startPrank(spdApSigner);

    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    uint256 protocolFeeAmount = 0;

    // Expect the event to be emitted
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.OffchainConversion(
      campaignId1,
      events[0].publisherRefCode,
      events[0].conversionConfigId,
      events[0].eventId,
      events[0].payoutAddress,
      events[0].payoutAmount,
      protocolFeeAmount,
      events[0].recipientType,
      events[0].clickId,
      events[0].timestamp
    );

    fwCampaigns.attributeOffchainEvents(campaignId1, events);

    // Check the balance of the Payout contract
    uint256 payoutBalance = dummyToken.balanceOf(campaignBalanceAddress1);
    assertEq(payoutBalance, fundAmount, "Incorrect Payout contract balance");

    // check that the campaign balances in PayoutFactory are updated
    (
      IFlywheelCampaigns.CampaignStatus _status,
      address _campaignBalanceAddress,
      address _tokenAddress,
      uint256 _attributionProviderId,
      address _advertiserAddress,
      uint256 _conversionEventCount,
      string memory _campaignMetadataUrl,
      uint256 _totalAmountClaimed,
      uint256 _totalAmountAllocated,
      uint256 _protocolFeesBalance,
      bool _isAllowlistSet
    ) = fwCampaigns.campaigns(campaignId1);

    assertEq(_totalAmountClaimed, 0, "Amount withdrawn should be 0");
    assertEq(_totalAmountAllocated, amount, "Amount attributed should be 1000");

    uint256 recipientBalance = fwCampaigns.getRecipientBalance(campaignId1, recipient);
    assertEq(recipientBalance, amount, "Recipient balance should be 1000");

    vm.stopPrank();
  }

  function test_updateAllowedTokenAddress() public {
    // DISABLE token address #1
    address tokenAddress = address(dummyToken);
    fwCampaigns.updateAllowedTokenAddress(tokenAddress, false);

    bool isAllowed = fwCampaigns.allowedTokenAddresses(tokenAddress);
    assertFalse(isAllowed, "Token address should not be allowed");

    // ENABLE token address #2
    address tokenAddress2 = address(0x33334444);

    fwCampaigns.updateAllowedTokenAddress(tokenAddress2, true);

    isAllowed = fwCampaigns.allowedTokenAddresses(tokenAddress2);
    assertTrue(isAllowed, "Token address should be allowed");
  }

  function test_createCampaign_tokenAddressNotSupported() public {
    // Create sample conversion events
    IFlywheelCampaigns.ConversionConfigInput[] memory conversionEvents = new IFlywheelCampaigns.ConversionConfigInput[](
      1
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

    address tokenAddress = address(0x44444);

    // First test the revert case
    vm.expectRevert(IFlywheelCampaigns.TokenAddressNotSupported.selector);
    fwCampaigns.createCampaign(tokenAddress, spdApId, true, campaignMetadataUrl1, conversionEvents, emptyPubAllowlist1);

    // Now test successful creation with valid token address
    tokenAddress = address(dummyToken); // Use valid token address

    // Expect CampaignCreated event with correct parameters
    // Set last param to false to skip checking non-indexed parameters
    vm.expectEmit(true, true, true, false);
    emit IFlywheelCampaigns.CampaignCreated(
      fwCampaigns.nextCampaignId() + 1,
      address(this), // msg.sender is advertiser
      address(0), // We don't care about this value
      tokenAddress, // token address
      spdApId, // attribution provider id
      "" // We don't check this since we set param 4 to false
    );

    (uint256 campaignId, address campaignBalanceAddress, uint8[] memory conversionEventIds) = fwCampaigns
      .createCampaign(tokenAddress, spdApId, true, campaignMetadataUrl1, conversionEvents, emptyPubAllowlist1);

    // Verify campaign was created with correct parameters
    (
      IFlywheelCampaigns.CampaignStatus status,
      address storedCampaignBalanceAddress,
      address storedTokenAddress,
      uint256 storedAttributionProviderId,
      address storedAdvertiserAddress,
      ,
      string memory storedMetadataUrl,
      ,
      ,
      ,

    ) = fwCampaigns.campaigns(campaignId);

    assertEq(uint8(status), uint8(IFlywheelCampaigns.CampaignStatus.CAMPAIGN_READY));
    assertEq(storedCampaignBalanceAddress, campaignBalanceAddress);
    assertEq(storedTokenAddress, tokenAddress);
    assertEq(storedAttributionProviderId, spdApId);
    assertEq(storedAdvertiserAddress, address(this));
    assertEq(storedMetadataUrl, campaignMetadataUrl1);
  }

  function test_createCampaign_InvalidAttributionProvider() public {
    uint256 invalidAttributionProviderId = 9999;

    vm.expectRevert(IFlywheelCampaigns.AttributionProviderDoesNotExist.selector);
    vm.prank(advertiser);

    fwCampaigns.createCampaign(
      address(0),
      invalidAttributionProviderId,
      true,
      campaignMetadataUrl1,
      dummyConversionEvents1,
      emptyPubAllowlist1
    );
  }

  function test_createCampaignAndFund() public {
    address tokenAddress = address(dummyToken);
    uint256 fundAmount = 1000 * 10 ** 18; // 1000 tokens

    // Check the balance of the Campaign Balance contract
    uint256 payoutBalance = dummyToken.balanceOf(campaignBalanceAddress1);
    assertEq(payoutBalance, fundAmount, "Incorrect Campaign Balance contract balance");

    // Check the balance using PayoutFactory's getPayoutTotalFunded function
    uint256 totalFunded = fwCampaigns.getCampaignTotalFunded(campaignId1);
    assertEq(totalFunded, fundAmount, "Incorrect total funded amount");

    // Assert that the campaign record is properly set
    (
      IFlywheelCampaigns.CampaignStatus _status,
      address _campaignBalanceAddress,
      address _tokenAddress,
      uint256 _attributionProviderId,
      address _advertiserAddress,
      uint256 _conversionEventCount,
      string memory _campaignMetadataUrl,
      uint256 _totalAmountClaimed,
      uint256 _totalAmountAllocated,
      uint256 _protocolFeesBalance,
      bool _isAllowlistSet
    ) = fwCampaigns.campaigns(campaignId1);

    assertEq(_campaignBalanceAddress, campaignBalanceAddress1, "Incorrect balance location");
    assertEq(_tokenAddress, tokenAddress, "Incorrect token address");
    assertEq(_totalAmountClaimed, 0, "Amount claimed should be 0");
    assertEq(_totalAmountAllocated, 0, "Amount attributed should be 0");
  }

  function test_recipientMappings() public {
    address tokenAddress = address(dummyToken);
    uint256 fundAmount = 1000 * 10 ** 18; // 1000 tokens
    address recipient = address(0x123);

    // Validate the recipient balance
    uint256 recipientBalance = fwCampaigns.getRecipientBalance(campaignId1, recipient);
    assertEq(recipientBalance, 0, "Incorrect recipient balance");

    // Validate the recipient claimed amount
    uint256 recipientClaimed = fwCampaigns.getRecipientClaimed(campaignId1, recipient);
    assertEq(recipientClaimed, 0, "Incorrect recipient claimed amount");
  }

  function test_e2eClaimRewards() public {
    address tokenAddress = address(dummyToken);
    uint256 campaignBalanceAmount = 1000 * 10 ** 18; // 1000 tokens
    uint8 publisherType = 1;
    address userAddress = address(0x456);
    // publisher 1
    address recipient1 = address(0x123);

    uint256 publisherAttributedAmount1 = 5_000;
    string memory publisherRefCode1 = "TEST123";
    address to1 = address(0x789);

    // publisher 2
    address recipient2 = address(0x456);
    uint256 publisherAttributedAmount2 = 3_000;
    string memory publisherRefCode2 = "TEST456";

    vm.startPrank(spdApSigner);

    // Create a sample OnchainEvent
    IFlywheelCampaigns.OnchainEvent[] memory events = new IFlywheelCampaigns.OnchainEvent[](2);
    events[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient1,
      payoutAmount: publisherAttributedAmount1,
      recipientType: publisherType,
      publisherRefCode: publisherRefCode1,
      clickId: "123",
      userAddress: userAddress,
      timestamp: 1734565100,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 2
    });

    events[1] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient2,
      payoutAmount: publisherAttributedAmount2,
      recipientType: publisherType,
      publisherRefCode: publisherRefCode2,
      clickId: "123",
      userAddress: userAddress,
      timestamp: 1734565200,
      txHash: keccak256("TestTxHash2"),
      txChainId: 1,
      txEventLogIndex: 3
    });

    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    uint256 protocolFeeAmount = 0;

    // Expect BOTH of the event to be emitted
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.OnchainConversion(
      campaignId1,
      publisherRefCode1,
      events[0].conversionConfigId,
      events[0].eventId,
      events[0].payoutAddress,
      events[0].payoutAmount,
      protocolFeeAmount, // Add protocol fee amount
      events[0].recipientType,
      events[0].clickId,
      events[0].userAddress,
      events[0].timestamp,
      events[0].txHash,
      events[0].txChainId,
      events[0].txEventLogIndex
    );
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.OnchainConversion(
      campaignId1,
      publisherRefCode2,
      events[1].conversionConfigId,
      events[1].eventId,
      events[1].payoutAddress,
      events[1].payoutAmount,
      protocolFeeAmount, // Add protocol fee amount
      events[1].recipientType,
      events[1].clickId,
      events[1].userAddress,
      events[1].timestamp,
      events[1].txHash,
      events[1].txChainId,
      events[1].txEventLogIndex
    );

    fwCampaigns.attributeOnchainEvents(campaignId1, events);

    // Check the balance of the Payout contract
    uint256 payoutBalance = dummyToken.balanceOf(campaignBalanceAddress1);
    assertEq(payoutBalance, campaignBalanceAmount, "Incorrect Payout contract balance");

    // Check that the campaign balances in PayoutFactory are updated
    (, , , , , , , uint256 amountClaimed_sh1, uint256 amountAttributed_sh1, , ) = fwCampaigns.campaigns(campaignId1);

    assertEq(amountClaimed_sh1, 0, "Amount withdrawn should be 0");
    assertEq(
      amountAttributed_sh1,
      publisherAttributedAmount1 + publisherAttributedAmount2,
      "Amount attributed should be 8000 (5000 + 3000)"
    );

    uint256 recipientBalance = fwCampaigns.getRecipientBalance(campaignId1, recipient1);
    assertEq(recipientBalance, publisherAttributedAmount1, "Recipient balance should be 1000");

    // claim the rewards
    vm.startPrank(recipient1);

    uint256[] memory campaignIds = new uint256[](1);
    campaignIds[0] = campaignId1;

    // We are claiming the rewards for recipient1
    fwCampaigns.claimRewards(campaignIds, to1);

    // check that the recipient balance is 0
    recipientBalance = fwCampaigns.getRecipientBalance(campaignId1, recipient1);
    assertEq(recipientBalance, 0, "Recipient balance should be 0 since they claimed their rewards");

    uint256 recipientClaimed = fwCampaigns.getRecipientClaimed(campaignId1, recipient1);
    assertEq(recipientClaimed, publisherAttributedAmount1, "Recipient claimed should be 5000");

    // check the to address has the amount
    uint256 toBalance = dummyToken.balanceOf(to1);
    assertEq(toBalance, publisherAttributedAmount1, "To address should have 1000 tokens");

    // check that the totals are updated correctly
    (
      IFlywheelCampaigns.CampaignStatus __status,
      address _payoutAddress,
      address _tokenAddress,
      uint256 _attributionProviderId,
      address _advertiserAddress,
      uint256 _conversionEventCount,
      string memory _campaignMetadataUrl,
      uint256 _totalAmountClaimed,
      uint256 _totalAmountAllocated,
      uint256 _protocolFeesBalance,
      bool _isAllowlistSet
    ) = fwCampaigns.campaigns(campaignId1);
    assertEq(_totalAmountClaimed, publisherAttributedAmount1, "Total amount claimed should be 5000");

    // assets other balances
    assertEq(
      _totalAmountAllocated,
      publisherAttributedAmount1 + publisherAttributedAmount2,
      "Total amount attributed should be 0"
    );

    vm.stopPrank();
  }

  function test_pushRewards_e2e() public {
    address tokenAddress = address(dummyToken);
    uint256 campaignBalanceAmount = 1000 * 10 ** 18; // 1000 tokens
    uint8 publisherType = 1;

    // publisher 1
    address recipient1 = address(0x123);

    uint256 publisherAttributedAmount1 = 12_000;
    string memory publisherRefCode1 = "TEST123";
    address to1 = address(0x789);

    // publisher 2
    address recipient2 = address(0x456);
    uint256 publisherAttributedAmount2 = 4_000;
    string memory publisherRefCode2 = "TEST456";

    address userAddress1 = address(0x111);
    address userAddress2 = address(0x222);
    address userAddress3 = address(0x333);

    // publisher 3
    address recipient3 = address(0x777);
    uint256 publisherAttributedAmount3 = 3_000;
    string memory publisherRefCode3 = "TEST777";

    vm.startPrank(spdApSigner);

    // Create a sample OnchainEvent
    IFlywheelCampaigns.OnchainEvent[] memory events = new IFlywheelCampaigns.OnchainEvent[](3);
    events[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient1,
      payoutAmount: publisherAttributedAmount1,
      recipientType: publisherType,
      publisherRefCode: publisherRefCode1,
      clickId: "123",
      userAddress: userAddress1,
      timestamp: 1734565100,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 2
    });

    events[1] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient2,
      payoutAmount: publisherAttributedAmount2,
      recipientType: publisherType,
      publisherRefCode: publisherRefCode2,
      clickId: "123",
      userAddress: userAddress2,
      timestamp: 1734565200,
      txHash: keccak256("TestTxHash2"),
      txChainId: 1,
      txEventLogIndex: 3
    });

    events[2] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient3,
      payoutAmount: publisherAttributedAmount3,
      recipientType: publisherType,
      publisherRefCode: publisherRefCode3,
      clickId: "123",
      userAddress: userAddress3,
      timestamp: 1734565300,
      txHash: keccak256("TestTxHash3"),
      txChainId: 1,
      txEventLogIndex: 4
    });

    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    uint256 protocolFeeAmount = 0;

    // Expect BOTH of the event to be emitted
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.OnchainConversion(
      campaignId1,
      publisherRefCode1,
      events[0].conversionConfigId,
      events[0].eventId,
      events[0].payoutAddress,
      events[0].payoutAmount,
      protocolFeeAmount, // Add protocol fee amount
      events[0].recipientType,
      events[0].clickId,
      events[0].userAddress,
      events[0].timestamp,
      events[0].txHash,
      events[0].txChainId,
      events[0].txEventLogIndex
    );
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.OnchainConversion(
      campaignId1,
      publisherRefCode2,
      events[1].conversionConfigId,
      events[1].eventId,
      events[1].payoutAddress,
      events[1].payoutAmount,
      protocolFeeAmount, // Add protocol fee amount
      events[1].recipientType,
      events[1].clickId,
      events[1].userAddress,
      events[1].timestamp,
      events[1].txHash,
      events[1].txChainId,
      events[1].txEventLogIndex
    );
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.OnchainConversion(
      campaignId1,
      publisherRefCode3,
      events[2].conversionConfigId,
      events[2].eventId,
      events[2].payoutAddress,
      events[2].payoutAmount,
      protocolFeeAmount, // Add protocol fee amount
      events[2].recipientType,
      events[2].clickId,
      events[2].userAddress,
      events[2].timestamp,
      events[2].txHash,
      events[2].txChainId,
      events[2].txEventLogIndex
    );

    fwCampaigns.attributeOnchainEvents(campaignId1, events);

    // Check the balance of the Payout contract
    uint256 payoutBalance = dummyToken.balanceOf(campaignBalanceAddress1);
    assertEq(payoutBalance, campaignBalanceAmount, "Incorrect Payout contract balance");

    // Check that the campaign balances in PayoutFactory are updated
    (, , , , , , , uint256 amountClaimed_sh1, uint256 amountAttributed_sh1, , ) = fwCampaigns.campaigns(campaignId1);

    assertEq(amountClaimed_sh1, 0, "Amount withdrawn should be 0");
    assertEq(
      amountAttributed_sh1,
      publisherAttributedAmount1 + publisherAttributedAmount2 + publisherAttributedAmount3,
      "Amount attributed should be 19000 (12000 + 4000 + 3000)"
    );

    uint256 recipientBalance = fwCampaigns.getRecipientBalance(campaignId1, recipient1);
    assertEq(recipientBalance, publisherAttributedAmount1, "Recipient balance should be 1000");

    // We are claiming the rewards for recipient1
    address[] memory payoutAddresses = new address[](2);
    payoutAddresses[0] = recipient1;
    payoutAddresses[1] = recipient2;

    vm.startPrank(spdApSigner);
    // PUSH rewards for recipient1 and recipient2 BUT not recipient3
    fwCampaigns.pushRewards(campaignId1, payoutAddresses);

    // check that the recipient balance is 0
    recipientBalance = fwCampaigns.getRecipientBalance(campaignId1, recipient1);
    assertEq(recipientBalance, 0, "Recipient balance should be 0 since they claimed their rewards");

    uint256 recipientClaimed = fwCampaigns.getRecipientClaimed(campaignId1, recipient1);
    assertEq(recipientClaimed, publisherAttributedAmount1, "Recipient claimed should be 5000");

    // check the to address has the amount
    uint256 recipient1Balance = dummyToken.balanceOf(recipient1);
    assertEq(recipient1Balance, publisherAttributedAmount1, "To address should have 12000 tokens");

    // check that the totals are updated correctly
    (
      IFlywheelCampaigns.CampaignStatus __status,
      address _payoutAddress,
      address _tokenAddress,
      uint256 _attributionProviderId,
      address _advertiserAddress,
      uint256 _conversionEventCount,
      string memory _campaignMetadataUrl,
      uint256 _totalAmountClaimed,
      uint256 _totalAmountAllocated,
      uint256 _protocolFeesBalance,
      bool _isAllowlistSet
    ) = fwCampaigns.campaigns(campaignId1);
    assertEq(
      _totalAmountClaimed,
      publisherAttributedAmount1 + publisherAttributedAmount2,
      "Total amount claimed should be 16000 (12000 + 4000)"
    );

    // assets other balances
    assertEq(
      _totalAmountAllocated,
      publisherAttributedAmount1 + publisherAttributedAmount2 + publisherAttributedAmount3,
      "Total amount attributed should be 19000 (12000 + 4000 + 3000)"
    );

    vm.stopPrank();
  }

  function test_conversionEvents() public {
    address tokenAddress = address(dummyToken);

    IFlywheelCampaigns.ConversionConfigInput[] memory conversionEvents = new IFlywheelCampaigns.ConversionConfigInput[](
      1
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

    vm.startPrank(owner);

    (uint256 campaignId, address campaignBalanceAddress, uint8[] memory conversionEventIds) = fwCampaigns
      .createCampaign(tokenAddress, spdApId, true, campaignMetadataUrl1, conversionEvents, emptyPubAllowlist1);

    // confirm the exact data of emitted campaign creation event
    vm.stopPrank();

    uint8 createdConversionEventId = conversionEventIds[0];

    assertEq(createdConversionEventId, 1);

    // Get and verify conversion event
    IFlywheelCampaigns.ConversionConfig memory conversionConfig = fwCampaigns.getConversionConfig(
      campaignId,
      createdConversionEventId
    );

    assertEq(uint8(conversionConfig.status), uint8(IFlywheelCampaigns.ConversionConfigStatus.ACTIVE));
    assertEq(uint8(conversionConfig.eventType), uint8(IFlywheelCampaigns.EventType.OFFCHAIN));
    assertEq(conversionConfig.eventName, "click");
    assertEq(conversionConfig.publisherBidValue, 100);
  }

  function test_conversionEventIds() public {
    address tokenAddress = address(dummyToken);
    IFlywheelCampaigns.ConversionConfigInput[] memory conversionEvents = new IFlywheelCampaigns.ConversionConfigInput[](
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
      eventName: "onchainEvnet",
      conversionMetadataUrl: "https://example.com",
      publisherBidValue: 100,
      userBidValue: 0,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE,
      cadenceType: IFlywheelCampaigns.CadenceEventType.ONE_TIME
    });

    vm.startPrank(advertiser);
    (uint256 campaignId1, address campaignBalanceAddress1, uint8[] memory conversionEventIds1) = fwCampaigns
      .createCampaign(tokenAddress, spdApId, true, campaignMetadataUrl1, conversionEvents, emptyPubAllowlist1);

    assertEq(conversionEventIds1.length, 2);
    assertEq(conversionEventIds1[0], 1);
    assertEq(conversionEventIds1[1], 2);

    (uint256 campaignId2, address campaignBalanceAddress2, uint8[] memory conversionEventIds2) = fwCampaigns
      .createCampaign(tokenAddress, spdApId, true, campaignMetadataUrl1, conversionEvents, emptyPubAllowlist1);

    assertEq(conversionEventIds2.length, 2);
    assertEq(conversionEventIds2[0], 1);
    assertEq(conversionEventIds2[1], 2);

    vm.stopPrank();
  }

  function test_emitOffchainEventErrorInvalidConvId() public {
    vm.startPrank(spdApSigner);

    // make campaign active
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 222,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0),
      payoutAmount: 0,
      recipientType: 0,
      publisherRefCode: "xx",
      clickId: "xx",
      timestamp: 1734565000
    });

    vm.expectRevert(IFlywheelCampaigns.ConversionConfigDoesNotExist.selector);
    fwCampaigns.attributeOffchainEvents(campaignId1, events);

    vm.stopPrank();
  }

  function test_emitOnchainEventErrorInvalidConvId() public {
    vm.startPrank(spdApSigner);

    // make campaign active
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OnchainEvent[] memory events = new IFlywheelCampaigns.OnchainEvent[](1);
    events[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 222,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: 1000,
      recipientType: 0,
      publisherRefCode: "xx",
      clickId: "xx",
      userAddress: address(0x999),
      timestamp: 1734565000,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 2
    });

    vm.expectRevert(IFlywheelCampaigns.ConversionConfigDoesNotExist.selector);
    fwCampaigns.attributeOnchainEvents(campaignId1, events);

    vm.stopPrank();
  }

  function test_addConversionEvent() public {
    vm.startPrank(advertiser);

    IFlywheelCampaigns.ConversionConfigInput memory newEvent = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.OFFCHAIN,
      eventName: "NewTestEvent",
      conversionMetadataUrl: "https://example.com/new",
      publisherBidValue: 2000,
      userBidValue: 100,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE,
      cadenceType: IFlywheelCampaigns.CadenceEventType.ONE_TIME
    });

    // Get initial conversion event count
    (, , , , , uint8 initialConversionEventCount, , , , , ) = fwCampaigns.campaigns(campaignId1);

    // Add new conversion event
    fwCampaigns.addConversionConfig(campaignId1, newEvent);

    // Get updated conversion event count
    (, , , , , uint8 updatedConversionEventCount, , , , , ) = fwCampaigns.campaigns(campaignId1);

    // Verify event count increased
    assertEq(updatedConversionEventCount, initialConversionEventCount + 1);

    // Get and verify the new conversion event
    IFlywheelCampaigns.ConversionConfig memory addedEvent = fwCampaigns.getConversionConfig(
      campaignId1,
      updatedConversionEventCount
    );

    assertEq(addedEvent.eventName, "NewTestEvent");
    assertEq(uint8(addedEvent.eventType), uint8(IFlywheelCampaigns.EventType.OFFCHAIN));
    assertEq(addedEvent.publisherBidValue, 2000);
    assertEq(addedEvent.userBidValue, 100);
    assertEq(uint8(addedEvent.rewardType), uint8(IFlywheelCampaigns.RewardType.FLAT_FEE));
    assertEq(uint8(addedEvent.cadenceType), uint8(IFlywheelCampaigns.CadenceEventType.ONE_TIME));

    vm.stopPrank();
  }
  function test_addConversionEvent_InvalidStatuses() public {
    vm.startPrank(advertiser);

    IFlywheelCampaigns.ConversionConfigInput memory newEvent = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.OFFCHAIN,
      eventName: "NewTestEvent",
      conversionMetadataUrl: "https://example.com/new",
      publisherBidValue: 2000,
      userBidValue: 100,
      rewardType: IFlywheelCampaigns.RewardType.NONE, // invalid reward type
      cadenceType: IFlywheelCampaigns.CadenceEventType.ONE_TIME
    });

    vm.expectRevert(IFlywheelCampaigns.InvalidConversionConfig.selector);
    fwCampaigns.addConversionConfig(campaignId1, newEvent);

    IFlywheelCampaigns.ConversionConfigInput memory newEvent2 = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.OFFCHAIN,
      eventName: "NewTestEvent",
      conversionMetadataUrl: "https://example.com/new",
      publisherBidValue: 2000,
      userBidValue: 100,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE, // valid reward type
      cadenceType: IFlywheelCampaigns.CadenceEventType.NONE // invalid cadence type
    });

    vm.expectRevert(IFlywheelCampaigns.InvalidConversionConfig.selector);
    fwCampaigns.addConversionConfig(campaignId1, newEvent2);

    IFlywheelCampaigns.ConversionConfigInput memory newEvent3 = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.NONE,
      eventName: "NewTestEvent",
      conversionMetadataUrl: "https://example.com/new",
      publisherBidValue: 2000,
      userBidValue: 100,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE, // valid reward type
      cadenceType: IFlywheelCampaigns.CadenceEventType.RECURRING // valid cadence type
    });

    vm.expectRevert(IFlywheelCampaigns.InvalidConversionConfig.selector);
    fwCampaigns.addConversionConfig(campaignId1, newEvent3);

    vm.stopPrank();
  }

  function test_addConversionEvent_CampaignNotActive() public {
    vm.startPrank(advertiser);

    uint256 nonExistentCampaignId = 9999;

    IFlywheelCampaigns.ConversionConfigInput memory newEvent = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.OFFCHAIN,
      eventName: "NewTestEvent",
      conversionMetadataUrl: "https://example.com/new",
      publisherBidValue: 2000,
      userBidValue: 100,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE,
      cadenceType: IFlywheelCampaigns.CadenceEventType.ONE_TIME
    });

    vm.expectRevert(IFlywheelCampaigns.Unauthorized.selector);
    fwCampaigns.addConversionConfig(nonExistentCampaignId, newEvent);

    vm.stopPrank();
  }

  function test_addConversionEvent_unauthorized() public {
    vm.startPrank(owner);

    IFlywheelCampaigns.ConversionConfigInput memory newEvent = IFlywheelCampaigns.ConversionConfigInput({
      eventType: IFlywheelCampaigns.EventType.OFFCHAIN,
      eventName: "NewTestEvent",
      conversionMetadataUrl: "https://example.com/new",
      publisherBidValue: 2000,
      userBidValue: 100,
      rewardType: IFlywheelCampaigns.RewardType.FLAT_FEE,
      cadenceType: IFlywheelCampaigns.CadenceEventType.ONE_TIME
    });

    vm.expectRevert(IFlywheelCampaigns.Unauthorized.selector);
    fwCampaigns.addConversionConfig(campaignId1, newEvent);

    vm.stopPrank();
  }

  function test_deactivateConversionConfig() public {
    vm.startPrank(advertiser);

    uint8 conversionEventId = 1;

    // Verify initial status is ACTIVE
    IFlywheelCampaigns.ConversionConfig memory initialEvent = fwCampaigns.getConversionConfig(
      campaignId1,
      conversionEventId
    );
    assertEq(uint8(initialEvent.status), uint8(IFlywheelCampaigns.ConversionConfigStatus.ACTIVE));

    // Deactivate the conversion event
    fwCampaigns.deactivateConversionConfig(campaignId1, conversionEventId);

    // Verify status is now DEACTIVATED
    IFlywheelCampaigns.ConversionConfig memory updatedEvent = fwCampaigns.getConversionConfig(
      campaignId1,
      conversionEventId
    );
    assertEq(uint8(updatedEvent.status), uint8(IFlywheelCampaigns.ConversionConfigStatus.DEACTIVATED));

    vm.stopPrank();
  }

  function test_deactivateConversionConfig_unauthorized() public {
    vm.prank(address(0x9999));

    uint8 conversionEventId = 1;

    vm.expectRevert(IFlywheelCampaigns.Unauthorized.selector);
    fwCampaigns.deactivateConversionConfig(campaignId1, conversionEventId);
  }

  function test_withdrawRemainingBalance() public {
    // Setup - get campaign to COMPLETED state
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);

    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    // Initial balances
    uint256 initialCampaignBalance = dummyToken.balanceOf(campaignBalanceAddress1);
    uint256 initialAdvertiserBalance = dummyToken.balanceOf(owner);

    // Withdraw remaining balance
    vm.prank(advertiser);
    fwCampaigns.withdrawRemainingBalance(campaignId1, owner);

    // Verify balances after withdrawal
    uint256 finalCampaignBalance = dummyToken.balanceOf(campaignBalanceAddress1);
    uint256 finalAdvertiserBalance = dummyToken.balanceOf(owner);

    assertEq(finalCampaignBalance, 0, "Campaign balance should be 0 after withdrawal");
    assertEq(
      finalAdvertiserBalance,
      initialAdvertiserBalance + initialCampaignBalance,
      "Advertiser should receive full campaign balance"
    );
  }

  function test_attributeEventsInvalidAttributionStatus() public {
    // Setup - get campaign to COMPLETED state
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);

    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    vm.prank(spdApSigner);
    IFlywheelCampaigns.OffchainEvent[] memory offchainEvents = new IFlywheelCampaigns.OffchainEvent[](1);
    offchainEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: 400 * 10 ** 18,
      recipientType: 1,
      publisherRefCode: "TEST123",
      clickId: "123",
      timestamp: 1734565000
    });

    vm.expectRevert(IFlywheelCampaigns.InvalidCampaignStatus.selector);
    fwCampaigns.attributeOffchainEvents(campaignId1, offchainEvents);

    IFlywheelCampaigns.OnchainEvent[] memory onchainEvents = new IFlywheelCampaigns.OnchainEvent[](1);
    onchainEvents[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: 400 * 10 ** 18,
      recipientType: 1,
      publisherRefCode: "TEST123",
      clickId: "123",
      userAddress: address(0x999),
      timestamp: 1734565000,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 2
    });

    vm.expectRevert(IFlywheelCampaigns.InvalidCampaignStatus.selector);
    vm.prank(spdApSigner);
    fwCampaigns.attributeOnchainEvents(campaignId1, onchainEvents);
  }

  function test_withdrawRemainingBalanceWithAttributions() public {
    // Setup - attribute some rewards first
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: 400 * 10 ** 18,
      recipientType: 1,
      publisherRefCode: "TEST123",
      clickId: "123",
      timestamp: 1734565000
    });

    vm.prank(spdApSigner);

    fwCampaigns.attributeOffchainEvents(campaignId1, events);

    // advertiser prank
    vm.prank(advertiser);
    // Move to COMPLETED state
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    uint256 initialCampaignBalance = dummyToken.balanceOf(campaignBalanceAddress1);
    uint256 initialAdvertiserBalance = dummyToken.balanceOf(advertiser);

    // Withdraw remaining balance
    vm.prank(advertiser);
    address randomTo = address(0x1010101010);

    fwCampaigns.withdrawRemainingBalance(campaignId1, randomTo);

    // Verify balances
    uint256 finalTotalFunded = fwCampaigns.getCampaignTotalFunded(campaignId1);
    uint256 finalAdvertiserBalance = dummyToken.balanceOf(randomTo);

    assertEq(finalTotalFunded, totalFunded1, "total funded is not accurate");
    assertEq(finalAdvertiserBalance, (600 * 10 ** 18), "Advertiser should receive unattributed balance");
  }
  function test_withdrawRemainingBalance_NotCompleted() public {
    // First make campaign ACTIVE
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    // Try to withdraw when campaign is ACTIVE (should fail)
    vm.prank(advertiser); // Changed from owner to advertiser
    vm.expectRevert(IFlywheelCampaigns.InvalidCampaignStatus.selector);
    fwCampaigns.withdrawRemainingBalance(campaignId1, advertiser);
  }

  function test_withdrawRemainingBalance_NotAdvertiser() public {
    // Setup - get campaign to COMPLETED state
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);
    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    // Try to withdraw as an attirbution provier (non-advertiser)
    vm.prank(address(0x9999));
    vm.expectRevert(IFlywheelCampaigns.Unauthorized.selector);
    fwCampaigns.withdrawRemainingBalance(campaignId1, address(0x9999));
  }

  function test_withdrawRemainingBalance_NoBalance() public {
    // Setup - attribute all funds then process campaign
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: 1000 * 10 ** 18, // Attribute full balance
      recipientType: 1,
      publisherRefCode: "TEST123",
      clickId: "123",
      timestamp: 1734565000
    });

    vm.prank(spdApSigner);
    fwCampaigns.attributeOffchainEvents(campaignId1, events);

    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);

    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    uint256 initialAdvertiserBalance = dummyToken.balanceOf(owner);

    // Try to withdraw when no unattributed balance remains
    vm.prank(advertiser);
    fwCampaigns.withdrawRemainingBalance(campaignId1, owner);

    uint256 finalAdvertiserBalance = dummyToken.balanceOf(owner);
    assertEq(
      finalAdvertiserBalance,
      initialAdvertiserBalance,
      "Advertiser balance should not change when no funds to withdraw"
    );
  }

  function test_withdrawRemainingBalance_MultipleTimes() public {
    address randomTo = address(0x101010101022);

    // Setup - get campaign to COMPLETED state
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);
    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    // First withdrawal
    vm.prank(advertiser);
    fwCampaigns.withdrawRemainingBalance(campaignId1, randomTo);

    uint256 balanceAfterFirstWithdraw = dummyToken.balanceOf(campaignBalanceAddress1);
    assertEq(balanceAfterFirstWithdraw, 0, "Balance should be 0 after first withdrawal");

    // balance of advertiser should be 0
    uint256 balanceOfAdvertiserToAddress = dummyToken.balanceOf(randomTo);
    assertEq(balanceOfAdvertiserToAddress, totalFunded1, "Balance of advertiser should be the total funded amount");

    // Try second withdrawal
    vm.prank(advertiser);
    fwCampaigns.withdrawRemainingBalance(campaignId1, randomTo);

    uint256 balanceAfterSecondWithdraw = dummyToken.balanceOf(campaignBalanceAddress1);
    assertEq(
      balanceAfterSecondWithdraw,
      balanceAfterFirstWithdraw,
      "Balance should not change after second withdrawal"
    );
  }

  function test_withdrawComplexScenario1() public {
    // Here the amount attributed is 910 ether, and the remaining balance is 90 ether
    // protocol fee is 10% (91 ether) but shouldn't affect the withdrawal in any way
    // publisher claims 819 ether (910 - 10%)
    // treasury claims protocol fees -> 91 ether
    // advertiser withdraws remaining balance -> 90 ether

    address toWithdrawal = address(0x99999);

    // Set protocol fee to 10%
    vm.prank(owner);
    fwCampaigns.updateProtocolFee(1000);

    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    uint256 attributionAmount = 910 ether;
    uint256 expectedFee = 91 ether;
    // remaining balance
    uint256 remainingBalance = 1000 ether - attributionAmount;

    FlywheelCampaigns.OnchainEvent[] memory events = new IFlywheelCampaigns.OnchainEvent[](1);
    events[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: attributionAmount,
      recipientType: 1,
      publisherRefCode: "test",
      clickId: "123",
      userAddress: address(0x999),
      timestamp: 1734565000,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 1
    });

    fwCampaigns.attributeOnchainEvents(campaignId1, events);
    vm.stopPrank();

    // @audit-info initial balance is 1000 ether
    assertEq(dummyToken.balanceOf(campaignBalanceAddress1), 1000 ether);

    // @audit-info totalAmountAllocated is 910 ether
    (, , , , , , , , uint256 totalAmountAllocated, , ) = fwCampaigns.campaigns(campaignId1);
    assertEq(totalAmountAllocated, attributionAmount);

    // @audit-info 1) Recipient claims 819 ether (910 - 10%)
    uint256 initialBalance123 = dummyToken.balanceOf(address(0x123));
    vm.prank(address(0x123));
    uint256[] memory claimCampaignIds = new uint256[](1);
    claimCampaignIds[0] = campaignId1;
    fwCampaigns.claimRewards(claimCampaignIds, address(0x123));
    assertEq(dummyToken.balanceOf(address(0x123)), initialBalance123 + 819 ether);

    // @audit-info 2) Treasury withdraws fees -> 91 ether
    vm.prank(treasury);
    uint256[] memory campaignIds = new uint256[](1);
    campaignIds[0] = campaignId1;
    fwCampaigns.claimProtocolFees(campaignIds);
    assertEq(dummyToken.balanceOf(treasury), expectedFee, "Treasury should receive protocol fees");

    // @audit-info 3) Set campaign status to completed
    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);

    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    // @audit-info the campaigns balance is 90 ether
    assertEq(dummyToken.balanceOf(campaignBalanceAddress1), remainingBalance);

    vm.prank(advertiser);
    fwCampaigns.withdrawRemainingBalance(campaignId1, toWithdrawal);

    // check balance of toWithdrawal
    assertEq(dummyToken.balanceOf(toWithdrawal), remainingBalance);
  }

  function test_withdrawComplexScenario2() public {
    // Similar to scenario1 but Publisher claims when campaign is COMPLETED & after both the treasury claimed and advertiser have withdrawn remaining balance
    // treasury claims protocol fees -> 91 ether
    // advertiser withdraws remaining balance -> 90 ether
    // the publisher amount is still 819 ether
    address recipient = address(0x123);

    address toWithdrawal = address(0x99999);

    // Set protocol fee to 10%
    vm.prank(owner);
    fwCampaigns.updateProtocolFee(1000);

    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    uint256 attributionAmount = 910 ether;
    uint256 expectedFee = 91 ether;
    uint256 attributionAmountMinusFee = attributionAmount - expectedFee;
    // remaining balance
    uint256 amountToBeWithdrawn = 1000 ether - attributionAmount;

    FlywheelCampaigns.OnchainEvent[] memory events = new IFlywheelCampaigns.OnchainEvent[](1);
    events[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient,
      payoutAmount: attributionAmount,
      recipientType: 1,
      publisherRefCode: "test",
      clickId: "123",
      userAddress: address(0x999),
      timestamp: 1734565000,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 1
    });

    fwCampaigns.attributeOnchainEvents(campaignId1, events);
    vm.stopPrank();

    // @audit-info initial balance is 1000 ether
    assertEq(dummyToken.balanceOf(campaignBalanceAddress1), 1000 ether);

    assertEq(
      fwCampaigns.getRecipientBalance(campaignId1, recipient),
      attributionAmountMinusFee,
      "Recipient should have received attribution amount minus fee part1"
    );

    // @audit-info totalAmountAllocated is 910 ether
    (, , , , , , , , uint256 totalAmountAllocated, , ) = fwCampaigns.campaigns(campaignId1);
    assertEq(totalAmountAllocated, attributionAmount);

    // @audit-info 2) Treasury withdraws fees -> 91 ether
    vm.prank(treasury);
    uint256[] memory campaignIds = new uint256[](1);
    campaignIds[0] = campaignId1;
    fwCampaigns.claimProtocolFees(campaignIds);
    assertEq(dummyToken.balanceOf(treasury), expectedFee, "Treasury should receive protocol fees");

    // @audit-info 3) Set campaign status to completed
    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);

    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    // uint256 remainderBalance = totalFunded1 - amountToBeWithdrawn - expectedFee;

    assertEq(
      dummyToken.balanceOf(campaignBalanceAddress1),
      totalFunded1 - expectedFee,
      "Campaign balance should be remaining balance"
    );

    vm.prank(advertiser);
    fwCampaigns.withdrawRemainingBalance(campaignId1, toWithdrawal);

    assertEq(
      fwCampaigns.getRecipientBalance(campaignId1, recipient),
      attributionAmountMinusFee,
      "Recipient should have received attribution amount minus fee part2"
    );

    // check balance of toWithdrawal
    assertEq(dummyToken.balanceOf(toWithdrawal), amountToBeWithdrawn, "Advertiser should receive remaining balance");

    // @audit-info 1) Recipient claims 819 ether (910 - 10%)
    uint256 initialBalance123 = dummyToken.balanceOf(recipient);
    uint256[] memory claimCampaignIds = new uint256[](1);
    claimCampaignIds[0] = campaignId1;
    vm.prank(recipient);
    fwCampaigns.claimRewards(claimCampaignIds, recipient);
    assertEq(
      dummyToken.balanceOf(recipient),
      initialBalance123 + 819 ether,
      "Recipient should receive remaining balance"
    );
  }

  function test_updateCampaignStatus_unauthorized() public {
    vm.prank(owner); // Campaign manager/owner

    // owner cannot set to ACTIVE
    vm.expectRevert(IFlywheelCampaigns.Unauthorized.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);
  }

  function test_campaignReadyStateTransition() public {
    // Create campaign without setting to CAMPAIGN_READY
    vm.startPrank(advertiser);
    (uint256 newCampaignId, address campaignBalanceAddress, uint8[] memory conversionEventIds) = fwCampaigns
      .createCampaign(
        address(dummyToken),
        spdApId,
        false, // don't set to CAMPAIGN_READY during creation
        campaignMetadataUrl1,
        dummyConversionEvents1,
        emptyPubAllowlist1
      );

    // Verify initial state is CREATED
    (IFlywheelCampaigns.CampaignStatus status, , , , , , , , , , ) = fwCampaigns.campaigns(newCampaignId);
    assertEq(uint8(status), uint8(IFlywheelCampaigns.CampaignStatus.CREATED));

    // Update to CAMPAIGN_READY
    fwCampaigns.updateCampaignStatus(newCampaignId, IFlywheelCampaigns.CampaignStatus.CAMPAIGN_READY);

    // Verify state is now CAMPAIGN_READY
    (status, , , , , , , , , , ) = fwCampaigns.campaigns(newCampaignId);
    assertEq(uint8(status), uint8(IFlywheelCampaigns.CampaignStatus.CAMPAIGN_READY));

    vm.stopPrank();
  }

  function test_updateCampaignStatus_completedFromCampaignReady() public {
    // check campaign is in CREATED state
    (IFlywheelCampaigns.CampaignStatus status, , , , , , , , , , ) = fwCampaigns.campaigns(campaignId1);
    assertEq(uint8(status), uint8(IFlywheelCampaigns.CampaignStatus.CAMPAIGN_READY));

    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    (status, , , , , , , , , , ) = fwCampaigns.campaigns(campaignId1);
    assertEq(uint8(status), uint8(IFlywheelCampaigns.CampaignStatus.COMPLETED));
  }

  function test_updateCampaignStatus_completedFromCreated() public {
    // create campaign in CREATED state
    vm.startPrank(advertiser);
    uint8[] memory conversionEventIds = new uint8[](1);
    (uint256 newCampaignId, address campaignBalanceAddress, ) = fwCampaigns.createCampaign(
      address(dummyToken),
      spdApId,
      false, // don't set to CAMPAIGN_READY during creation
      campaignMetadataUrl1,
      dummyConversionEvents1,
      emptyPubAllowlist1
    );

    (IFlywheelCampaigns.CampaignStatus status, , , , , , , , , , ) = fwCampaigns.campaigns(newCampaignId);
    assertEq(uint8(status), uint8(IFlywheelCampaigns.CampaignStatus.CREATED));

    fwCampaigns.updateCampaignStatus(newCampaignId, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    (IFlywheelCampaigns.CampaignStatus status2, , , , , , , , , , ) = fwCampaigns.campaigns(newCampaignId);
    assertEq(uint8(status2), uint8(IFlywheelCampaigns.CampaignStatus.COMPLETED));

    vm.stopPrank();
  }

  function test_updateCampaignStatus_invalidTransition() public {
    // check campaign is in CREATED state
    (IFlywheelCampaigns.CampaignStatus status, , , , , , , , , , ) = fwCampaigns.campaigns(campaignId1);
    assertEq(uint8(status), uint8(IFlywheelCampaigns.CampaignStatus.CAMPAIGN_READY));

    // Attribution provider tries to set to COMPLETED from CAMPAIGN_READY (should fail)
    vm.prank(spdApSigner);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    // advertiser tries to set to CREATED from CAMPAIGN_READY (should fail)
    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.CREATED);

    // advertiser tries to set to CAMPAIGN_READY from CAMPAIGN_READY (should fail)
    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.CAMPAIGN_READY);

    // advertiser tries to set to ACTIVE from CAMPAIGN_READY (should fail)
    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    // attribution provider tries to set to PENDING_COMPLETION from CAMPAIGN_READY (should fail)
    vm.prank(spdApSigner);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);

    // correctly set to ACTIVE
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.CAMPAIGN_READY);

    // advertiser tries to set to CREATD from ACTIVE (should fail)
    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.CREATED);

    // attribution provider tries to set to NONE from ACTIVE (should fail)
    vm.prank(spdApSigner);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.NONE);

    // advertiser tries to set to COMPLETED from ACTIVE (should fail)
    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    // attribution provider tries to set to COMPLETED from ACTIVE (should fail)
    vm.prank(spdApSigner);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    // correctly set to PAUSED
    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PAUSED);

    // advertiser tries to set to CREATED from PAUSED (should fail)
    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.CREATED);

    // correctly set to PENDING_COMPLETION
    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);

    // advertiser tries to set to PAUSED from PENDING_COMPLETION (should fail)
    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.PAUSED);

    // advertiser tries to set to ACTIVE from PENDING_COMPLETION (should fail)
    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    // advertiser tries to set to COMPLETED from PENDING_COMPLETION (should fail)
    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    // correctly set to COMPLETED
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    // advertiser tries to set to ACTIVE from COMPLETED (should fail)
    vm.prank(advertiser);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    // attribution provider tries to set to ACTIVE from COMPLETED (should fail)
    vm.prank(spdApSigner);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);
  }

  function test_attributionProviderCannotSetActiveFromCreated() public {
    // Create campaign without setting to CAMPAIGN_READY
    vm.prank(advertiser);
    (uint256 newCampaignId, address campaignBalanceAddress, uint8[] memory conversionEventIds) = fwCampaigns
      .createCampaign(
        address(dummyToken),
        spdApId,
        false, // don't set to CAMPAIGN_READY during creation
        campaignMetadataUrl1,
        dummyConversionEvents1,
        emptyPubAllowlist1
      );

    // Attribution Provider tries to set to ACTIVE from CREATED (should fail)
    vm.prank(spdApSigner);
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(newCampaignId, IFlywheelCampaigns.CampaignStatus.ACTIVE);
  }

  function test_cannotSetBackToCreated() public {
    // Create campaign in CAMPAIGN_READY state
    vm.startPrank(advertiser);
    (uint256 newCampaignId, address campaignBalanceAddress, uint8[] memory conversionEventIds) = fwCampaigns
      .createCampaign(
        address(dummyToken),
        spdApId,
        true, // set to CAMPAIGN_READY during creation
        campaignMetadataUrl1,
        dummyConversionEvents1,
        emptyPubAllowlist1
      );

    // Try to set back to CREATED (should fail)
    vm.expectRevert(IFlywheelCampaigns.InvalidStatusTransition.selector);
    fwCampaigns.updateCampaignStatus(newCampaignId, IFlywheelCampaigns.CampaignStatus.CREATED);
    vm.stopPrank();
  }

  function testFuzz_attributeOffchainEvents(uint256 payoutAmount) public {
    // Bound the amount to something reasonable but test edge cases
    payoutAmount = bound(payoutAmount, 1, totalFunded1);

    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: payoutAmount,
      recipientType: 1,
      publisherRefCode: "1",
      clickId: "123",
      timestamp: 1734565000
    });

    fwCampaigns.attributeOffchainEvents(campaignId1, events);

    // Verify attribution was recorded correctly
    assertEq(fwCampaigns.getRecipientBalance(campaignId1, address(0x123)), payoutAmount);
  }

  function testFuzz_multipleRecipientAttribution(uint256[3] memory amounts, address[3] memory recipients) public {
    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    // Ensure unique valid addresses
    vm.assume(recipients[0] != address(0) && recipients[1] != address(0) && recipients[2] != address(0));
    vm.assume(recipients[0] != recipients[1] && recipients[1] != recipients[2] && recipients[0] != recipients[2]);

    // Bound amounts to ensure they don't exceed total funded amount
    uint256 maxAmount = totalFunded1 / 3; // Split total among 3 recipients
    amounts[0] = bound(amounts[0], 1, maxAmount);
    amounts[1] = bound(amounts[1], 1, maxAmount);
    amounts[2] = bound(amounts[2], 1, maxAmount);

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](3);
    for (uint i = 0; i < 3; i++) {
      events[i] = IFlywheelCampaigns.OffchainEvent({
        conversionConfigId: 1,
        eventId: bytes16(0x1234567890abcdef1234567890abcdef),
        payoutAddress: recipients[i],
        payoutAmount: amounts[i],
        recipientType: 1,
        publisherRefCode: "test",
        clickId: "123",
        timestamp: 1734565000
      });
    }

    fwCampaigns.attributeOffchainEvents(campaignId1, events);

    // Verify balances
    for (uint i = 0; i < 3; i++) {
      assertEq(fwCampaigns.getRecipientBalance(campaignId1, recipients[i]), amounts[i]);
    }

    // Verify total attributed doesn't exceed funded amount
    (, , , , , , , , uint256 totalAllocated, , ) = fwCampaigns.campaigns(campaignId1);
    assertLe(totalAllocated, totalFunded1);
  }

  function testFuzz_claimRewards(uint256 amount, address recipient, address to) public {
    vm.assume(recipient != address(0) && to != address(0));
    uint256 originalAmount = amount;
    amount = bound(amount, 1, totalFunded1);

    console.log("Testing with amount:", amount);
    console.log("Testing with recipient:", recipient);
    console.log("Testing with to:", to);

    // Store initial balances
    uint256 initialRecipientBalance = dummyToken.balanceOf(recipient);
    uint256 initialToBalance = dummyToken.balanceOf(to);
    uint256 initialCampaignBalance = dummyToken.balanceOf(campaignBalanceAddress1);

    // Setup - attribute some rewards
    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient,
      payoutAmount: amount,
      recipientType: 1,
      publisherRefCode: "test",
      clickId: "123",
      timestamp: 1734565000
    });

    fwCampaigns.attributeOffchainEvents(campaignId1, events);

    // Verify state after attribution
    assertEq(
      fwCampaigns.getRecipientBalance(campaignId1, recipient),
      amount,
      "Recipient balance should equal attributed amount"
    );
    assertEq(fwCampaigns.getRecipientClaimed(campaignId1, recipient), 0, "Recipient claimed should be 0 before claim");

    // Verify campaign state after attribution
    (
      IFlywheelCampaigns.CampaignStatus status,
      address campaignBalanceAddress,
      address tokenAddress,
      ,
      ,
      ,
      ,
      uint256 totalAmountClaimed,
      uint256 totalAmountAllocated,
      uint256 _protocolFeesBalance,
      bool _isAllowlistSet
    ) = fwCampaigns.campaigns(campaignId1);

    assertEq(uint8(status), uint8(IFlywheelCampaigns.CampaignStatus.ACTIVE), "Campaign should be active");
    assertEq(totalAmountClaimed, 0, "Total claimed should be 0 before any claims");
    assertEq(totalAmountAllocated, amount, "Total attributed should equal attribution amount");
    assertEq(
      dummyToken.balanceOf(campaignBalanceAddress1),
      initialCampaignBalance,
      "Campaign balance shouldn't change after attribution"
    );
    vm.stopPrank();

    // Claim rewards
    vm.startPrank(recipient);
    uint256[] memory campaignIds = new uint256[](1);
    campaignIds[0] = campaignId1;

    uint256 preClaimBalance = dummyToken.balanceOf(to);
    uint256 preCampaignBalance = dummyToken.balanceOf(campaignBalanceAddress1);

    // Expect ClaimedRewards event to be emitted with correct parameters
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.ClaimedRewards(campaignId1, recipient, amount, to);

    fwCampaigns.claimRewards(campaignIds, to);

    // Verify balances after claim
    assertEq(dummyToken.balanceOf(to) - preClaimBalance, amount, "To address should receive exact attributed amount");
    assertEq(
      dummyToken.balanceOf(campaignBalanceAddress1),
      preCampaignBalance - amount,
      "Campaign balance should decrease by claimed amount"
    );
    assertEq(fwCampaigns.getRecipientBalance(campaignId1, recipient), 0, "Recipient balance should be 0 after claim");
    assertEq(
      fwCampaigns.getRecipientClaimed(campaignId1, recipient),
      amount,
      "Recipient claimed should equal attributed amount"
    );

    // Verify final campaign state
    (
      ,
      ,
      ,
      ,
      ,
      ,
      ,
      uint256 finalTotalAmountClaimed,
      uint256 finaltotalAmountAllocated,
      uint256 finalprotocolFeesBalance,
      bool finalIsAllowlistSet
    ) = fwCampaigns.campaigns(campaignId1);

    assertEq(finalTotalAmountClaimed, amount, "Campaign total claimed should equal attributed amount");
    assertEq(finaltotalAmountAllocated, amount, "Campaign total attributed should remain unchanged");
    assertEq(finalprotocolFeesBalance, 0, "Accumulated protocol fees should be 0");

    // Try to claim again (should result in no transfer)
    uint256 balanceBeforeSecondClaim = dummyToken.balanceOf(to);
    fwCampaigns.claimRewards(campaignIds, to);
    assertEq(dummyToken.balanceOf(to), balanceBeforeSecondClaim, "Balance should not change on second claim attempt");
    vm.stopPrank();
  }

  function testFuzz_fullFlow_balances_both_token_types(
    uint256 attributeAmount1,
    uint256 attributeAmount2,
    uint256 offchainAmount3,
    uint256 onchainAmount3,
    bool useNativeToken
  ) public {
    // Setup campaign based on token type
    if (!useNativeToken) {
      _runFullFlowTest(attributeAmount1, attributeAmount2, offchainAmount3, onchainAmount3, address(dummyToken));
    } else {
      _runFullFlowTest(attributeAmount1, attributeAmount2, offchainAmount3, onchainAmount3, address(0));
    }
  }

  function _runFullFlowTest(
    uint256 attributeAmount1,
    uint256 attributeAmount2,
    uint256 offchainAmount3,
    uint256 onchainAmount3,
    address tokenAddress
  ) internal {
    // Create and fund new campaign
    (address _campaignBalanceAddress, uint256 _campaignId) = _createAndFundCampaign(
      tokenAddress,
      spdApId,
      totalFunded1,
      true
    );

    // Setup recipients
    address recipient1 = address(0x123);
    address recipient2 = address(0x456);
    address recipient3 = address(0x789);

    // Store initial balances
    uint256 initialAdvertiserBalance = getBalance(advertiser, tokenAddress);
    uint256 initialCampaignBalance = getBalance(_campaignBalanceAddress, tokenAddress);

    // Bound all attribution amounts to prevent overattribution
    attributeAmount1 = bound(attributeAmount1, 100, totalFunded1 / 4);
    attributeAmount2 = bound(attributeAmount2, 100, totalFunded1 / 4);
    offchainAmount3 = bound(offchainAmount3, 100, totalFunded1 / 4);
    onchainAmount3 = bound(onchainAmount3, 100, totalFunded1 / 4);

    // Log the bounded amounts
    console.log("Bounded Attribution Amount 1:", attributeAmount1);
    console.log("Bounded Attribution Amount 2:", attributeAmount2);
    console.log("Bounded Recipient 3 Offchain Amount:", offchainAmount3);
    console.log("Bounded Recipient 3 Onchain Amount:", onchainAmount3);
    console.log("Total Campaign Balance:", initialCampaignBalance);

    // Verify total attribution won't exceed campaign balance
    uint256 totalAttribution = attributeAmount1 + attributeAmount2 + offchainAmount3 + onchainAmount3;
    require(totalAttribution <= initialCampaignBalance, "Total attribution would exceed campaign balance");

    // Perform attributions
    _performAttributions(
      _campaignId,
      tokenAddress,
      attributeAmount1,
      attributeAmount2,
      offchainAmount3,
      onchainAmount3,
      recipient1,
      recipient2,
      recipient3
    );

    // Verify state after attributions
    assertEq(
      getBalance(_campaignBalanceAddress, tokenAddress),
      initialCampaignBalance,
      "Campaign balance should not change after attributions"
    );
    assertEq(
      fwCampaigns.getRecipientBalance(_campaignId, recipient1),
      attributeAmount1,
      "Recipient1 balance incorrect after attribution"
    );
    assertEq(
      fwCampaigns.getRecipientBalance(_campaignId, recipient2),
      attributeAmount2,
      "Recipient2 balance incorrect after attribution"
    );
    assertEq(
      fwCampaigns.getRecipientBalance(_campaignId, recipient3),
      offchainAmount3 + onchainAmount3,
      "Recipient3 balance should equal sum of offchain and onchain attributions"
    );

    // Verify campaign state after attributions
    (
      IFlywheelCampaigns.CampaignStatus status,
      ,
      ,
      ,
      ,
      ,
      ,
      uint256 totalAmountClaimed,
      uint256 totalAmountAllocated,
      uint256 protocolFeesBalance,
      bool isAllowlistSet
    ) = fwCampaigns.campaigns(_campaignId);

    assertEq(uint8(status), uint8(IFlywheelCampaigns.CampaignStatus.ACTIVE), "Campaign should be active");
    assertEq(totalAmountClaimed, 0, "Nothing should be claimed yet");
    assertEq(
      totalAmountAllocated,
      attributeAmount1 + attributeAmount2 + offchainAmount3 + onchainAmount3,
      "Total attributed should equal sum of all attributions"
    );

    // Perform claims
    _performClaims(_campaignId, tokenAddress, attributeAmount1, attributeAmount2, recipient1, recipient2);

    // Verify state after claims
    assertEq(fwCampaigns.getRecipientBalance(_campaignId, recipient1), 0, "Recipient1 balance should be 0 after claim");
    assertEq(fwCampaigns.getRecipientBalance(_campaignId, recipient2), 0, "Recipient2 balance should be 0 after claim");
    assertEq(
      fwCampaigns.getRecipientClaimed(_campaignId, recipient1),
      attributeAmount1,
      "Recipient1 claimed amount incorrect"
    );
    assertEq(
      fwCampaigns.getRecipientClaimed(_campaignId, recipient2),
      attributeAmount2,
      "Recipient2 claimed amount incorrect"
    );
    assertEq(
      fwCampaigns.getRecipientBalance(_campaignId, recipient3),
      offchainAmount3 + onchainAmount3,
      "Recipient3 balance should remain unchanged"
    );

    // Complete campaign and withdraw
    vm.prank(advertiser);
    fwCampaigns.updateCampaignStatus(_campaignId, IFlywheelCampaigns.CampaignStatus.PENDING_COMPLETION);

    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(_campaignId, IFlywheelCampaigns.CampaignStatus.COMPLETED);

    uint256 remainingBalance = initialCampaignBalance -
      (attributeAmount1 + attributeAmount2 + offchainAmount3 + onchainAmount3);
    uint256 preWithdrawBalance = getBalance(advertiser, tokenAddress);

    vm.prank(advertiser);
    fwCampaigns.withdrawRemainingBalance(_campaignId, advertiser);

    // Verify final state after withdrawal
    assertEq(
      getBalance(advertiser, tokenAddress),
      preWithdrawBalance + remainingBalance,
      "Advertiser should receive exact remaining balance"
    );
    assertEq(
      getBalance(_campaignBalanceAddress, tokenAddress),
      offchainAmount3 + onchainAmount3,
      "Campaign balance should only contain recipient3's unclaimed amount"
    );

    // Verify final campaign state
    (status, , , , , , , totalAmountClaimed, totalAmountAllocated, protocolFeesBalance, isAllowlistSet) = fwCampaigns
      .campaigns(_campaignId);

    assertEq(uint8(status), uint8(IFlywheelCampaigns.CampaignStatus.COMPLETED), "Campaign should be completed");
    assertEq(
      totalAmountClaimed,
      attributeAmount1 + attributeAmount2 + remainingBalance,
      "Total claimed should include recipient claims and withdrawal"
    );
    assertEq(
      totalAmountAllocated,
      attributeAmount1 + attributeAmount2 + offchainAmount3 + onchainAmount3 + remainingBalance,
      "Total attributed should include all attributions plus remaining balance"
    );
    assertEq(protocolFeesBalance, 0, "Accumulated protocol fees should be 0");

    // Verify conservation of funds
    assertEq(
      getBalance(recipient1, tokenAddress) +
        getBalance(recipient2, tokenAddress) +
        getBalance(_campaignBalanceAddress, tokenAddress) + // Contains recipient3's unclaimed
        (getBalance(advertiser, tokenAddress) - preWithdrawBalance), // Only count what advertiser got back
      initialCampaignBalance,
      "Sum of all balances should equal initial campaign balance"
    );

    // For native ETH, verify contract doesn't hold any funds
    if (tokenAddress == address(0)) {
      assertEq(address(fwCampaigns).balance, 0, "Main contract should not hold any ETH");
    } else {
      assertEq(dummyToken.balanceOf(address(fwCampaigns)), 0, "Main contract should not hold any ERC20");
    }
  }

  // Break out the attribution logic into a separate function
  function _performAttributions(
    uint256 _campaignId,
    address tokenAddress,
    uint256 attributeAmount1,
    uint256 attributeAmount2,
    uint256 offchainAmount3,
    uint256 onchainAmount3,
    address recipient1,
    address recipient2,
    address recipient3
  ) internal {
    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(_campaignId, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    // First attribution batch
    IFlywheelCampaigns.OffchainEvent[] memory offchainEvents = new IFlywheelCampaigns.OffchainEvent[](2);
    offchainEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient1,
      payoutAmount: attributeAmount1,
      recipientType: 1,
      publisherRefCode: "test1",
      clickId: "123",
      timestamp: 1734565000
    });
    offchainEvents[1] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient3,
      payoutAmount: offchainAmount3,
      recipientType: 1,
      publisherRefCode: "test3",
      clickId: "456",
      timestamp: 1734565000
    });
    fwCampaigns.attributeOffchainEvents(_campaignId, offchainEvents);

    // Second attribution
    IFlywheelCampaigns.OffchainEvent[] memory singleEvent = new IFlywheelCampaigns.OffchainEvent[](1);
    singleEvent[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient2,
      payoutAmount: attributeAmount2,
      recipientType: 1,
      publisherRefCode: "test2",
      clickId: "123",
      timestamp: 1734565000
    });
    fwCampaigns.attributeOffchainEvents(_campaignId, singleEvent);

    // Onchain attribution
    IFlywheelCampaigns.OnchainEvent[] memory onchainEvents = new IFlywheelCampaigns.OnchainEvent[](1);
    onchainEvents[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 2,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient3,
      payoutAmount: onchainAmount3,
      recipientType: 1,
      publisherRefCode: "test3",
      clickId: "789",
      userAddress: address(0x999),
      timestamp: 1734565100,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 1
    });
    fwCampaigns.attributeOnchainEvents(_campaignId, onchainEvents);
    vm.stopPrank();
  }

  // Break out the claims logic into a separate function
  function _performClaims(
    uint256 _campaignId,
    address tokenAddress,
    uint256 attributeAmount1,
    uint256 attributeAmount2,
    address recipient1,
    address recipient2
  ) internal {
    uint256[] memory campaignIds = new uint256[](1);
    campaignIds[0] = _campaignId;

    // First recipient claims
    vm.startPrank(recipient1);
    uint256 preClaimBalance1 = getBalance(recipient1, tokenAddress);
    fwCampaigns.claimRewards(campaignIds, recipient1);
    assertEq(
      getBalance(recipient1, tokenAddress) - preClaimBalance1,
      attributeAmount1,
      "Recipient1 should receive exact attributed amount after claiming"
    );
    vm.stopPrank();

    // Second recipient claims
    vm.startPrank(recipient2);
    uint256 preClaimBalance2 = getBalance(recipient2, tokenAddress);
    fwCampaigns.claimRewards(campaignIds, recipient2);
    assertEq(
      getBalance(recipient2, tokenAddress) - preClaimBalance2,
      attributeAmount2,
      "Recipient2 should receive exact attributed amount after claiming"
    );
    vm.stopPrank();
  }

  function testFuzz_cannotOverattribute_both_token_types(
    uint256 validAmount,
    uint256 overflowAmount,
    bool useNativeToken
  ) public {
    // Setup campaign based on token type
    if (!useNativeToken) {
      _runOverattributionTest(validAmount, overflowAmount, address(dummyToken));
    } else {
      _runOverattributionTest(validAmount, overflowAmount, address(0));
    }
  }

  function _runOverattributionTest(uint256 validAmount, uint256 overflowAmount, address tokenAddress) internal {
    // Create and fund new campaign with proper funding for token type
    if (tokenAddress == address(0)) {
      // For native ETH, ensure both test contract and advertiser have enough ETH
      vm.deal(address(this), totalFunded1);
      vm.deal(advertiser, totalFunded1);
    }

    (address _campaignBalanceAddress, uint256 _campaignId) = _createAndFundCampaign(
      tokenAddress,
      spdApId,
      totalFunded1,
      true
    );

    // Store initial balances
    uint256 initialCampaignBalance = getBalance(_campaignBalanceAddress, tokenAddress);
    require(initialCampaignBalance == totalFunded1, "Campaign not funded correctly");

    // Bound valid amount to be less than total funded but significant
    validAmount = bound(validAmount, totalFunded1 / 4, totalFunded1 / 2);

    // Calculate remaining balance after valid attribution
    uint256 remainingBalance = initialCampaignBalance - validAmount;

    // Ensure overflow amount is definitely larger than remaining balance
    overflowAmount = remainingBalance + bound(overflowAmount, 1, remainingBalance);

    console.log("Token type:", tokenAddress == address(0) ? "Native ETH" : "ERC20");
    console.log("Initial campaign balance:", initialCampaignBalance);
    console.log("Valid attribution amount:", validAmount);
    console.log("Remaining balance:", remainingBalance);
    console.log("Overflow attempt amount:", overflowAmount);

    // First do a valid attribution
    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(_campaignId, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OffchainEvent[] memory validEvents = new IFlywheelCampaigns.OffchainEvent[](1);
    validEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: validAmount,
      recipientType: 1,
      publisherRefCode: "test1",
      clickId: "123",
      timestamp: 1734565000
    });

    // Valid attribution should succeed
    fwCampaigns.attributeOffchainEvents(_campaignId, validEvents);

    // Verify valid attribution state
    assertEq(
      fwCampaigns.getRecipientBalance(_campaignId, address(0x123)),
      validAmount,
      "First attribution should succeed"
    );
    assertEq(
      getBalance(_campaignBalanceAddress, tokenAddress),
      initialCampaignBalance,
      "Campaign balance should not change after attribution"
    );

    // Try to attribute more than remaining balance
    IFlywheelCampaigns.OffchainEvent[] memory overflowEvents = new IFlywheelCampaigns.OffchainEvent[](1);
    overflowEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x456),
      payoutAmount: overflowAmount,
      recipientType: 1,
      publisherRefCode: "test2",
      clickId: "456",
      timestamp: 1734565000
    });

    // Attempt overflow attribution - should revert
    vm.expectRevert(IFlywheelCampaigns.CannotOverAttribute.selector);
    fwCampaigns.attributeOffchainEvents(_campaignId, overflowEvents);

    // Try onchain overflow too
    IFlywheelCampaigns.OnchainEvent[] memory overflowOnchainEvents = new IFlywheelCampaigns.OnchainEvent[](1);
    overflowOnchainEvents[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 2,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x456),
      payoutAmount: overflowAmount,
      recipientType: 1,
      publisherRefCode: "test2",
      clickId: "456",
      userAddress: address(0x999),
      timestamp: 1734565000,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 1
    });

    // Attempt overflow attribution - should revert
    vm.expectRevert(IFlywheelCampaigns.CannotOverAttribute.selector);
    fwCampaigns.attributeOnchainEvents(_campaignId, overflowOnchainEvents);

    // Verify final state is unchanged
    assertEq(
      getBalance(_campaignBalanceAddress, tokenAddress),
      initialCampaignBalance,
      "Campaign balance should remain unchanged after failed attributions"
    );
    assertEq(
      fwCampaigns.getRecipientBalance(_campaignId, address(0x123)),
      validAmount,
      "Original attribution should remain unchanged"
    );
    assertEq(
      fwCampaigns.getRecipientBalance(_campaignId, address(0x456)),
      0,
      "Failed attribution recipient should have 0 balance"
    );

    // Verify campaign totals
    (, , , , , , , uint256 totalAmountClaimed, uint256 totalAmountAllocated, , ) = fwCampaigns.campaigns(_campaignId);

    assertEq(totalAmountClaimed, 0, "Nothing should be claimed");
    assertEq(totalAmountAllocated, validAmount, "Only valid attribution should be counted");
    vm.stopPrank();
  }

  function testFuzz_pushRewards_both_token_types(
    uint8 numRecipients, // Use uint8 to control array size
    uint256 seed, // Use seed for generating addresses
    bool useNativeToken,
    bool useAttributionProvider
  ) public {
    // Bound number of recipients between 1 and 3
    numRecipients = uint8(bound(uint256(numRecipients), 1, 3));

    // Create arrays
    uint256[] memory amounts = new uint256[](numRecipients);
    address[] memory recipients = new address[](numRecipients);

    // Use seed to generate deterministic but different addresses
    for (uint i = 0; i < numRecipients; i++) {
      // Generate unique addresses using seed and index
      recipients[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))));
      // Ensure generated address is valid
      vm.assume(recipients[i] != address(0));
      vm.assume(recipients[i] != address(this));
      vm.assume(recipients[i] != address(fwCampaigns));
      vm.assume(recipients[i] != advertiser);
      vm.assume(recipients[i] != spdApSigner);
    }

    // Setup campaign based on token type
    if (!useNativeToken) {
      _runPushRewardsTest(amounts, recipients, address(dummyToken), useAttributionProvider);
    } else {
      _runPushRewardsTest(amounts, recipients, address(0), useAttributionProvider);
    }
  }

  function _runPushRewardsTest(
    uint256[] memory amounts,
    address[] memory recipients,
    address tokenAddress,
    bool useAttributionProvider
  ) internal {
    // Create and fund campaign
    uint256 totalAmount = 0;
    uint256[] memory boundedAmounts = new uint256[](amounts.length);

    // Bound each amount and calculate total
    for (uint i = 0; i < amounts.length; i++) {
      // Use a smaller maximum to prevent overflow
      uint256 maxAmount = totalFunded1 / (2 * amounts.length); // Divide by 2*length to ensure we don't exceed total
      boundedAmounts[i] = bound(amounts[i], 100, maxAmount);
      totalAmount += boundedAmounts[i];
    }

    // Create and fund the campaign
    (address _campaignBalanceAddress, uint256 _campaignId) = _createAndFundCampaign(
      tokenAddress,
      spdApId,
      totalFunded1,
      true
    );

    // Store initial balances
    uint256[] memory initialBalances = new uint256[](recipients.length);
    for (uint i = 0; i < recipients.length; i++) {
      initialBalances[i] = getBalance(recipients[i], tokenAddress);
    }

    // Attribute rewards to recipients
    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(_campaignId, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](recipients.length);
    for (uint i = 0; i < recipients.length; i++) {
      events[i] = IFlywheelCampaigns.OffchainEvent({
        conversionConfigId: 1,
        eventId: bytes16(0x1234567890abcdef1234567890abcdef),
        payoutAddress: recipients[i],
        payoutAmount: boundedAmounts[i],
        recipientType: 1,
        publisherRefCode: "test",
        clickId: "123",
        timestamp: 1734565000
      });
    }

    fwCampaigns.attributeOffchainEvents(_campaignId, events);
    vm.stopPrank();

    // Verify initial attribution state
    for (uint i = 0; i < recipients.length; i++) {
      uint256 recipientBalance = fwCampaigns.getRecipientBalance(_campaignId, recipients[i]);
      assertEq(
        recipientBalance,
        boundedAmounts[i],
        string.concat("Initial attribution incorrect for recipient ", vm.toString(i))
      );
    }

    // Push rewards using either attribution provider or advertiser
    if (useAttributionProvider) {
      vm.prank(spdApSigner);
    } else {
      vm.prank(advertiser);
    }
    fwCampaigns.pushRewards(_campaignId, recipients);

    // Verify final balances and state
    for (uint i = 0; i < recipients.length; i++) {
      // Check recipient received correct amount
      assertEq(
        getBalance(recipients[i], tokenAddress) - initialBalances[i],
        boundedAmounts[i],
        "Recipient did not receive correct amount"
      );

      // Check recipient balance is now 0
      assertEq(
        fwCampaigns.getRecipientBalance(_campaignId, recipients[i]),
        0,
        "Recipient balance not zeroed after push"
      );

      // Check claimed amount is correct
      assertEq(
        fwCampaigns.getRecipientClaimed(_campaignId, recipients[i]),
        boundedAmounts[i],
        "Claimed amount incorrect"
      );
    }

    // Verify campaign totals
    (, , , , , , , uint256 totalAmountClaimed, uint256 totalAmountAllocated, , ) = fwCampaigns.campaigns(_campaignId);
    assertEq(totalAmountClaimed, totalAmount, "Total claimed amount incorrect");
    assertEq(totalAmountAllocated, totalAmount, "Total attributed amount incorrect");

    // Try to push rewards again with the same role
    if (useAttributionProvider) {
      vm.prank(spdApSigner);
    } else {
      vm.prank(advertiser);
    }
    fwCampaigns.pushRewards(_campaignId, recipients);

    // Verify balances don't change after second push
    for (uint i = 0; i < recipients.length; i++) {
      // Compare against final balance after first push, not initial balance
      uint256 expectedBalance = initialBalances[i] + boundedAmounts[i];
      assertEq(getBalance(recipients[i], tokenAddress), expectedBalance, "Balance should not change on second push");
    }
  }

  function testFuzz_pushRewards_unauthorized(address unauthorizedCaller) public {
    // Simplify unauthorized caller assumptions
    vm.assume(unauthorizedCaller != address(0));
    vm.assume(unauthorizedCaller != advertiser);
    vm.assume(unauthorizedCaller != spdApSigner);
    vm.assume(unauthorizedCaller != address(fwCampaigns));

    // Create campaign with minimal setup
    (address _campaignBalanceAddress, uint256 _campaignId) = _createAndFundCampaign(
      address(dummyToken),
      spdApId,
      1000, // Use smaller fixed amount
      true
    );

    // Attribute a simple reward
    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(_campaignId, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    address recipient = address(0x123);
    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient,
      payoutAmount: 100, // Use smaller fixed amount
      recipientType: 1,
      publisherRefCode: "test",
      clickId: "123",
      timestamp: 1734565000
    });

    fwCampaigns.attributeOffchainEvents(_campaignId, events);
    vm.stopPrank();

    // Try to push rewards as unauthorized caller
    vm.prank(unauthorizedCaller);
    address[] memory recipients = new address[](1);
    recipients[0] = recipient;
    vm.expectRevert(IFlywheelCampaigns.Unauthorized.selector);
    fwCampaigns.pushRewards(_campaignId, recipients);
  }

  // Add specific tests for attribution provider and advertiser roles
  function test_pushRewards_attribution_provider() public {
    address recipient = address(0x123);
    uint256 amount = 1000;

    // Setup and fund campaign
    (address _campaignBalanceAddress, uint256 _campaignId) = _createAndFundCampaign(
      address(dummyToken),
      spdApId,
      totalFunded1,
      true
    );

    // Attribute rewards
    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(_campaignId, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient,
      payoutAmount: amount,
      recipientType: 1,
      publisherRefCode: "test",
      clickId: "123",
      timestamp: 1734565000
    });

    fwCampaigns.attributeOffchainEvents(_campaignId, events);

    // Push rewards as attribution provider
    address[] memory recipients = new address[](1);
    recipients[0] = recipient;
    fwCampaigns.pushRewards(_campaignId, recipients);
    vm.stopPrank();

    // Verify rewards were pushed
    assertEq(fwCampaigns.getRecipientBalance(_campaignId, recipient), 0);
    assertEq(fwCampaigns.getRecipientClaimed(_campaignId, recipient), amount);
  }

  function test_pushRewards_advertiser() public {
    address recipient = address(0x123);
    uint256 amount = 1000;

    // Setup and fund campaign
    (address _campaignBalanceAddress, uint256 _campaignId) = _createAndFundCampaign(
      address(dummyToken),
      spdApId,
      totalFunded1,
      true
    );

    // Attribute rewards
    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(_campaignId, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: recipient,
      payoutAmount: amount,
      recipientType: 1,
      publisherRefCode: "test",
      clickId: "123",
      timestamp: 1734565000
    });

    fwCampaigns.attributeOffchainEvents(_campaignId, events);
    vm.stopPrank();

    // Push rewards as advertiser
    vm.startPrank(advertiser);
    address[] memory recipients = new address[](1);
    recipients[0] = recipient;
    fwCampaigns.pushRewards(_campaignId, recipients);
    vm.stopPrank();

    // Verify rewards were pushed
    assertEq(fwCampaigns.getRecipientBalance(_campaignId, recipient), 0);
    assertEq(fwCampaigns.getRecipientClaimed(_campaignId, recipient), amount);
  }

  // HELPER FUNCTIONS ***********************************************************

  // Update _createAndFundCampaign to handle native ETH
  function _createAndFundCampaign(
    address tokenAddress,
    uint256 attributionProviderId,
    uint256 fundAmount,
    bool setToCampaignReady
  ) private returns (address payoutAddress, uint256 campaignId) {
    vm.startPrank(advertiser);

    // Create campaign
    (uint256 _campaignId, address _campaignBalanceAddress, uint8[] memory conversionEventIds) = fwCampaigns
      .createCampaign(
        tokenAddress,
        attributionProviderId,
        setToCampaignReady,
        campaignMetadataUrl1,
        dummyConversionEvents1,
        emptyPubAllowlist1
      );

    // Fund the campaign
    if (tokenAddress == address(0)) {
      // For native ETH
      vm.deal(advertiser, fundAmount); // Ensure advertiser has enough ETH
      (bool success, ) = _campaignBalanceAddress.call{ value: fundAmount }("");
      require(success, "ETH transfer failed");
    } else {
      // For ERC20
      dummyToken.transfer(_campaignBalanceAddress, fundAmount);
    }

    vm.stopPrank();
    return (_campaignBalanceAddress, _campaignId);
  }

  // Create a helper function to get balance based on token type
  function getBalance(address account, address tokenAddress) internal view returns (uint256) {
    if (tokenAddress == address(0)) {
      return account.balance;
    } else {
      return dummyToken.balanceOf(account);
    }
  }

  // Add these tests after the existing tests

  function test_updateProtocolFee() public {
    // Only owner can update protocol fee
    vm.startPrank(owner);

    uint16 newFee = 500; // 5.00%
    fwCampaigns.updateProtocolFee(newFee);
    assertEq(fwCampaigns.protocolFee(), newFee);

    // Cannot set fee >= 100%
    vm.expectRevert(IFlywheelCampaigns.InvalidProtocolFee.selector);
    fwCampaigns.updateProtocolFee(10_000); // 100.00%

    vm.expectRevert(IFlywheelCampaigns.InvalidProtocolFee.selector);
    fwCampaigns.updateProtocolFee(10_001); // 100.01%

    vm.stopPrank();

    // Non-owner cannot update fee
    vm.prank(address(0x123));
    vm.expectRevert(); // Just expect any revert without specifying the error
    fwCampaigns.updateProtocolFee(100);
  }

  function test_protocolFeeCalculation() public {
    // Set protocol fee to 10% (1000 basis points)
    vm.prank(owner);
    fwCampaigns.updateProtocolFee(1000);

    // Test fee calculation with different amounts
    assertEq(fwCampaigns.calculateProtocolFeeAmount(1000), 100); // 10% of 1000 is 100
    assertEq(fwCampaigns.calculateProtocolFeeAmount(0), 0); // 10% of 0 is 0
    assertEq(fwCampaigns.calculateProtocolFeeAmount(10_000), 1000); // 10% of 10000 is 1000
  }

  function test_protocolFeeOnchainAttribution() public {
    // Set protocol fee to 5%
    vm.prank(owner);
    fwCampaigns.updateProtocolFee(500);

    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    uint256 attributionAmount = 5000;
    uint256 expectedFee = 250; // 5% of 5000
    uint256 expectedAmountAfterFee = 4750;

    IFlywheelCampaigns.OnchainEvent[] memory events = new IFlywheelCampaigns.OnchainEvent[](1);
    events[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: attributionAmount,
      recipientType: 1,
      publisherRefCode: "test",
      clickId: "123",
      userAddress: address(0x999),
      timestamp: 1734565000,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 1
    });

    // Expect event with protocol fee
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.OnchainConversion(
      campaignId1,
      events[0].publisherRefCode,
      events[0].conversionConfigId,
      events[0].eventId,
      events[0].payoutAddress,
      expectedAmountAfterFee, // amountAfterFee
      expectedFee, // protocolFeeAmount
      events[0].recipientType,
      events[0].clickId,
      events[0].userAddress,
      events[0].timestamp,
      events[0].txHash,
      events[0].txChainId,
      events[0].txEventLogIndex
    );

    fwCampaigns.attributeOnchainEvents(campaignId1, events);

    // Verify recipient gets amount after fee
    assertEq(
      fwCampaigns.getRecipientBalance(campaignId1, address(0x123)),
      expectedAmountAfterFee,
      "Recipient should receive amount minus fee"
    );

    // Verify accumulated protocol fees
    assertEq(fwCampaigns.getAvailableProtocolFees(campaignId1), expectedFee, "Protocol fees should be accumulated");

    vm.stopPrank();
  }

  function test_protocolFeeOffchainAttribution() public {
    // Set protocol fee to 10%
    vm.prank(owner);
    fwCampaigns.updateProtocolFee(1000);

    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    uint256 attributionAmount = 5000;
    uint256 expectedFee = 500; // 10% of 5000
    uint256 expectedAmountAfterFee = 4500;

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: attributionAmount,
      recipientType: 1,
      publisherRefCode: "test",
      clickId: "123",
      timestamp: 1734565000
    });

    // Expect event with protocol fee
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.OffchainConversion(
      campaignId1,
      events[0].publisherRefCode,
      events[0].conversionConfigId,
      events[0].eventId,
      events[0].payoutAddress,
      expectedAmountAfterFee, // amountAfterFee
      expectedFee, // protocolFeeAmount
      events[0].recipientType,
      events[0].clickId,
      events[0].timestamp
    );

    fwCampaigns.attributeOffchainEvents(campaignId1, events);

    // Verify recipient gets amount after fee
    assertEq(
      fwCampaigns.getRecipientBalance(campaignId1, address(0x123)),
      expectedAmountAfterFee,
      "Recipient should receive amount minus fee"
    );

    // Verify accumulated protocol fees
    assertEq(fwCampaigns.getAvailableProtocolFees(campaignId1), expectedFee, "Protocol fees should be accumulated");

    vm.stopPrank();
  }

  function test_claimProtocolFees() public {
    // Set protocol fee and attribute some rewards
    vm.prank(owner);
    fwCampaigns.updateProtocolFee(1000); // 10%

    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    IFlywheelCampaigns.OffchainEvent[] memory events = new IFlywheelCampaigns.OffchainEvent[](1);
    events[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: 1000,
      recipientType: 1,
      publisherRefCode: "test",
      clickId: "123",
      timestamp: 1734565000
    });

    fwCampaigns.attributeOffchainEvents(campaignId1, events);
    vm.stopPrank();

    uint256 expectedFee = 100; // 10% of 1000
    uint256 initialTreasuryBalance = dummyToken.balanceOf(treasury);

    // Only treasury can withdraw fees
    vm.prank(owner);
    vm.expectRevert(IFlywheelCampaigns.Unauthorized.selector);
    uint256[] memory campaignIds = new uint256[](1);
    campaignIds[0] = campaignId1;
    fwCampaigns.claimProtocolFees(campaignIds);

    // Treasury withdraws fees
    vm.prank(treasury);
    vm.expectEmit(true, true, true, true);
    emit IFlywheelCampaigns.ProtocolFeesWithdrawn(campaignId1, expectedFee, treasury);
    fwCampaigns.claimProtocolFees(campaignIds);

    // Verify balances and state
    assertEq(
      dummyToken.balanceOf(treasury),
      initialTreasuryBalance + expectedFee,
      "Treasury should receive protocol fees"
    );
    assertEq(fwCampaigns.getAvailableProtocolFees(campaignId1), 0, "Available fees should be 0 after withdrawal");

    // Second withdrawal should not transfer anything
    vm.prank(treasury);
    fwCampaigns.claimProtocolFees(campaignIds);
    assertEq(
      dummyToken.balanceOf(treasury),
      initialTreasuryBalance + expectedFee,
      "Second withdrawal should not transfer additional funds"
    );
  }

  function testFuzz_protocolFeeCalculation(uint16 fee, uint256 amount) public {
    // Bound fee to valid range (0-99.99%)
    fee = uint16(bound(fee, 0, fwCampaigns.MAX_PROTOCOL_FEE()));
    // Bound amount to reasonable range
    amount = bound(amount, 0, 1_000_000_000 * 10 ** 18);

    vm.prank(owner);
    fwCampaigns.updateProtocolFee(fee);

    uint256 calculatedFee = fwCampaigns.calculateProtocolFeeAmount(amount);

    // Verify fee calculation
    assertEq(calculatedFee, (amount * fee) / fwCampaigns.PROTOCOL_FEE_PRECISION(), "Fee calculation incorrect");

    // Verify fee is never more than original amount
    assertLe(calculatedFee, amount, "Fee should not exceed original amount");

    // If fee is 0, calculated fee should be 0
    if (fee == 0) {
      assertEq(calculatedFee, 0, "Zero fee should result in zero calculation");
    }

    // If amount is 0, calculated fee should be 0
    if (amount == 0) {
      assertEq(calculatedFee, 0, "Zero amount should result in zero fee");
    }
  }

  function testFuzz_protocolFeeAttributionAndWithdraw(uint16 fee, uint256 attributionAmount) public {
    // Bound fee to valid range (0-99.99%)
    fee = uint16(bound(fee, 0, fwCampaigns.MAX_PROTOCOL_FEE()));
    // Bound attribution amount to be less than total funded/2 (since we'll do 2 attributions)
    attributionAmount = bound(attributionAmount, 100, totalFunded1 / 2);

    // Setup
    vm.prank(owner);
    fwCampaigns.updateProtocolFee(fee);

    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    uint256 expectedFee = (attributionAmount * fee) / fwCampaigns.PROTOCOL_FEE_PRECISION();
    uint256 expectedAmountAfterFee = attributionAmount - expectedFee;

    // Create offchain event
    IFlywheelCampaigns.OffchainEvent[] memory offchainEvents = new IFlywheelCampaigns.OffchainEvent[](1);
    offchainEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: attributionAmount,
      recipientType: 1,
      publisherRefCode: "test1",
      clickId: "123",
      timestamp: 1734565000
    });

    // Create onchain event
    IFlywheelCampaigns.OnchainEvent[] memory onchainEvents = new IFlywheelCampaigns.OnchainEvent[](1);
    onchainEvents[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 2,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x456),
      payoutAmount: attributionAmount,
      recipientType: 1,
      publisherRefCode: "test2",
      clickId: "456",
      userAddress: address(0x999),
      timestamp: 1734565100,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 1
    });

    // Attribute both events
    fwCampaigns.attributeOffchainEvents(campaignId1, offchainEvents);
    fwCampaigns.attributeOnchainEvents(campaignId1, onchainEvents);
    vm.stopPrank();

    // Total expected fees from both attributions
    uint256 totalExpectedFee = expectedFee * 2;

    // Verify recipient balances after attribution
    assertEq(
      fwCampaigns.getRecipientBalance(campaignId1, address(0x123)),
      expectedAmountAfterFee,
      "Offchain recipient balance incorrect"
    );
    assertEq(
      fwCampaigns.getRecipientBalance(campaignId1, address(0x456)),
      expectedAmountAfterFee,
      "Onchain recipient balance incorrect"
    );

    // Verify accumulated protocol fees
    assertEq(
      fwCampaigns.getAvailableProtocolFees(campaignId1),
      totalExpectedFee,
      "Accumulated protocol fees incorrect"
    );

    // Treasury withdraws protocol fees
    uint256 initialTreasuryBalance = dummyToken.balanceOf(treasury);
    vm.startPrank(treasury);
    uint256[] memory campaignIds = new uint256[](1);
    campaignIds[0] = campaignId1;
    fwCampaigns.claimProtocolFees(campaignIds);
    vm.stopPrank();

    // Verify treasury received correct amount
    assertEq(
      dummyToken.balanceOf(treasury),
      initialTreasuryBalance + totalExpectedFee,
      "Treasury should receive correct protocol fees"
    );
    assertEq(fwCampaigns.getAvailableProtocolFees(campaignId1), 0, "Protocol fees should be 0 after withdrawal");

    // Recipients claim their rewards
    uint256 initialBalance123 = dummyToken.balanceOf(address(0x123));
    uint256 initialBalance456 = dummyToken.balanceOf(address(0x456));

    // First recipient claims
    vm.prank(address(0x123));
    uint256[] memory claimCampaignIds = new uint256[](1);
    claimCampaignIds[0] = campaignId1;
    fwCampaigns.claimRewards(claimCampaignIds, address(0x123));

    // Second recipient claims
    vm.prank(address(0x456));
    fwCampaigns.claimRewards(claimCampaignIds, address(0x456));

    // Verify final balances
    assertEq(
      dummyToken.balanceOf(address(0x123)),
      initialBalance123 + expectedAmountAfterFee,
      "First recipient should receive correct amount"
    );
    assertEq(
      dummyToken.balanceOf(address(0x456)),
      initialBalance456 + expectedAmountAfterFee,
      "Second recipient should receive correct amount"
    );

    // Verify recipient balances are now 0
    assertEq(
      fwCampaigns.getRecipientBalance(campaignId1, address(0x123)),
      0,
      "First recipient balance should be 0 after claim"
    );
    assertEq(
      fwCampaigns.getRecipientBalance(campaignId1, address(0x456)),
      0,
      "Second recipient balance should be 0 after claim"
    );

    // Verify claimed amounts
    assertEq(
      fwCampaigns.getRecipientClaimed(campaignId1, address(0x123)),
      expectedAmountAfterFee,
      "First recipient claimed amount incorrect"
    );
    assertEq(
      fwCampaigns.getRecipientClaimed(campaignId1, address(0x456)),
      expectedAmountAfterFee,
      "Second recipient claimed amount incorrect"
    );

    // Verify total campaign state
    (, , , , , , , uint256 totalAmountClaimed, uint256 totalAmountAllocated, , ) = fwCampaigns.campaigns(campaignId1);
    assertEq(totalAmountAllocated, attributionAmount * 2, "Total attributed should include both attributions");

    assertEq(
      totalAmountClaimed,
      (expectedAmountAfterFee * 2) + totalExpectedFee,
      "Total claimed should match both claims plus protocol fees"
    );
  }

  function test_overattribution_check_uses_totalFunded_not_balance() public {
    // Setup campaign and initial attribution
    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId1, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    // First do a valid attribution of 400 tokens
    uint256 firstAttributionAmount = 400 * 10 ** 18;
    IFlywheelCampaigns.OffchainEvent[] memory firstEvents = new IFlywheelCampaigns.OffchainEvent[](1);
    firstEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: firstAttributionAmount,
      recipientType: 1,
      publisherRefCode: "test1",
      clickId: "123",
      timestamp: 1734565000
    });

    fwCampaigns.attributeOffchainEvents(campaignId1, firstEvents);
    vm.stopPrank();

    // Recipient claims their rewards, reducing the campaign balance
    vm.startPrank(address(0x123));
    uint256[] memory campaignIds = new uint256[](1);
    campaignIds[0] = campaignId1;
    fwCampaigns.claimRewards(campaignIds, address(0x123));
    vm.stopPrank();

    // Verify campaign balance is now reduced
    uint256 currentBalance = dummyToken.balanceOf(campaignBalanceAddress1);
    assertEq(currentBalance, totalFunded1 - firstAttributionAmount, "Balance should be reduced after claim");

    // Now try to attribute the remaining amount up to totalFunded
    vm.startPrank(spdApSigner);

    // Calculate remaining amount that can be attributed (should be totalFunded - firstAttributionAmount)
    uint256 remainingAttributable = totalFunded1 - firstAttributionAmount;

    IFlywheelCampaigns.OffchainEvent[] memory remainingEvents = new IFlywheelCampaigns.OffchainEvent[](1);
    remainingEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x456),
      payoutAmount: remainingAttributable,
      recipientType: 1,
      publisherRefCode: "test2",
      clickId: "456",
      timestamp: 1734565000
    });

    // This should succeed even though current balance is less than remainingAttributable
    fwCampaigns.attributeOffchainEvents(campaignId1, remainingEvents);

    // Verify state after second attribution
    assertEq(
      fwCampaigns.getRecipientBalance(campaignId1, address(0x456)),
      remainingAttributable,
      "Second attribution should succeed up to remaining total funded amount"
    );

    // Verify campaign totals
    (, , , , , , , uint256 totalAmountClaimed, uint256 totalAmountAllocated, , ) = fwCampaigns.campaigns(campaignId1);

    assertEq(totalAmountClaimed, firstAttributionAmount, "Only first attribution should be claimed");
    assertEq(totalAmountAllocated, totalFunded1, "Total attributed should equal total funded");

    // Now try to attribute even 1 more token - should fail
    IFlywheelCampaigns.OffchainEvent[] memory overflowEvents = new IFlywheelCampaigns.OffchainEvent[](1);
    overflowEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x789),
      payoutAmount: 1,
      recipientType: 1,
      publisherRefCode: "test3",
      clickId: "789",
      timestamp: 1734565000
    });

    vm.expectRevert(IFlywheelCampaigns.CannotOverAttribute.selector);
    fwCampaigns.attributeOffchainEvents(campaignId1, overflowEvents);

    vm.stopPrank();
  }

  function test_createCampaignWithAllowlist() public {
    // Create campaign with allowlist
    string[] memory allowedRefCodes = new string[](3);
    allowedRefCodes[0] = "publisher1";
    allowedRefCodes[1] = "publisher2";
    allowedRefCodes[2] = "publisher3";

    vm.startPrank(advertiser);
    (uint256 campaignId, address campaignBalanceAddress, uint8[] memory conversionEventIds) = fwCampaigns
      .createCampaign(
        address(dummyToken),
        spdApId,
        true,
        campaignMetadataUrl1,
        dummyConversionEvents1,
        allowedRefCodes
      );

    // Fund the campaign
    dummyToken.transfer(campaignBalanceAddress, totalFunded1);
    vm.stopPrank();

    // Verify campaign is created with allowlist
    (, , , , , , , , , , bool isAllowlistSet) = fwCampaigns.campaigns(campaignId);
    assertTrue(isAllowlistSet, "Allowlist should be set");

    for (uint256 i = 0; i < allowedRefCodes.length; i++) {
      assertTrue(
        fwCampaigns.isPublisherRefCodeAllowed(campaignId, allowedRefCodes[i]),
        "Publisher ref code should be allowed"
      );
    }

    // Test attribution with allowed publisher ref code
    vm.startPrank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    // Test offchain attribution with allowed ref code
    IFlywheelCampaigns.OffchainEvent[] memory validOffchainEvents = new IFlywheelCampaigns.OffchainEvent[](1);
    validOffchainEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: 1000,
      recipientType: 1,
      publisherRefCode: "publisher1", // Using allowed ref code
      clickId: "123",
      timestamp: 1734565000
    });

    // This should succeed
    fwCampaigns.attributeOffchainEvents(campaignId, validOffchainEvents);

    // Test onchain attribution with allowed ref code
    IFlywheelCampaigns.OnchainEvent[] memory validOnchainEvents = new IFlywheelCampaigns.OnchainEvent[](1);
    validOnchainEvents[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 2,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x456),
      payoutAmount: 1000,
      recipientType: 1,
      publisherRefCode: "publisher2", // Using allowed ref code
      clickId: "456",
      userAddress: address(0x999),
      timestamp: 1734565000,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 1
    });

    // This should succeed
    fwCampaigns.attributeOnchainEvents(campaignId, validOnchainEvents);

    // Test offchain attribution with disallowed ref code
    IFlywheelCampaigns.OffchainEvent[] memory invalidOffchainEvents = new IFlywheelCampaigns.OffchainEvent[](1);
    invalidOffchainEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x123),
      payoutAmount: 1000,
      recipientType: 1,
      publisherRefCode: "invalidPublisher", // Using disallowed ref code
      clickId: "123",
      timestamp: 1734565000
    });

    // This should fail
    vm.expectRevert(IFlywheelCampaigns.PublisherRefCodeNotAllowed.selector);
    fwCampaigns.attributeOffchainEvents(campaignId, invalidOffchainEvents);

    // Test onchain attribution with disallowed ref code
    IFlywheelCampaigns.OnchainEvent[] memory invalidOnchainEvents = new IFlywheelCampaigns.OnchainEvent[](1);
    invalidOnchainEvents[0] = IFlywheelCampaigns.OnchainEvent({
      conversionConfigId: 2,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x456),
      payoutAmount: 1000,
      recipientType: 1,
      publisherRefCode: "invalidPublisher", // Using disallowed ref code
      clickId: "456",
      userAddress: address(0x999),
      timestamp: 1734565000,
      txHash: keccak256("TestTxHash"),
      txChainId: 1,
      txEventLogIndex: 1
    });

    // This should fail
    vm.expectRevert(IFlywheelCampaigns.PublisherRefCodeNotAllowed.selector);
    fwCampaigns.attributeOnchainEvents(campaignId, invalidOnchainEvents);

    vm.stopPrank();
  }

  function test_addAllowedPublisherRefCode_failsWhenAllowlistNotSet() public {
    // Create campaign without allowlist
    string[] memory emptyAllowlist = new string[](0);

    vm.startPrank(advertiser);
    (uint256 campaignId, address campaignBalanceAddress, uint8[] memory conversionEventIds) = fwCampaigns
      .createCampaign(address(dummyToken), spdApId, true, campaignMetadataUrl1, dummyConversionEvents1, emptyAllowlist);

    assertEq(campaignId, 2, "Campaign ID should be 2");

    // Fund the campaign
    dummyToken.transfer(campaignBalanceAddress, totalFunded1);

    // Verify campaign is created without allowlist
    (, , , , , , , , , , bool isAllowlistSet) = fwCampaigns.campaigns(campaignId);
    assertFalse(isAllowlistSet, "Allowlist should not be set");

    // Try to add a publisher ref code - should fail
    vm.expectRevert(IFlywheelCampaigns.PublisherAllowlistNotSet.selector);
    fwCampaigns.addAllowedPublisherRefCode(campaignId, "newPublisher");

    vm.stopPrank();
  }

  // Test adding a new publisher ref code
  function test_addAllowedPublisherRefCode_success() public {
    // Create campaign with allowlist
    string[] memory allowedRefCodes = new string[](3);
    allowedRefCodes[0] = "publisher1";
    allowedRefCodes[1] = "publisher2";
    allowedRefCodes[2] = "publisher3";

    vm.startPrank(advertiser);
    (uint256 campaignId, address campaignBalanceAddress, uint8[] memory conversionEventIds) = fwCampaigns
      .createCampaign(
        address(dummyToken),
        spdApId,
        true,
        campaignMetadataUrl1,
        dummyConversionEvents1,
        allowedRefCodes
      );

    // Fund the campaign
    dummyToken.transfer(campaignBalanceAddress, totalFunded1);
    vm.stopPrank();

    // Verify campaign is created with allowlist
    (, , , , , , , , , , bool isAllowlistSet) = fwCampaigns.campaigns(campaignId);
    assertTrue(isAllowlistSet, "Allowlist should be set");

    for (uint256 i = 0; i < allowedRefCodes.length; i++) {
      assertTrue(
        fwCampaigns.isPublisherRefCodeAllowed(campaignId, allowedRefCodes[i]),
        "Publisher ref code should be allowed"
      );
    }

    // Test attribution with allowed publisher ref code
    vm.prank(spdApSigner);
    fwCampaigns.updateCampaignStatus(campaignId, IFlywheelCampaigns.CampaignStatus.ACTIVE);

    // Test adding a new publisher ref code
    vm.prank(advertiser);
    fwCampaigns.addAllowedPublisherRefCode(campaignId, "newPublisher");

    // Verify the new ref code is allowed
    assertTrue(
      fwCampaigns.isPublisherRefCodeAllowed(campaignId, "newPublisher"),
      "New publisher ref code should be allowed"
    );

    // Test attribution with newly added ref code
    IFlywheelCampaigns.OffchainEvent[] memory newRefCodeEvents = new IFlywheelCampaigns.OffchainEvent[](1);
    newRefCodeEvents[0] = IFlywheelCampaigns.OffchainEvent({
      conversionConfigId: 1,
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      payoutAddress: address(0x789),
      payoutAmount: 1000,
      recipientType: 1,
      publisherRefCode: "newPublisher",
      clickId: "789",
      timestamp: 1734565000
    });

    // This should succeed with the newly added ref code
    vm.prank(spdApSigner);
    fwCampaigns.attributeOffchainEvents(campaignId, newRefCodeEvents);

    // Verify the attribution was successful
    assertEq(
      fwCampaigns.getRecipientBalance(campaignId, address(0x789)),
      1000,
      "Attribution with new publisher ref code should succeed"
    );
  }
}

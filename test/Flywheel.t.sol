// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import { Test } from "forge-std/Test.sol";
import { Flywheel } from "../src/Flywheel.sol";
import { AdvertisementConversion } from "../src/hooks/AdvertisementConversion.sol";
import { DummyERC20 } from "../src/archive/test/DummyERC20.sol";

contract FlywheelTest is Test {
  Flywheel public flywheel;
  AdvertisementConversion public hook;
  DummyERC20 public token;

  address public advertiser = address(0x1);
  address public attributor = address(0x2);
  address public protocolFeeRecipient = address(0x3);
  address public publisher1 = address(0x4);
  address public publisher2 = address(0x5);
  address public user = address(0x6);

  uint16 public constant PROTOCOL_FEE_BPS = 500; // 5%
  uint256 public constant INITIAL_BALANCE = 1000e18; // 1000 tokens

  function setUp() public {
    // Deploy token
    address[] memory initialHolders = new address[](2);
    initialHolders[0] = advertiser;
    initialHolders[1] = attributor;
    token = new DummyERC20(initialHolders);

    // Deploy Flywheel
    flywheel = new Flywheel();

    // Deploy hook
    hook = new AdvertisementConversion(address(flywheel), address(this));
  }

  function test_createCampaign() public {
    vm.startPrank(advertiser);

    // Create campaign
    bytes memory initData = ""; // Empty init data for this test
    address campaign = flywheel.createCampaign(attributor, address(hook), initData);

    // Verify campaign was created
    (
      Flywheel.CampaignStatus status,
      address campaignAdvertiser,
      address campaignAttributor,
      address campaignHook,

    ) = flywheel.campaigns(campaign);

    assertEq(uint8(status), uint8(Flywheel.CampaignStatus.CREATED));
    assertEq(campaignAdvertiser, advertiser);
    assertEq(campaignAttributor, attributor);
    assertEq(campaignHook, address(hook));

    vm.stopPrank();
  }

  function test_campaignLifecycle() public {
    vm.startPrank(advertiser);

    // Create campaign
    bytes memory initData = "";
    address campaign = flywheel.createCampaign(attributor, address(hook), initData);

    (Flywheel.CampaignStatus status1, , , , ) = flywheel.campaigns(campaign);
    assertEq(uint8(status1), uint8(Flywheel.CampaignStatus.CREATED));

    vm.stopPrank();

    // Attributor opens campaign (CREATED -> OPEN)
    vm.startPrank(attributor);
    flywheel.openCampaign(campaign);

    (Flywheel.CampaignStatus status2, , , , ) = flywheel.campaigns(campaign);
    assertEq(uint8(status2), uint8(Flywheel.CampaignStatus.OPEN));

    vm.stopPrank();
  }

  function test_offchainAttribution() public {
    // Create campaign
    bytes memory initData = "";
    vm.prank(advertiser);
    address campaign = flywheel.createCampaign(attributor, address(hook), initData);

    vm.startPrank(attributor);

    // Open campaign (attributor only)
    flywheel.openCampaign(campaign);

    // Fund campaign by transferring tokens directly to the TokenStore
    token.transfer(campaign, INITIAL_BALANCE);

    // Create offchain attribution data
    AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

    AdvertisementConversion.Conversion memory conversion = AdvertisementConversion.Conversion({
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      clickId: "click_123",
      conversionConfigId: 1,
      publisherRefCode: "PUB_001",
      timestamp: uint32(block.timestamp),
      recipientType: 1
    });

    Flywheel.Payout memory payout = Flywheel.Payout({
      recipient: publisher1,
      amount: 100e18 // 100 tokens
    });

    attributions[0] = AdvertisementConversion.Attribution({
      payout: payout,
      conversion: conversion,
      logBytes: "" // Empty for offchain
    });

    bytes memory attributionData = abi.encode(attributions);

    // Attribute offchain conversion
    flywheel.attribute(campaign, address(token), attributionData);

    // Check internal Flywheel balance
    uint256 publisherInternalBalance = flywheel.balances(address(token), publisher1);
    uint256 protocolFeeInternalBalance = flywheel.fees(address(token), attributor);
    assertEq(publisherInternalBalance, 100e18, "Publisher should have 100 tokens in Flywheel");
    assertEq(protocolFeeInternalBalance, 5 * 10 ** 18, "Protocol should have 5 tokens in Flywheel (5% of 100)");

    // Distribute to publisher and check token balance
    vm.stopPrank();
    vm.startPrank(publisher1);
    uint256 balanceBefore = token.balanceOf(publisher1);
    flywheel.distributePayouts(address(token), publisher1);
    uint256 balanceAfter = token.balanceOf(publisher1);
    assertEq(balanceAfter - balanceBefore, 100 * 10 ** 18, "Publisher should receive 100 tokens after distribute");
    vm.stopPrank();
  }

  function test_onchainAttribution() public {
    vm.prank(advertiser);
    // Create campaign
    bytes memory initData = "";
    address campaign = flywheel.createCampaign(attributor, address(hook), initData);

    vm.startPrank(attributor);
    // Open campaign (attributor only)
    flywheel.openCampaign(campaign);

    // Fund campaign by transferring tokens directly to the TokenStore
    token.transfer(campaign, INITIAL_BALANCE);

    // Create onchain attribution data
    AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

    AdvertisementConversion.Conversion memory conversion = AdvertisementConversion.Conversion({
      eventId: bytes16(0xabcdef1234567890abcdef1234567890),
      clickId: "click_456",
      conversionConfigId: 2,
      publisherRefCode: "PUB_002",
      timestamp: uint32(block.timestamp),
      recipientType: 1
    });

    AdvertisementConversion.Log memory log = AdvertisementConversion.Log({
      chainId: 1,
      transactionHash: keccak256("test_transaction"),
      index: 0
    });

    Flywheel.Payout memory payout = Flywheel.Payout({
      recipient: publisher2,
      amount: 200 * 10 ** 18 // 200 tokens
    });

    attributions[0] = AdvertisementConversion.Attribution({
      payout: payout,
      conversion: conversion,
      logBytes: abi.encode(log) // Encoded log for onchain
    });

    bytes memory attributionData = abi.encode(attributions);

    // Attribute onchain conversion
    flywheel.attribute(campaign, address(token), attributionData);

    // Check internal Flywheel balance
    uint256 publisherInternalBalance = flywheel.balances(address(token), publisher2);
    uint256 protocolFeeInternalBalance = flywheel.fees(address(token), attributor);
    assertEq(publisherInternalBalance, 200 * 10 ** 18, "Publisher should have 200 tokens in Flywheel");
    assertEq(protocolFeeInternalBalance, 10 * 10 ** 18, "Protocol should have 10 tokens in Flywheel (5% of 200)");

    // Distribute to publisher and check token balance
    vm.stopPrank();
    vm.startPrank(publisher2);
    uint256 balanceBefore = token.balanceOf(publisher2);
    flywheel.distributePayouts(address(token), publisher2);
    uint256 balanceAfter = token.balanceOf(publisher2);
    assertEq(balanceAfter - balanceBefore, 200 * 10 ** 18, "Publisher should receive 200 tokens after distribute");
    vm.stopPrank();
  }

  function test_distributeAndWithdraw() public {
    vm.prank(advertiser);
    // Create campaign
    bytes memory initData = "";
    address campaign = flywheel.createCampaign(attributor, address(hook), initData);

    vm.startPrank(attributor);
    // Open campaign (attributor only)
    flywheel.openCampaign(campaign);

    // Fund campaign by transferring tokens directly to the TokenStore
    token.transfer(campaign, INITIAL_BALANCE);

    // Create attribution data
    AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

    AdvertisementConversion.Conversion memory conversion = AdvertisementConversion.Conversion({
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      clickId: "click_789",
      conversionConfigId: 1,
      publisherRefCode: "PUB_003",
      timestamp: uint32(block.timestamp),
      recipientType: 1
    });

    Flywheel.Payout memory payout = Flywheel.Payout({
      recipient: publisher1,
      amount: 50 * 10 ** 18 // 50 tokens
    });

    attributions[0] = AdvertisementConversion.Attribution({ payout: payout, conversion: conversion, logBytes: "" });

    bytes memory attributionData = abi.encode(attributions);

    // Attribute conversion
    flywheel.attribute(campaign, address(token), attributionData);

    vm.stopPrank();

    // Distribute tokens to publisher
    vm.startPrank(publisher1);
    uint256 balanceBefore = token.balanceOf(publisher1);
    flywheel.distributePayouts(address(token), publisher1);
    uint256 balanceAfter = token.balanceOf(publisher1);

    assertEq(balanceAfter - balanceBefore, 50 * 10 ** 18, "Publisher should receive 50 tokens");
    vm.stopPrank();

    // Close campaign first
    vm.startPrank(advertiser);
    flywheel.closeCampaign(campaign);

    // Wait for finalization deadline to pass
    vm.warp(block.timestamp + 8 days); // 7 days + 1 day buffer

    // Finalize campaign
    flywheel.finalizeCampaign(campaign);
    vm.stopPrank();

    // Withdraw remaining tokens
    vm.startPrank(advertiser);
    uint256 advertiserBalanceBefore = token.balanceOf(advertiser);
    flywheel.withdrawRemainder(campaign, address(token));
    uint256 advertiserBalanceAfter = token.balanceOf(advertiser);

    // Should receive remaining tokens minus attributed amount and protocol fee
    uint256 expectedRemaining = INITIAL_BALANCE - (50 * 10 ** 18) - (2.5 * 10 ** 18); // 50 tokens + 2.5 protocol fee
    assertEq(
      advertiserBalanceAfter - advertiserBalanceBefore,
      expectedRemaining,
      "Advertiser should receive remaining tokens"
    );
    vm.stopPrank();
  }

  function test_collectFees() public {
    vm.prank(advertiser);
    // Create campaign
    bytes memory initData = "";
    address campaign = flywheel.createCampaign(attributor, address(hook), initData);

    vm.startPrank(attributor);
    // Open campaign (attributor only)
    flywheel.openCampaign(campaign);

    // Fund campaign by transferring tokens directly to the TokenStore
    token.transfer(campaign, INITIAL_BALANCE);

    // Create attribution data to generate fees
    AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

    AdvertisementConversion.Conversion memory conversion = AdvertisementConversion.Conversion({
      eventId: bytes16(0x1234567890abcdef1234567890abcdef),
      clickId: "click_fees",
      conversionConfigId: 1,
      publisherRefCode: "PUB_FEES",
      timestamp: uint32(block.timestamp),
      recipientType: 1
    });

    Flywheel.Payout memory payout = Flywheel.Payout({
      recipient: publisher1,
      amount: 100 * 10 ** 18 // 100 tokens
    });

    attributions[0] = AdvertisementConversion.Attribution({ payout: payout, conversion: conversion, logBytes: "" });

    bytes memory attributionData = abi.encode(attributions);

    // Attribute conversion to generate protocol fees
    flywheel.attribute(campaign, address(token), attributionData);

    // Check that fees are available
    uint256 availableFees = flywheel.fees(address(token), attributor);
    assertEq(availableFees, 5 * 10 ** 18, "Should have 5 tokens in collectible fees (5% of 100)");

    vm.stopPrank();

    // Collect fees as attributor
    vm.startPrank(attributor);
    uint256 balanceBefore = token.balanceOf(attributor);
    flywheel.collectFees(address(token), attributor);
    uint256 balanceAfter = token.balanceOf(attributor);

    assertEq(balanceAfter - balanceBefore, 5 * 10 ** 18, "Protocol fee recipient should receive 5 tokens");

    // Check that fees are cleared
    uint256 remainingFees = flywheel.fees(address(token), attributor);
    assertEq(remainingFees, 0, "Fees should be cleared after collection");
    vm.stopPrank();
  }
}

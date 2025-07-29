// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../src/Flywheel.sol";
import {FlywheelPublisherRegistry} from "../src/FlywheelPublisherRegistry.sol";
import {
    AdvertisementConversion,
    ConversionConfig,
    ConversionConfigStatus,
    EventType
} from "../src/hooks/AdvertisementConversion.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FlywheelTest is Test {
    Flywheel public flywheel;
    FlywheelPublisherRegistry public publisherRegistry;
    AdvertisementConversion public hook;
    DummyERC20 public token;

    address public advertiser = address(0x1);
    address public attributionProvider = address(0x2);
    address public owner = address(0x3);
    address public publisher1 = address(0x4);
    address public publisher2 = address(0x5);
    address public user = address(0x6);

    uint16 public constant ATTRIBUTION_FEE_BPS = 500; // 5%
    uint256 public constant INITIAL_BALANCE = 1000e18; // 1000 tokens
    address public campaign;

    function setUp() public {
        // Deploy token
        address[] memory initialHolders = new address[](2);
        initialHolders[0] = advertiser;
        initialHolders[1] = attributionProvider;
        token = new DummyERC20(initialHolders);

        // Deploy Flywheel
        flywheel = new Flywheel();

        // Deploy publisher registry
        FlywheelPublisherRegistry impl = new FlywheelPublisherRegistry();
        bytes memory initData = abi.encodeWithSelector(
            FlywheelPublisherRegistry.initialize.selector,
            owner,
            address(0x999) // signer address
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        publisherRegistry = FlywheelPublisherRegistry(address(proxy));

        // Deploy hook
        hook = new AdvertisementConversion(address(flywheel), owner, address(publisherRegistry));

        // Create a basic campaign for tests
        _createCampaign();
    }

    function _createCampaign() internal {
        ConversionConfig[] memory configs = new ConversionConfig[](2);
        configs[0] = ConversionConfig({
            status: ConversionConfigStatus.ACTIVE,
            eventType: EventType.OFFCHAIN,
            conversionMetadataUrl: "https://example.com/offchain"
        });
        configs[1] = ConversionConfig({
            status: ConversionConfigStatus.ACTIVE,
            eventType: EventType.ONCHAIN,
            conversionMetadataUrl: "https://example.com/onchain"
        });

        string[] memory allowedRefCodes = new string[](0);
        bytes memory hookData =
            abi.encode(attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs);

        campaign = flywheel.createCampaign(address(hook), 1, hookData);
    }

    function test_createCampaign() public {
        // Verify campaign was created correctly
        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.INACTIVE));
        assertEq(flywheel.campaignHooks(campaign), address(hook));
        assertEq(flywheel.campaignURI(campaign), "https://example.com/campaign");
    }

    function test_campaignLifecycle() public {
        // Start with INACTIVE status
        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.INACTIVE));

        // Attribution provider opens campaign (INACTIVE -> ACTIVE)
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.ACTIVE));

        // Attribution provider can transition to FINALIZING
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");

        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.FINALIZING));

        // Attribution provider can finalize campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");

        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.FINALIZED));
    }

    function test_offchainAttribution() public {
        // Activate campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Set attribution fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(ATTRIBUTION_FEE_BPS);

        // Fund campaign by transferring tokens directly to the TokenStore
        vm.prank(advertiser);
        token.transfer(campaign, INITIAL_BALANCE);

        // Create offchain attribution data
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

        AdvertisementConversion.Conversion memory conversion = AdvertisementConversion.Conversion({
            eventId: bytes16(0x1234567890abcdef1234567890abcdef),
            clickId: "click_123",
            conversionConfigId: 1,
            publisherRefCode: "",
            timestamp: uint32(block.timestamp),
            recipientType: 0,
            payoutAmount: 100e18
        });

        Flywheel.Payout memory payout = Flywheel.Payout({
            recipient: publisher1,
            amount: 100e18, // 100 tokens
            extraData: ""
        });

        attributions[0] = AdvertisementConversion.Attribution({
            payout: payout,
            conversion: conversion,
            logBytes: "" // Empty for offchain
        });

        bytes memory attributionData = abi.encode(attributions);

        // Process attribution with reward (immediate payout)
        vm.prank(attributionProvider);
        flywheel.reward(campaign, address(token), attributionData);

        // Check that publisher received tokens immediately
        uint256 payoutAmount = 100e18;
        uint256 feeAmount = payoutAmount * ATTRIBUTION_FEE_BPS / 10000;
        uint256 expectedPayout = payoutAmount - feeAmount; // Amount minus fee
        assertEq(token.balanceOf(publisher1), expectedPayout, "Publisher should receive tokens minus fee");

        // Check attribution provider fee is allocated
        uint256 expectedFee = feeAmount;
        assertEq(
            flywheel.fees(campaign, address(token), attributionProvider),
            expectedFee,
            "Attribution provider should have fee allocated"
        );
    }

    function test_onchainAttribution() public {
        // Activate campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Set attribution fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(ATTRIBUTION_FEE_BPS);

        // Fund campaign by transferring tokens directly to the TokenStore
        vm.prank(advertiser);
        token.transfer(campaign, INITIAL_BALANCE);

        // Create onchain attribution data
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

        AdvertisementConversion.Conversion memory conversion = AdvertisementConversion.Conversion({
            eventId: bytes16(0xabcdef1234567890abcdef1234567890),
            clickId: "click_456",
            conversionConfigId: 2,
            publisherRefCode: "",
            timestamp: uint32(block.timestamp),
            recipientType: 0,
            payoutAmount: 200 * 10 ** 18
        });

        AdvertisementConversion.Log memory log =
            AdvertisementConversion.Log({chainId: 1, transactionHash: keccak256("test_transaction"), index: 0});

        Flywheel.Payout memory payout = Flywheel.Payout({
            recipient: publisher2,
            amount: 200 * 10 ** 18, // 200 tokens
            extraData: ""
        });

        attributions[0] = AdvertisementConversion.Attribution({
            payout: payout,
            conversion: conversion,
            logBytes: abi.encode(log) // Encoded log for onchain
        });

        bytes memory attributionData = abi.encode(attributions);

        // Process attribution with reward (immediate payout)
        vm.prank(attributionProvider);
        flywheel.reward(campaign, address(token), attributionData);

        // Check that publisher received tokens immediately
        uint256 payoutAmount2 = 200 * 10 ** 18;
        uint256 feeAmount2 = payoutAmount2 * ATTRIBUTION_FEE_BPS / 10000;
        uint256 expectedPayout = payoutAmount2 - feeAmount2;
        assertEq(token.balanceOf(publisher2), expectedPayout, "Publisher should receive tokens minus fee");

        // Check attribution provider fee is allocated
        uint256 expectedFee = feeAmount2;
        assertEq(
            flywheel.fees(campaign, address(token), attributionProvider),
            expectedFee,
            "Attribution provider should have fee allocated"
        );
    }

    function test_distributeAndWithdraw() public {
        // Activate campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Set attribution fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(ATTRIBUTION_FEE_BPS);

        // Fund campaign by transferring tokens directly to the TokenStore
        vm.prank(advertiser);
        token.transfer(campaign, INITIAL_BALANCE);

        // Create attribution data
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

        AdvertisementConversion.Conversion memory conversion = AdvertisementConversion.Conversion({
            eventId: bytes16(0x1234567890abcdef1234567890abcdef),
            clickId: "click_789",
            conversionConfigId: 1,
            publisherRefCode: "",
            timestamp: uint32(block.timestamp),
            recipientType: 0,
            payoutAmount: 50 * 10 ** 18
        });

        Flywheel.Payout memory payout = Flywheel.Payout({
            recipient: publisher1,
            amount: 50 * 10 ** 18, // 50 tokens
            extraData: ""
        });

        attributions[0] = AdvertisementConversion.Attribution({payout: payout, conversion: conversion, logBytes: ""});

        bytes memory attributionData = abi.encode(attributions);

        // Process attribution with reward (immediate payout)
        vm.prank(attributionProvider);
        flywheel.reward(campaign, address(token), attributionData);

        // Verify publisher received tokens
        uint256 payoutAmount3 = 50 * 10 ** 18;
        uint256 feeAmount3 = payoutAmount3 * ATTRIBUTION_FEE_BPS / 10000;
        uint256 expectedPayout = payoutAmount3 - feeAmount3;
        assertEq(token.balanceOf(publisher1), expectedPayout, "Publisher should receive tokens minus fee");

        // Finalize campaign
        vm.startPrank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");
        vm.stopPrank();

        // First, attribution provider collects their fee
        vm.startPrank(attributionProvider);
        flywheel.collectFees(campaign, address(token), attributionProvider);
        vm.stopPrank();

        // Withdraw remaining tokens
        uint256 campaignBalance = token.balanceOf(campaign);
        vm.startPrank(advertiser);
        uint256 advertiserBalanceBefore = token.balanceOf(advertiser);
        flywheel.withdrawFunds(campaign, address(token), campaignBalance, "");
        uint256 advertiserBalanceAfter = token.balanceOf(advertiser);

        assertEq(
            advertiserBalanceAfter - advertiserBalanceBefore,
            campaignBalance,
            "Advertiser should receive remaining campaign tokens"
        );
        vm.stopPrank();
    }

    function test_collectFees() public {
        // Activate campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Set attribution fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(ATTRIBUTION_FEE_BPS);

        // Fund campaign by transferring tokens directly to the TokenStore
        vm.prank(advertiser);
        token.transfer(campaign, INITIAL_BALANCE);

        // Create attribution data to generate fees
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

        AdvertisementConversion.Conversion memory conversion = AdvertisementConversion.Conversion({
            eventId: bytes16(0x1234567890abcdef1234567890abcdef),
            clickId: "click_fees",
            conversionConfigId: 1,
            publisherRefCode: "",
            timestamp: uint32(block.timestamp),
            recipientType: 0,
            payoutAmount: 100 * 10 ** 18
        });

        Flywheel.Payout memory payout = Flywheel.Payout({
            recipient: publisher1,
            amount: 100 * 10 ** 18, // 100 tokens
            extraData: ""
        });

        attributions[0] = AdvertisementConversion.Attribution({payout: payout, conversion: conversion, logBytes: ""});

        bytes memory attributionData = abi.encode(attributions);

        // Process attribution to generate fees
        vm.prank(attributionProvider);
        flywheel.reward(campaign, address(token), attributionData);

        // Check that fees are available
        uint256 payoutAmount4 = 100 * 10 ** 18;
        uint256 expectedFee = payoutAmount4 * ATTRIBUTION_FEE_BPS / 10000;
        uint256 availableFees = flywheel.fees(campaign, address(token), attributionProvider);
        assertEq(availableFees, expectedFee, "Should have correct attribution fee allocated");

        // Collect fees as attribution provider
        vm.startPrank(attributionProvider);
        uint256 balanceBefore = token.balanceOf(attributionProvider);
        flywheel.collectFees(campaign, address(token), attributionProvider);
        uint256 balanceAfter = token.balanceOf(attributionProvider);

        assertEq(balanceAfter - balanceBefore, expectedFee, "Attribution provider should receive fee tokens");

        // Check that fees are cleared
        uint256 remainingFees = flywheel.fees(campaign, address(token), attributionProvider);
        assertEq(remainingFees, 0, "Fees should be cleared after collection");
        vm.stopPrank();
    }
}

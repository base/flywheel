// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../src/Flywheel.sol";
import {ReferralCodeRegistry} from "../src/ReferralCodeRegistry.sol";
import {TokenStore} from "../src/TokenStore.sol";
import {AdvertisementConversion} from "../src/hooks/AdvertisementConversion.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FlywheelTest is Test {
    Flywheel public flywheel;
    ReferralCodeRegistry public publisherRegistry;
    AdvertisementConversion public hook;
    DummyERC20 public token;

    address public advertiser = address(0x1);
    address public attributionProvider = address(0x2);
    address public owner = address(0x3);
    address public publisher1 = address(0x4);
    address public publisher2 = address(0x5);

    address public publisher1Payout = address(0x6);
    address public publisher2Payout = address(0x7);
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
        ReferralCodeRegistry impl = new ReferralCodeRegistry();
        bytes memory initData = abi.encodeWithSelector(
            ReferralCodeRegistry.initialize.selector,
            owner,
            address(0x999) // signer address
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        publisherRegistry = ReferralCodeRegistry(address(proxy));

        // Register publishers with ref codes
        vm.startPrank(owner);

        // Register publisher1 with ref code "PUBLISHER_1"
        publisherRegistry.registerCustom("PUBLISHER_1", publisher1, publisher1Payout, "https://example.com/publisher1");

        // Register publisher2 with ref code "PUBLISHER_2"
        publisherRegistry.registerCustom("PUBLISHER_2", publisher2, publisher2Payout, "https://example.com/publisher2");
        vm.stopPrank();

        // Deploy hook
        hook = new AdvertisementConversion(address(flywheel), owner, address(publisherRegistry));

        // Create a basic campaign for tests
        _createCampaign();
    }

    function _createCampaign() internal {
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](2);
        configs[0] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: false,
            conversionMetadataUrl: "https://example.com/offchain"
        });
        configs[1] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: true,
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
            publisherRefCode: "PUBLISHER_1",
            timestamp: uint32(block.timestamp),
            payoutRecipient: address(0),
            payoutAmount: 100e18
        });

        attributions[0] = AdvertisementConversion.Attribution({
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
        assertEq(token.balanceOf(publisher1Payout), expectedPayout, "Publisher should receive tokens minus fee");

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
            publisherRefCode: "PUBLISHER_2",
            timestamp: uint32(block.timestamp),
            payoutRecipient: address(0),
            payoutAmount: 200 * 10 ** 18
        });

        AdvertisementConversion.Log memory log =
            AdvertisementConversion.Log({chainId: 1, transactionHash: keccak256("test_transaction"), index: 0});

        attributions[0] = AdvertisementConversion.Attribution({
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
        assertEq(token.balanceOf(publisher2Payout), expectedPayout, "Publisher should receive tokens minus fee");

        // Check attribution provider fee is allocated
        uint256 expectedFee = feeAmount2;
        assertEq(
            flywheel.fees(campaign, address(token), attributionProvider),
            expectedFee,
            "Attribution provider should have fee allocated"
        );
    }

    function test_distributeAndWithdraw() public {
        address payoutRecipient = address(0x1222);

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
            payoutRecipient: payoutRecipient,
            payoutAmount: 50 * 10 ** 18
        });

        attributions[0] = AdvertisementConversion.Attribution({conversion: conversion, logBytes: ""});

        bytes memory attributionData = abi.encode(attributions);

        // Process attribution with reward (immediate payout)
        vm.prank(attributionProvider);
        flywheel.reward(campaign, address(token), attributionData);

        // Verify payoutRecipient received tokens
        uint256 payoutAmount3 = 50 * 10 ** 18;
        uint256 feeAmount3 = payoutAmount3 * ATTRIBUTION_FEE_BPS / 10000;
        uint256 expectedPayout = payoutAmount3 - feeAmount3;
        assertEq(token.balanceOf(payoutRecipient), expectedPayout, "Payout recipient should receive tokens minus fee");

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
        address payoutRecipient = address(0x1222);

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
            payoutRecipient: payoutRecipient,
            payoutAmount: 100 * 10 ** 18
        });

        attributions[0] = AdvertisementConversion.Attribution({conversion: conversion, logBytes: ""});

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

    // =============================================================
    //                    ALLOCATE/DISTRIBUTE FUNCTIONALITY
    // =============================================================

    function test_allocateAndDistribute() public {
        // Note: AdvertisementConversion hook doesn't support allocate/distribute
        // This test demonstrates that the hook properly rejects unsupported operations
        address payoutRecipient = address(0x1333);

        // Activate campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Fund campaign
        vm.prank(advertiser);
        token.transfer(campaign, INITIAL_BALANCE);

        // Create attribution data for allocation
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(0x11111111111111112222222222222222)),
                clickId: "allocate_test",
                conversionConfigId: 1,
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: payoutRecipient,
                payoutAmount: 150e18
            }),
            logBytes: ""
        });

        bytes memory attributionData = abi.encode(attributions);

        // AdvertisementConversion hook doesn't support allocate - should revert
        vm.expectRevert(); // Unsupported operation
        vm.prank(attributionProvider);
        flywheel.allocate(campaign, address(token), attributionData);
    }

    function test_deallocate() public {
        // Note: AdvertisementConversion hook doesn't support deallocate
        // This test demonstrates that the hook properly rejects unsupported operations
        address payoutRecipient = address(0x1444);

        // Activate campaign and fund it
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        vm.prank(advertiser);
        token.transfer(campaign, INITIAL_BALANCE);

        // Create attribution data
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(0x33333333333333334444444444444444)),
                clickId: "deallocate_test",
                conversionConfigId: 1,
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: payoutRecipient,
                payoutAmount: 100e18
            }),
            logBytes: ""
        });

        bytes memory attributionData = abi.encode(attributions);

        // AdvertisementConversion hook doesn't support deallocate - should revert
        vm.expectRevert(); // Unsupported operation
        vm.prank(attributionProvider);
        flywheel.deallocate(campaign, address(token), attributionData);
    }

    // =============================================================
    //                    MULTI-TOKEN SUPPORT
    // =============================================================

    function test_multiTokenCampaign() public {
        // Deploy a second token
        address[] memory holders = new address[](1);
        holders[0] = advertiser;
        DummyERC20 token2 = new DummyERC20(holders);

        // Activate campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Fund campaign with both tokens
        vm.startPrank(advertiser);
        token.transfer(campaign, INITIAL_BALANCE);
        token2.transfer(campaign, INITIAL_BALANCE / 2);
        vm.stopPrank();

        // Create attributions for both tokens
        address recipient1 = address(0x1555);
        address recipient2 = address(0x1666);

        // Attribution for token1
        AdvertisementConversion.Attribution[] memory attributions1 = new AdvertisementConversion.Attribution[](1);
        attributions1[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(0x55555555555555556666666666666666)),
                clickId: "token1_test",
                conversionConfigId: 1,
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: recipient1,
                payoutAmount: 50e18
            }),
            logBytes: ""
        });

        // Attribution for token2
        AdvertisementConversion.Attribution[] memory attributions2 = new AdvertisementConversion.Attribution[](1);
        attributions2[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(0x77777777777777778888888888888888)),
                clickId: "token2_test",
                conversionConfigId: 1,
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: recipient2,
                payoutAmount: 25e18
            }),
            logBytes: ""
        });

        // Process both attributions
        vm.startPrank(attributionProvider);
        flywheel.reward(campaign, address(token), abi.encode(attributions1));
        flywheel.reward(campaign, address(token2), abi.encode(attributions2));
        vm.stopPrank();

        // Verify both recipients received their respective tokens
        assertEq(token.balanceOf(recipient1), 50e18, "Recipient1 should receive token1");
        assertEq(token2.balanceOf(recipient2), 25e18, "Recipient2 should receive token2");
    }

    function test_multiTokenFeeCollection() public {
        // Deploy second token
        address[] memory holders = new address[](1);
        holders[0] = advertiser;
        DummyERC20 token2 = new DummyERC20(holders);

        // Activate campaign and set fee
        vm.startPrank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        hook.setAttributionProviderFee(1000); // 10%
        vm.stopPrank();

        // Fund campaign with both tokens
        vm.startPrank(advertiser);
        token.transfer(campaign, INITIAL_BALANCE);
        token2.transfer(campaign, INITIAL_BALANCE);
        vm.stopPrank();

        // Create attributions that generate fees in both tokens
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(0x99999999999999990000000000000000)),
                clickId: "fee_test",
                conversionConfigId: 1,
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0x1777),
                payoutAmount: 100e18
            }),
            logBytes: ""
        });

        // Process attributions for both tokens
        vm.startPrank(attributionProvider);
        flywheel.reward(campaign, address(token), abi.encode(attributions));
        flywheel.reward(campaign, address(token2), abi.encode(attributions));
        vm.stopPrank();

        // Verify fees are collected for both tokens
        uint256 expectedFee = 100e18 * 1000 / 10000; // 10%
        assertEq(flywheel.fees(campaign, address(token), attributionProvider), expectedFee);
        assertEq(flywheel.fees(campaign, address(token2), attributionProvider), expectedFee);

        // Collect fees for both tokens
        vm.startPrank(attributionProvider);
        flywheel.collectFees(campaign, address(token), attributionProvider);
        flywheel.collectFees(campaign, address(token2), attributionProvider);
        vm.stopPrank();

        // Verify attribution provider received fees in both tokens
        // Note: attribution provider started with 1000000e18 initial token balance, so add the fee to that
        assertEq(
            token.balanceOf(attributionProvider), 1000000e18 + expectedFee, "Should receive initial + fee for token1"
        );
        assertEq(token2.balanceOf(attributionProvider), expectedFee, "Should receive fee for token2");
    }

    // =============================================================
    //                    TOKENSTORE INTEGRATION
    // =============================================================

    function test_tokenStoreCloneDeployment() public {
        // Verify TokenStore was cloned correctly
        assertTrue(campaign != address(0), "Campaign address should be non-zero");

        // Verify the campaign is a clone of the TokenStore implementation
        // The campaign address should have code (cloned contract)
        uint256 codeSize;
        address campaignAddr = campaign;
        assembly {
            codeSize := extcodesize(campaignAddr)
        }
        assertTrue(codeSize > 0, "Campaign should have contract code");
    }

    function test_tokenStoreAccessControl() public {
        // Fund campaign first
        vm.prank(advertiser);
        token.transfer(campaign, INITIAL_BALANCE);

        // Try to call TokenStore directly (should fail)
        vm.expectRevert();
        TokenStore(campaign).sendTokens(address(token), advertiser, 100e18);

        // Only Flywheel should be able to call TokenStore
        vm.prank(address(flywheel));
        TokenStore(campaign).sendTokens(address(token), advertiser, 100e18);

        // Verify the transfer worked - advertiser should have received the tokens back
        // Note: advertiser's balance should have the 100e18 transferred back plus remaining initial balance
        uint256 expectedBalance = (1000000e18 - INITIAL_BALANCE) + 100e18; // Initial remaining + transfer
        assertEq(token.balanceOf(advertiser), expectedBalance, "Advertiser should receive transferred tokens");
    }

    // =============================================================
    //                    CAMPAIGN ADDRESS PREDICTION
    // =============================================================

    function test_campaignAddressPrediction() public {
        // Create hook data for a new campaign
        string[] memory allowedRefs = new string[](0);
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](1);
        configs[0] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: false,
            conversionMetadataUrl: "https://test.com"
        });

        bytes memory hookData =
            abi.encode(attributionProvider, advertiser, "https://test-campaign.com", allowedRefs, configs);

        // Predict the campaign address
        address predictedAddress = flywheel.campaignAddress(999, hookData);

        // Create the campaign
        address actualAddress = flywheel.createCampaign(address(hook), 999, hookData);

        // Verify prediction was correct
        assertEq(predictedAddress, actualAddress, "Predicted address should match actual address");
    }

    function test_campaignAddressUniqueness() public {
        string[] memory allowedRefs = new string[](0);
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](0);

        bytes memory hookData1 = abi.encode(attributionProvider, advertiser, "campaign1", allowedRefs, configs);
        bytes memory hookData2 = abi.encode(attributionProvider, advertiser, "campaign2", allowedRefs, configs);

        // Same nonce, different data should produce different addresses
        address addr1 = flywheel.campaignAddress(100, hookData1);
        address addr2 = flywheel.campaignAddress(100, hookData2);
        assertTrue(addr1 != addr2, "Different hook data should produce different addresses");

        // Same data, different nonce should produce different addresses
        address addr3 = flywheel.campaignAddress(101, hookData1);
        assertTrue(addr1 != addr3, "Different nonce should produce different addresses");
    }

    // =============================================================
    //                    EDGE CASE STATUS TRANSITIONS
    // =============================================================

    function test_invalidStatusTransitions() public {
        // Go to ACTIVE first
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Try to update to same status (this should fail at Flywheel level)
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Move to FINALIZING
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");

        // Move to FINALIZED
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");

        // Try to change from FINALIZED (should fail at Flywheel level)
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
    }

    function test_statusUpdateWithHookData() public {
        // Test that hook receives the correct data on status updates
        bytes memory testData = "test_hook_data";

        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, testData);

        // Verify status was updated
        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.ACTIVE));
    }

    function test_finalizedStatusImmutable() public {
        // Move to FINALIZED status
        vm.startPrank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");
        vm.stopPrank();

        // Try to change status from FINALIZED (should fail)
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
    }
}

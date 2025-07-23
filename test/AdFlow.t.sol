// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Flywheel} from "../src/Flywheel.sol";
import {FlywheelPublisherRegistry} from "../src/FlywheelPublisherRegistry.sol";
import {
    AdvertisementConversion,
    ConversionConfig,
    ConversionConfigStatus,
    EventType
} from "../src/hooks/AdvertisementConversion.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";
import {TokenStore} from "../src/TokenStore.sol";

contract AdFlowTest is Test {
    // Contracts
    Flywheel public flywheel;
    FlywheelPublisherRegistry public publisherRegistry;
    AdvertisementConversion public adHook;
    DummyERC20 public usdc;

    // Test accounts
    address public advertiser = makeAddr("advertiser");
    address public provider = makeAddr("provider");
    address public publisher1 = makeAddr("publisher1");
    address public publisher2 = makeAddr("publisher2");
    address public owner = makeAddr("owner");

    // Campaign details
    address public campaign;
    uint256 public constant CAMPAIGN_NONCE = 1;
    uint256 public constant INITIAL_FUNDING = 10000 * 1e6; // 10,000 USDC
    uint256 public constant ATTRIBUTION_AMOUNT = 100 * 1e6; // 100 USDC per attribution
    uint16 public constant ATTRIBUTION_FEE_BPS = 500; // 5%

    // Publisher ref codes
    string public pub1RefCode;
    string public pub2RefCode;

    function setUp() public {
        // Deploy token with initial balances
        address[] memory initialHolders = new address[](2);
        initialHolders[0] = advertiser;
        initialHolders[1] = provider;
        usdc = new DummyERC20(initialHolders);

        // Deploy Flywheel
        flywheel = new Flywheel();

        // Deploy publisher registry
        FlywheelPublisherRegistry impl = new FlywheelPublisherRegistry();
        bytes memory initData = abi.encodeWithSelector(
            FlywheelPublisherRegistry.initialize.selector,
            owner,
            address(0) // No signer for this test
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        publisherRegistry = FlywheelPublisherRegistry(address(proxy));

        // Deploy advertisement conversion hook
        adHook = new AdvertisementConversion(address(flywheel), owner, address(publisherRegistry));

        // Register publishers
        _registerPublishers();

        // Create campaign
        _createCampaign();

        // Set attribution provider fee
        vm.startPrank(provider);
        adHook.setAttributionProviderFee(ATTRIBUTION_FEE_BPS);
        vm.stopPrank();

        // Fund campaign
        _fundCampaign();
    }

    function _registerPublishers() internal {
        // Register publisher 1 with chain-specific overrides
        vm.startPrank(publisher1);
        FlywheelPublisherRegistry.OverridePublisherPayout[] memory overrides1 =
            new FlywheelPublisherRegistry.OverridePublisherPayout[](2);

        // Override for Ethereum mainnet (chain ID 1)
        overrides1[0] = FlywheelPublisherRegistry.OverridePublisherPayout({
            chainId: 1,
            payoutAddress: makeAddr("publisher1_ethereum")
        });

        // Override for Polygon (chain ID 137)
        overrides1[1] = FlywheelPublisherRegistry.OverridePublisherPayout({
            chainId: 137,
            payoutAddress: makeAddr("publisher1_polygon")
        });

        (pub1RefCode,) = publisherRegistry.registerPublisher("https://publisher1.com/metadata", publisher1, overrides1);
        vm.stopPrank();

        // Register publisher 2 with different chain overrides
        vm.startPrank(publisher2);
        FlywheelPublisherRegistry.OverridePublisherPayout[] memory overrides2 =
            new FlywheelPublisherRegistry.OverridePublisherPayout[](1);

        // Override for Arbitrum (chain ID 42161)
        overrides2[0] = FlywheelPublisherRegistry.OverridePublisherPayout({
            chainId: 42161,
            payoutAddress: makeAddr("publisher2_arbitrum")
        });

        (pub2RefCode,) = publisherRegistry.registerPublisher("https://publisher2.com/metadata", publisher2, overrides2);
        vm.stopPrank();

        console2.log("Publisher 1 ref code:", pub1RefCode);
        console2.log("Publisher 2 ref code:", pub2RefCode);
        console2.log("Publisher 1 Ethereum override:", makeAddr("publisher1_ethereum"));
        console2.log("Publisher 1 Polygon override:", makeAddr("publisher1_polygon"));
        console2.log("Publisher 2 Arbitrum override:", makeAddr("publisher2_arbitrum"));
    }

    function _createCampaign() internal {
        // Prepare hook data for campaign creation (empty allowlist means all publishers allowed)
        string[] memory allowedRefCodes = new string[](0);

        // Create conversion configs
        ConversionConfig[] memory configs = new ConversionConfig[](2);
        configs[0] = ConversionConfig({
            status: ConversionConfigStatus.ACTIVE,
            eventType: EventType.OFFCHAIN,
            conversionMetadataUrl: "https://campaign.com/offchain-metadata"
        });
        configs[1] = ConversionConfig({
            status: ConversionConfigStatus.ACTIVE,
            eventType: EventType.ONCHAIN,
            conversionMetadataUrl: "https://campaign.com/onchain-metadata"
        });

        bytes memory hookData =
            abi.encode(provider, advertiser, "https://campaign.com/metadata", allowedRefCodes, configs);

        // Create campaign
        vm.startPrank(advertiser);
        campaign = flywheel.createCampaign(address(adHook), CAMPAIGN_NONCE, hookData);
        vm.stopPrank();

        console2.log("Campaign created at:", campaign);
    }

    function _fundCampaign() internal {
        // Fund campaign with USDC
        vm.startPrank(advertiser);
        usdc.transfer(campaign, INITIAL_FUNDING);
        vm.stopPrank();

        console2.log("Campaign funded with:", INITIAL_FUNDING);
    }

    function test_endToEndAdFlow() public {
        // 1. Verify initial setup
        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.CREATED));
        assertEq(usdc.balanceOf(campaign), INITIAL_FUNDING);
        assertEq(usdc.balanceOf(publisher1), 0);
        assertEq(usdc.balanceOf(publisher2), 0);

        // 2. Open campaign
        vm.startPrank(provider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.OPEN, "");
        vm.stopPrank();

        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.OPEN));

        // 3. Create attributions
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](2);

        // Attribution for publisher 1
        attributions[0] = AdvertisementConversion.Attribution({
            payout: Flywheel.Payout({recipient: publisher1, amount: ATTRIBUTION_AMOUNT}),
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click_123",
                conversionConfigId: 0,
                publisherRefCode: pub1RefCode,
                timestamp: uint32(block.timestamp),
                recipientType: 1,
                payoutAmount: ATTRIBUTION_AMOUNT
            }),
            logBytes: "" // Offchain conversion
        });

        // Attribution for publisher 2
        attributions[1] = AdvertisementConversion.Attribution({
            payout: Flywheel.Payout({recipient: publisher2, amount: ATTRIBUTION_AMOUNT}),
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(2)),
                clickId: "click_456",
                conversionConfigId: 0,
                publisherRefCode: pub2RefCode,
                timestamp: uint32(block.timestamp),
                recipientType: 1,
                payoutAmount: ATTRIBUTION_AMOUNT
            }),
            logBytes: "" // Offchain conversion
        });

        // 4. Process attributions
        vm.startPrank(provider);
        bytes memory attributionData = abi.encode(attributions);
        flywheel.allocate(campaign, address(usdc), attributionData);
        vm.stopPrank();

        // 5. Verify attributions were processed
        uint256 expectedPayoutAmount = ATTRIBUTION_AMOUNT - (ATTRIBUTION_AMOUNT * ATTRIBUTION_FEE_BPS / 10000);
        uint256 expectedFeeAmount = ATTRIBUTION_AMOUNT * ATTRIBUTION_FEE_BPS / 10000;

        assertEq(flywheel.payouts(address(usdc), publisher1), expectedPayoutAmount);
        assertEq(flywheel.payouts(address(usdc), publisher2), expectedPayoutAmount);
        assertEq(flywheel.fees(address(usdc), provider), expectedFeeAmount * 2);

        // 6. Distribute payouts to publishers
        vm.startPrank(publisher1);
        flywheel.distributePayouts(address(usdc), publisher1);
        vm.stopPrank();

        vm.startPrank(publisher2);
        flywheel.distributePayouts(address(usdc), publisher2);
        vm.stopPrank();

        // 7. Verify publishers received their payments
        assertEq(usdc.balanceOf(publisher1), expectedPayoutAmount);
        assertEq(usdc.balanceOf(publisher2), expectedPayoutAmount);

        // 8. Provider collects fees
        vm.startPrank(provider);
        flywheel.collectFees(address(usdc), provider);
        vm.stopPrank();

        assertEq(usdc.balanceOf(provider), 1000000 * 1e18 + expectedFeeAmount * 2); // Initial balance + fees

        // 9. Close campaign
        vm.startPrank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.CLOSED, "");
        vm.stopPrank();

        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.CLOSED));

        // 10. Wait for finalization period and finalize
        vm.warp(block.timestamp + 7 days + 1);

        vm.startPrank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");
        vm.stopPrank();

        assertEq(uint8(flywheel.campaignStatus(campaign)), uint8(Flywheel.CampaignStatus.FINALIZED));

        // 11. Withdraw remaining funds
        uint256 remainingFunds = usdc.balanceOf(campaign);
        vm.startPrank(advertiser);
        flywheel.withdrawFunds(campaign, address(usdc), remainingFunds, "");
        vm.stopPrank();

        assertEq(usdc.balanceOf(campaign), 0);
        console2.log("Test completed successfully!");
    }

    function test_onchainConversion() public {
        // Open campaign
        vm.startPrank(provider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.OPEN, "");
        vm.stopPrank();

        // Create onchain attribution with log data
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

        AdvertisementConversion.Log memory logData =
            AdvertisementConversion.Log({chainId: block.chainid, transactionHash: keccak256("test_tx"), index: 0});

        attributions[0] = AdvertisementConversion.Attribution({
            payout: Flywheel.Payout({recipient: publisher1, amount: ATTRIBUTION_AMOUNT}),
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "onchain_click_123",
                conversionConfigId: 1,
                publisherRefCode: pub1RefCode,
                timestamp: uint32(block.timestamp),
                recipientType: 1,
                payoutAmount: ATTRIBUTION_AMOUNT
            }),
            logBytes: abi.encode(logData)
        });

        // Process onchain attribution
        vm.startPrank(provider);
        bytes memory attributionData = abi.encode(attributions);

        // Expect OnchainConversion event
        vm.expectEmit(true, false, false, true);
        emit AdvertisementConversion.OnchainConversionProcessed(campaign, attributions[0].conversion, logData);

        flywheel.allocate(campaign, address(usdc), attributionData);
        vm.stopPrank();

        // Verify attribution processed correctly
        uint256 expectedPayoutAmount = ATTRIBUTION_AMOUNT - (ATTRIBUTION_AMOUNT * ATTRIBUTION_FEE_BPS / 10000);
        assertEq(flywheel.payouts(address(usdc), publisher1), expectedPayoutAmount);
    }

    function test_unauthorizedAccessReverts() public {
        // Try to update status as unauthorized user
        vm.startPrank(makeAddr("unauthorized"));
        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.OPEN, "");
        vm.stopPrank();

        // Open the campaign properly first
        vm.startPrank(provider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.OPEN, "");
        vm.stopPrank();

        // Try to allocate as unauthorized provider
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            payout: Flywheel.Payout({recipient: publisher1, amount: ATTRIBUTION_AMOUNT}),
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click_123",
                conversionConfigId: 0,
                publisherRefCode: pub1RefCode,
                timestamp: uint32(block.timestamp),
                recipientType: 1,
                payoutAmount: ATTRIBUTION_AMOUNT
            }),
            logBytes: ""
        });

        vm.startPrank(makeAddr("unauthorized_provider"));
        bytes memory attributionData = abi.encode(attributions);
        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
        flywheel.allocate(campaign, address(usdc), attributionData);
        vm.stopPrank();

        // Try to withdraw funds as unauthorized user
        vm.startPrank(makeAddr("unauthorized"));
        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
        flywheel.withdrawFunds(campaign, address(usdc), 100, "");
        vm.stopPrank();
    }

    function test_publisherOverrideAddresses() public {
        // Test publisher 1 overrides
        assertEq(publisherRegistry.getPublisherPayoutAddress(pub1RefCode, 1), makeAddr("publisher1_ethereum"));
        assertEq(publisherRegistry.getPublisherPayoutAddress(pub1RefCode, 137), makeAddr("publisher1_polygon"));
        // Should use default for chain without override
        assertEq(publisherRegistry.getPublisherPayoutAddress(pub1RefCode, 999), publisher1);

        // Test publisher 2 overrides
        assertEq(publisherRegistry.getPublisherPayoutAddress(pub2RefCode, 42161), makeAddr("publisher2_arbitrum"));
        // Should use default for chain without override
        assertEq(publisherRegistry.getPublisherPayoutAddress(pub2RefCode, 1), publisher2);
        assertEq(publisherRegistry.getPublisherPayoutAddress(pub2RefCode, 999), publisher2);

        console2.log("All override addresses verified successfully!");
    }

    function test_conversionConfigManagement() public {
        // Test adding a new conversion config
        ConversionConfig memory newConfig = ConversionConfig({
            status: ConversionConfigStatus.ACTIVE,
            eventType: EventType.OFFCHAIN,
            conversionMetadataUrl: "https://campaign.com/new-config-metadata"
        });

        // Only advertiser can add conversion configs
        vm.startPrank(advertiser);
        vm.expectEmit(true, true, false, true);
        emit AdvertisementConversion.ConversionConfigAdded(campaign, 2, newConfig);
        adHook.addConversionConfig(campaign, newConfig);
        vm.stopPrank();

        // Verify the new config was added
        ConversionConfig memory retrievedConfig = adHook.getConversionConfig(campaign, 2);
        assertEq(uint8(retrievedConfig.status), uint8(ConversionConfigStatus.ACTIVE));
        assertEq(uint8(retrievedConfig.eventType), uint8(EventType.OFFCHAIN));
        assertEq(retrievedConfig.conversionMetadataUrl, "https://campaign.com/new-config-metadata");

        // Test disabling a conversion config
        vm.startPrank(advertiser);
        vm.expectEmit(true, true, false, true);
        emit AdvertisementConversion.ConversionConfigStatusChanged(campaign, 0, ConversionConfigStatus.DISABLED);
        adHook.disableConversionConfig(campaign, 0);
        vm.stopPrank();

        // Verify the config was disabled
        ConversionConfig memory disabledConfig = adHook.getConversionConfig(campaign, 0);
        assertEq(uint8(disabledConfig.status), uint8(ConversionConfigStatus.DISABLED));

        // Test that unauthorized users cannot manage configs
        vm.startPrank(makeAddr("unauthorized"));
        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
        adHook.addConversionConfig(campaign, newConfig);

        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
        adHook.disableConversionConfig(campaign, 1);
        vm.stopPrank();

        // Test trying to use disabled config in attribution should fail
        vm.startPrank(provider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.OPEN, "");
        vm.stopPrank();

        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            payout: Flywheel.Payout({recipient: publisher1, amount: ATTRIBUTION_AMOUNT}),
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click_disabled_config",
                conversionConfigId: 0, // This config was disabled
                publisherRefCode: pub1RefCode,
                timestamp: uint32(block.timestamp),
                recipientType: 1,
                payoutAmount: ATTRIBUTION_AMOUNT
            }),
            logBytes: ""
        });

        vm.startPrank(provider);
        bytes memory attributionData = abi.encode(attributions);
        vm.expectRevert(AdvertisementConversion.ConversionConfigDisabled.selector);
        flywheel.allocate(campaign, address(usdc), attributionData);
        vm.stopPrank();

        console2.log("Conversion config management tests completed successfully!");
    }
}

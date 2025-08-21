// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../src/Flywheel.sol";
import {BuilderCodes} from "../src/BuilderCodes.sol";
import {AdConversion} from "../src/hooks/AdConversion.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {PublisherTestSetup, PublisherSetupHelper} from "./helpers/PublisherSetupHelper.sol";

contract AdConversionTest is PublisherTestSetup {
    Flywheel public flywheel;
    BuilderCodes public publisherRegistry;
    AdConversion public hook;
    DummyERC20 public token;

    address public owner = address(0x1);
    address public advertiser = address(0x2);
    address public attributionProvider = address(0x3);
    address public randomUser = address(0x4);

    address public campaign;

    function setUp() public {
        // Deploy contracts
        flywheel = new Flywheel();

        // Deploy BuilderCodes as upgradeable proxy
        BuilderCodes implementation = new BuilderCodes();
        bytes memory initData = abi.encodeWithSelector(
            BuilderCodes.initialize.selector,
            owner,
            address(0x999), // signer address
            "" // empty baseURI
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        publisherRegistry = BuilderCodes(address(proxy));

        hook = new AdConversion(address(flywheel), owner, address(publisherRegistry));

        // Deploy token with initial holders
        address[] memory initialHolders = new address[](1);
        initialHolders[0] = address(this);
        token = new DummyERC20(initialHolders);

        // Register randomUser as a publisher with ref code
        vm.prank(owner);
        publisherRegistry.register("random", randomUser, randomUser);

        // Create a campaign with conversion configs
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](2);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: true, metadataURI: "https://example.com/config0"});
        configs[1] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config1"});

        string[] memory allowedRefCodes = new string[](0);

        bytes memory hookData = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs, 7 days
        );

        campaign = flywheel.createCampaign(address(hook), 1, hookData);
    }

    function test_onReward_valid_onchainConversion() public {
        vm.prank(owner);
        publisherRegistry.register("code1", randomUser, randomUser);

        // Set attribution provider fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(1000); // 10%

        // Create attribution with logBytes for ONCHAIN config
        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 1, // ONCHAIN config (1-indexed)
                publisherRefCode: "code1",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(AdConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0}))
        });

        bytes memory hookData = abi.encode(attributions);

        // Call onReward through flywheel
        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, uint256 fee) =
            hook.onReward(attributionProvider, campaign, address(token), hookData);

        // Verify results
        assertEq(payouts.length, 1);
        assertEq(payouts[0].recipient, randomUser);
        assertEq(payouts[0].amount, 90 ether); // 100 - 10% fee
        assertEq(fee, 10 ether);
    }

    function test_onReward_valid_offchainConversion() public {
        vm.prank(owner);
        publisherRegistry.register("code1", randomUser, randomUser);

        // Set attribution provider fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(1000); // 10%

        // Create attribution without logBytes for OFFCHAIN config
        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 2, // OFFCHAIN config (1-indexed)
                publisherRefCode: "code1",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: "" // Empty for offchain
        });

        bytes memory hookData = abi.encode(attributions);

        // Call onReward through flywheel
        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, uint256 fee) =
            hook.onReward(attributionProvider, campaign, address(token), hookData);

        // Verify results
        assertEq(payouts.length, 1);
        assertEq(payouts[0].recipient, randomUser);
        assertEq(payouts[0].amount, 90 ether); // 100 - 10% fee
        assertEq(fee, 10 ether);
    }

    function test_onReward_revert_onchainConversionWithoutLogBytes() public {
        // Create attribution without logBytes for ONCHAIN config (invalid)
        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 1, // ONCHAIN config (1-indexed)
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: "" // Empty logBytes for ONCHAIN is invalid
        });

        bytes memory hookData = abi.encode(attributions);

        // Expect revert
        vm.expectRevert(AdConversion.InvalidConversionType.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, campaign, address(token), hookData);
    }

    function test_onReward_revert_offchainConversionWithLogBytes() public {
        // Create attribution with logBytes for OFFCHAIN config (invalid)
        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 2, // OFFCHAIN config (1-indexed)
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(AdConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0})) // logBytes for OFFCHAIN is invalid
        });

        bytes memory hookData = abi.encode(attributions);

        // Expect revert
        vm.expectRevert(AdConversion.InvalidConversionType.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, campaign, address(token), hookData);
    }

    function test_onReward_ofacFundsRerouting() public {
        // Simulate OFAC-sanctioned address
        address ofacAddress = address(0xBAD);
        address burnAddress = address(0xdead);

        // Give OFAC address some tokens
        token.transfer(ofacAddress, 1000 ether);

        // OFAC address adds funds to campaign by transferring directly
        vm.prank(ofacAddress);
        token.transfer(campaign, 1000 ether);

        // Set attribution provider fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(0); // No fee for burn transaction

        // Attribution provider re-routes the sanctioned funds to burn address
        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(999)), // Unique ID for OFAC re-routing
                clickId: "ofac_sanctioned_funds",
                configId: 0, // No config - unregistered conversion
                publisherRefCode: "", // No publisher
                timestamp: uint32(block.timestamp),
                payoutRecipient: burnAddress, // Send to burn address
                payoutAmount: 1000 ether // Full amount
            }),
            logBytes: "" // Offchain event
        });

        bytes memory hookData = abi.encode(attributions);

        // Expect the event to be emitted
        vm.expectEmit(true, false, false, true);
        emit AdConversion.OffchainConversionProcessed(
            campaign,
            AdConversion.Conversion({
                eventId: bytes16(uint128(999)),
                clickId: "ofac_sanctioned_funds",
                configId: 0,
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: burnAddress,
                payoutAmount: 1000 ether
            })
        );

        // Call onReward through flywheel
        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, uint256 fee) =
            hook.onReward(attributionProvider, campaign, address(token), hookData);

        // Verify results
        assertEq(payouts.length, 1);
        assertEq(payouts[0].recipient, burnAddress);
        assertEq(payouts[0].amount, 1000 ether); // Full amount sent to burn
        assertEq(fee, 0); // No fee taken
    }

    function test_createCampaign_emitsConversionConfigAddedEvents() public {
        // Create conversion configs
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](2);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: true, metadataURI: "https://example.com/config0"});
        configs[1] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config1"});

        string[] memory allowedRefCodes = new string[](0);

        bytes memory hookData = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs, 7 days
        );

        // Calculate expected campaign address
        address expectedCampaign = flywheel.predictCampaignAddress(address(hook), 2, hookData);

        // Expect events for each config (with isActive: true added automatically)
        vm.expectEmit(true, true, false, true);
        emit AdConversion.ConversionConfigAdded(
            expectedCampaign,
            1,
            AdConversion.ConversionConfig({
                isActive: true,
                isEventOnchain: true,
                metadataURI: "https://example.com/config0"
            })
        );

        vm.expectEmit(true, true, false, true);
        emit AdConversion.ConversionConfigAdded(
            expectedCampaign,
            2,
            AdConversion.ConversionConfig({
                isActive: true,
                isEventOnchain: false,
                metadataURI: "https://example.com/config1"
            })
        );

        // Create campaign
        address newCampaign = flywheel.createCampaign(address(hook), 2, hookData);

        assertEq(newCampaign, expectedCampaign);
    }

    function test_createCampaign_emitsPublisherAddedToAllowlistEvents() public {
        // Register additional publishers
        vm.startPrank(owner);
        publisherRegistry.register("code1", address(0x1001), address(0x1001));
        publisherRegistry.register("code2", address(0x1002), address(0x1002));
        vm.stopPrank();

        // Create empty conversion configs
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](0);

        // Create allowlist
        string[] memory allowedRefCodes = new string[](3);
        allowedRefCodes[0] = "code1";
        allowedRefCodes[1] = "code2";
        allowedRefCodes[2] = "code3";

        bytes memory hookData = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs, 7 days
        );

        // Calculate expected campaign address
        address expectedCampaign = flywheel.predictCampaignAddress(address(hook), 3, hookData);

        // Expect events for each publisher
        vm.expectEmit(true, false, false, true);
        emit AdConversion.PublisherAddedToAllowlist(expectedCampaign, "code1");

        vm.expectEmit(true, false, false, true);
        emit AdConversion.PublisherAddedToAllowlist(expectedCampaign, "code2");

        vm.expectEmit(true, false, false, true);
        emit AdConversion.PublisherAddedToAllowlist(expectedCampaign, "code3");

        // Create campaign
        address newCampaign = flywheel.createCampaign(address(hook), 3, hookData);

        assertEq(newCampaign, expectedCampaign);
    }

    function test_createCampaign_emitsAdCampaignCreatedEvent() public {
        // Create conversion configs
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: true, metadataURI: "https://example.com/config"});

        // Create allowlist
        string[] memory allowedRefCodes = new string[](1);
        allowedRefCodes[0] = "code1";

        uint48 attributionDeadline = 7 days;
        string memory uri = "https://example.com/new-campaign";

        bytes memory hookData =
            abi.encode(attributionProvider, advertiser, uri, allowedRefCodes, configs, attributionDeadline);

        // Calculate expected campaign address
        address expectedCampaign = flywheel.predictCampaignAddress(address(hook), 4, hookData);

        // Expect the campaign creation event
        vm.expectEmit(true, false, false, true);
        emit AdConversion.AdCampaignCreated(expectedCampaign, attributionProvider, advertiser, uri, attributionDeadline);

        // Create campaign
        address newCampaign = flywheel.createCampaign(address(hook), 4, hookData);

        assertEq(newCampaign, expectedCampaign);
    }

    function test_addAllowedPublisherRefCode_emitsEvent() public {
        // First create a campaign with allowlist enabled
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](0);
        string[] memory allowedRefCodes = new string[](1);
        allowedRefCodes[0] = "TEST_REF_CODE";

        bytes memory hookData = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs, 7 days
        );

        address allowlistCampaign = flywheel.createCampaign(address(hook), 4, hookData);

        // Register a new publisher
        vm.prank(owner);
        publisherRegistry.register("code1", address(0x2001), address(0x2001));

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit AdConversion.PublisherAddedToAllowlist(allowlistCampaign, "code1");

        // Add publisher to allowlist
        vm.prank(advertiser);
        hook.addAllowedPublisherRefCode(allowlistCampaign, "code1");

        // Verify it was added
        assertTrue(hook.isPublisherRefCodeAllowed(allowlistCampaign, "code1"));
    }

    // =============================================================
    //                    ATTRIBUTION PROVIDER FEE MANAGEMENT
    // =============================================================

    function test_setAttributionProviderFee_success() public {
        uint16 newFee = 750; // 7.5%

        vm.expectEmit(true, false, false, true);
        emit AdConversion.AttributionProviderFeeUpdated(attributionProvider, 0, newFee); // old, new

        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(newFee);

        assertEq(hook.attributionProviderFees(attributionProvider), newFee);
    }

    function test_setAttributionProviderFee_anyoneCanSetOwnFee() public {
        // Any address can set their own attribution provider fee
        vm.prank(randomUser);
        hook.setAttributionProviderFee(1000);

        assertEq(hook.attributionProviderFees(randomUser), 1000);
    }

    function test_setAttributionProviderFee_revert_feeTooHigh() public {
        vm.expectRevert(abi.encodeWithSelector(AdConversion.InvalidFeeBps.selector, 10001));
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(10001); // > 100%
    }

    function test_setAttributionProviderFee_maxFeeAllowed() public {
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(10000); // Exactly 100%

        assertEq(hook.attributionProviderFees(attributionProvider), 10000);
    }

    // =============================================================
    //                    CONVERSION CONFIG MANAGEMENT
    // =============================================================

    function test_addConversionConfig_success() public {
        AdConversion.ConversionConfigInput memory newConfig =
            AdConversion.ConversionConfigInput({isEventOnchain: true, metadataURI: "https://example.com/new-config"});

        vm.expectEmit(true, true, false, true);
        emit AdConversion.ConversionConfigAdded(
            campaign,
            3, // Next ID
            AdConversion.ConversionConfig({
                isActive: true,
                isEventOnchain: true,
                metadataURI: "https://example.com/new-config"
            })
        );

        vm.prank(advertiser);
        hook.addConversionConfig(campaign, newConfig);

        // Verify config was added
        AdConversion.ConversionConfig memory retrievedConfig = hook.getConversionConfig(campaign, 3);
        assertTrue(retrievedConfig.isActive);
        assertTrue(retrievedConfig.isEventOnchain);
        assertEq(retrievedConfig.metadataURI, "https://example.com/new-config");
    }

    function test_addConversionConfig_revert_unauthorized() public {
        AdConversion.ConversionConfigInput memory newConfig =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/unauthorized"});

        vm.expectRevert(AdConversion.Unauthorized.selector);
        vm.prank(randomUser);
        hook.addConversionConfig(campaign, newConfig);
    }

    function test_disableConversionConfig_success() public {
        vm.expectEmit(true, true, false, true);
        emit AdConversion.ConversionConfigStatusChanged(campaign, 1, false);

        vm.prank(advertiser);
        hook.disableConversionConfig(campaign, 1);

        AdConversion.ConversionConfig memory config = hook.getConversionConfig(campaign, 1);
        assertFalse(config.isActive);
    }

    function test_disableConversionConfig_revert_unauthorized() public {
        vm.expectRevert(AdConversion.Unauthorized.selector);
        vm.prank(randomUser);
        hook.disableConversionConfig(campaign, 1);
    }

    function test_disableConversionConfig_revert_invalidId() public {
        vm.expectRevert(AdConversion.InvalidConversionConfigId.selector);
        vm.prank(advertiser);
        hook.disableConversionConfig(campaign, 99); // uint8 max is 255
    }

    // Note: There's no enableConversionConfig function - configs cannot be re-enabled once disabled
    // This is by design to prevent accidental re-activation of disabled conversion types

    // =============================================================
    //                    PUBLISHER ALLOWLIST MANAGEMENT
    // =============================================================

    // Note: There's no removeAllowedPublisherRefCode function - publishers cannot be removed once added
    // This is by design to prevent accidental removal of authorized publishers

    function test_isPublisherRefCodeAllowed_noAllowlist(uint16 codeNum) public {
        // Campaign with empty allowlist should allow all publishers
        assertTrue(hook.isPublisherRefCodeAllowed(campaign, generateCode(codeNum)));
    }

    // =============================================================
    //                    EDGE CASES AND ERROR HANDLING
    // =============================================================

    function test_onReward_revert_unauthorizedAttributionProvider() public {
        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 1,
                publisherRefCode: "code1",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(AdConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0}))
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(AdConversion.Unauthorized.selector);
        vm.prank(address(flywheel)); // Called from flywheel but with wrong attribution provider
        hook.onReward(randomUser, campaign, address(token), hookData); // randomUser not the campaign's attribution provider
    }

    function test_onReward_revert_invalidConversionConfigId() public {
        vm.prank(owner);
        publisherRegistry.register("code1", address(0x1001), address(0x1001));

        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 99, // Invalid config ID
                publisherRefCode: "code1",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: ""
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(AdConversion.InvalidConversionConfigId.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, campaign, address(token), hookData);
    }

    function test_onReward_revert_disabledConversionConfig() public {
        // Disable config 1
        vm.prank(advertiser);
        hook.disableConversionConfig(campaign, 1);

        vm.prank(owner);
        publisherRegistry.register("code1", address(0x1001), address(0x1001));

        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 1, // Disabled config
                publisherRefCode: "code1",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(AdConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0}))
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(AdConversion.ConversionConfigDisabled.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, campaign, address(token), hookData);
    }

    function test_onReward_revert_publisherNotInAllowlist() public {
        // Register a publisher that will NOT be in the allowlist
        vm.prank(owner);
        publisherRegistry.register("notonallowlist", address(0x9999), address(0x9999));

        // Create campaign with specific allowlist that DOESN'T include the registered publisher
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config"});

        string[] memory allowedRefCodes = new string[](1);
        allowedRefCodes[0] = "code1"; // Only code1 is allowed

        bytes memory hookData = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs, 7 days
        );

        address limitedCashbackCampaign = flywheel.createCampaign(address(hook), 5, hookData);

        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 1,
                publisherRefCode: "notonallowlist", // Registered but not in allowlist
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: ""
        });

        bytes memory rewardData = abi.encode(attributions);

        vm.expectRevert(AdConversion.PublisherNotAllowed.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, limitedCashbackCampaign, address(token), rewardData);
    }

    function test_onReward_revert_publisherNotRegistered() public {
        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 2,
                publisherRefCode: "code2",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: ""
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(AdConversion.InvalidPublisherRefCode.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, campaign, address(token), hookData);
    }

    // =============================================================
    //                    BATCH ATTRIBUTION PROCESSING
    // =============================================================

    function test_onReward_batchAttributions() public {
        // Register additional publishers
        vm.startPrank(owner);
        publisherRegistry.register("code1", address(0x1001), address(0x1001));
        publisherRegistry.register("code2", address(0x1002), address(0x1002));
        vm.stopPrank();

        // Set attribution provider fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(500); // 5%

        // Create batch of attributions
        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](3);

        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click1",
                configId: 1,
                publisherRefCode: "random",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(AdConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0}))
        });

        attributions[1] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(2)),
                clickId: "click2",
                configId: 2,
                publisherRefCode: "code1",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 200 ether
            }),
            logBytes: ""
        });

        attributions[2] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(3)),
                clickId: "click3",
                configId: 2,
                publisherRefCode: "code2",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0x2222), // Custom recipient
                payoutAmount: 150 ether
            }),
            logBytes: ""
        });

        bytes memory hookData = abi.encode(attributions);

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, uint256 fee) =
            hook.onReward(attributionProvider, campaign, address(token), hookData);

        // Verify results
        assertEq(payouts.length, 3);

        // First attribution: "code3" publisher (randomUser)
        assertEq(payouts[0].recipient, randomUser);
        assertEq(payouts[0].amount, 95 ether); // 100 - 5%

        // Second attribution: "code1" publisher
        assertEq(payouts[1].recipient, address(0x1001));
        assertEq(payouts[1].amount, 190 ether); // 200 - 5%

        // Third attribution: Custom recipient
        assertEq(payouts[2].recipient, address(0x2222));
        assertEq(payouts[2].amount, 142.5 ether); // 150 - 5%

        // Total fee: 5% of (100 + 200 + 150) = 22.5 ether
        assertEq(fee, 22.5 ether);
    }

    // =============================================================
    //                    STATUS UPDATE HOOKS
    // =============================================================

    function test_onUpdateStatus_success() public {
        vm.prank(address(flywheel));
        hook.onUpdateStatus(
            attributionProvider, campaign, Flywheel.CampaignStatus.INACTIVE, Flywheel.CampaignStatus.ACTIVE, ""
        );
        // Should not revert - hook allows all status transitions
    }

    function test_onUpdateStatus_revert_unauthorized() public {
        vm.expectRevert(AdConversion.Unauthorized.selector);
        vm.prank(address(flywheel)); // Called from flywheel but with wrong sender
        hook.onUpdateStatus(
            randomUser, // randomUser is not the campaign's attribution provider
            campaign,
            Flywheel.CampaignStatus.INACTIVE,
            Flywheel.CampaignStatus.ACTIVE,
            ""
        );
    }

    // =============================================================
    //                    UNSUPPORTED OPERATIONS
    // =============================================================

    function test_onAllocate_revert_unsupported() public {
        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 1,
                publisherRefCode: "code1",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(AdConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0}))
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(); // Should revert with unsupported operation
        vm.prank(address(flywheel));
        hook.onAllocate(attributionProvider, campaign, address(token), hookData);
    }

    function test_onDeallocate_revert_unsupported() public {
        AdConversion.Attribution[] memory attributions = new AdConversion.Attribution[](1);
        attributions[0] = AdConversion.Attribution({
            conversion: AdConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                configId: 1,
                publisherRefCode: "code1",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(AdConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0}))
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(); // Should revert with unsupported operation
        vm.prank(address(flywheel));
        hook.onDeallocate(attributionProvider, campaign, address(token), hookData);
    }

    function test_onDistribute_revert_unsupported() public {
        vm.expectRevert(); // Should revert with unsupported operation
        vm.prank(address(flywheel));
        hook.onDistribute(attributionProvider, campaign, address(token), "");
    }

    // =============================================================
    //                    CAMPAIGN URI AND METADATA
    // =============================================================

    function test_campaignURI_returnsCorrectURI() public {
        string memory uri = hook.campaignURI(campaign);
        assertEq(uri, "https://example.com/campaign");
    }

    function test_getConversionConfig_returnsCorrectConfig() public {
        AdConversion.ConversionConfig memory config1 = hook.getConversionConfig(campaign, 1);
        assertTrue(config1.isActive);
        assertTrue(config1.isEventOnchain);
        assertEq(config1.metadataURI, "https://example.com/config0");

        AdConversion.ConversionConfig memory config2 = hook.getConversionConfig(campaign, 2);
        assertTrue(config2.isActive);
        assertFalse(config2.isEventOnchain);
        assertEq(config2.metadataURI, "https://example.com/config1");
    }

    function test_getConversionConfig_revert_invalidId() public {
        vm.expectRevert(AdConversion.InvalidConversionConfigId.selector);
        hook.getConversionConfig(campaign, 99);
    }

    function test_attributionProvider_cannotRevertFromFinalizingToActive() public {
        // Create campaign and move to ACTIVE
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Advertiser moves to FINALIZING
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");

        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZING));

        // Attribution provider should NOT be able to revert to ACTIVE
        vm.prank(attributionProvider);
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
    }

    function test_attributionProvider_cannotRevertFromFinalizingToInactive() public {
        // Create campaign and move to ACTIVE
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Advertiser moves to FINALIZING
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");

        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZING));

        // Attribution provider should NOT be able to revert to INACTIVE
        vm.prank(attributionProvider);
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.INACTIVE, "");
    }

    function test_attributionProvider_canTransitionFromFinalizingToFinalized() public {
        // Create campaign and move to ACTIVE
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Advertiser moves to FINALIZING
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");

        // Attribution provider CAN transition to FINALIZED (valid transition)
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");

        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZED));
    }

    function test_attributionProvider_cannotPauseCampaign() public {
        // Start with ACTIVE campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));

        // Attribution provider CANNOT pause campaign (ACTIVE → INACTIVE) - this transition is now blocked
        vm.prank(attributionProvider);
        vm.expectRevert(AdConversion.Unauthorized.selector);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.INACTIVE, "");

        // Campaign remains active - ACTIVE → INACTIVE transitions are no longer allowed
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));
    }

    function test_maliciousPause_nowBlocked() public {
        // Start ACTIVE campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Malicious/uncooperative attribution provider tries to pause campaign but fails
        vm.prank(attributionProvider);
        vm.expectRevert(AdConversion.Unauthorized.selector);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.INACTIVE, "");

        // Campaign remains ACTIVE - malicious pause is now blocked
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));

        // Attribution provider can still perform other valid transitions like ACTIVE → FINALIZING
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZING));
    }

    // =============================================================
    //                    STATE TRANSITION PERMISSIONS
    // =============================================================

    /// @notice Test that Advertiser CANNOT transition INACTIVE → ACTIVE
    function test_advertiserCannotActivateCampaign() public {
        // Verify campaign starts INACTIVE
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.INACTIVE));

        // Advertiser should NOT be able to activate campaign - should revert
        vm.expectRevert(AdConversion.Unauthorized.selector);
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Campaign should still be INACTIVE
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.INACTIVE));
    }

    /// @notice Test that only Attribution Provider can activate campaigns
    function test_onlyAttributionProviderCanActivate() public {
        // Verify campaign starts INACTIVE
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.INACTIVE));

        // Attribution Provider CAN activate
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));
    }

    /// @notice Test Advertiser can only do ACTIVE → FINALIZING, not other transitions
    function test_advertiserLimitedStateTransitions() public {
        // Start with ACTIVE campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Advertiser CAN do ACTIVE → FINALIZING
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZING));

        // Create a second campaign to test ACTIVE → INACTIVE restriction
        // (Cannot reset from FINALIZING back to ACTIVE due to core Flywheel state machine)
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](0);
        string[] memory allowedRefCodes = new string[](0);
        bytes memory hookData2 = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign2", allowedRefCodes, configs, 7 days
        );

        address campaign2 = flywheel.createCampaign(address(hook), 999, hookData2);

        // Activate the second campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign2, Flywheel.CampaignStatus.ACTIVE, "");

        // Advertiser CANNOT do ACTIVE → INACTIVE
        vm.expectRevert(AdConversion.Unauthorized.selector);
        vm.prank(advertiser);
        flywheel.updateStatus(campaign2, Flywheel.CampaignStatus.INACTIVE, "");
    }

    /// @notice Test Attribution Provider has full state transition control
    function test_attributionProviderControlExceptActivePause() public {
        // Attribution Provider can do INACTIVE → ACTIVE
        vm.startPrank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));

        // Attribution Provider CANNOT do ACTIVE → INACTIVE (this transition is now blocked)
        vm.expectRevert(AdConversion.Unauthorized.selector);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.INACTIVE, "");

        // Campaign remains ACTIVE
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));

        // Attribution Provider can do ACTIVE → FINALIZING
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZING));

        // Attribution Provider can do FINALIZING → FINALIZED (no deadline wait)
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZED));

        vm.stopPrank();
    }

    /// @notice Test Advertiser can transition from ACTIVE → FINALIZING directly (no pause state needed)
    function test_advertiserCanFinalizeFromActive() public {
        // Start with ACTIVE campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Advertiser can go directly from ACTIVE → FINALIZING (no need for pause/escape route)
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZING));

        // After deadline passes, advertiser can finalize
        vm.warp(block.timestamp + 8 days);
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZED));
    }

    function test_campaignCreation_customAttributionDeadline() public {
        // Create campaign with 14-day attribution deadline
        uint48 customDeadline = 14 days;
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config"});

        string[] memory allowedRefCodes = new string[](0);
        bytes memory hookData = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs, customDeadline
        );

        address customCampaign = flywheel.createCampaign(address(hook), 999, hookData);

        // Get campaign state to verify custom attribution window duration
        (,,, uint48 storedDuration,) = hook.state(customCampaign);
        assertEq(storedDuration, customDeadline);
    }

    function test_campaignCreation_zeroDeadlineAllowed() public {
        // Create campaign with 0 attribution deadline (instant finalization allowed)
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config"});

        string[] memory allowedRefCodes = new string[](0);
        bytes memory hookData = abi.encode(
            attributionProvider,
            advertiser,
            "https://example.com/campaign",
            allowedRefCodes,
            configs,
            uint48(0) // Valid - allows instant finalization
        );

        address zeroCampaign = flywheel.createCampaign(address(hook), 998, hookData);

        // Verify zero deadline is stored correctly
        (,,, uint48 storedDuration,) = hook.state(zeroCampaign);
        assertEq(storedDuration, 0);
    }

    function test_campaignCreation_revert_invalidPrecision() public {
        // Try to create with 1.5 days (not days precision)
        uint48 invalidDeadline = 1 days + 12 hours;
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config"});

        string[] memory allowedRefCodes = new string[](0);
        bytes memory hookData = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs, invalidDeadline
        );

        vm.expectRevert(abi.encodeWithSelector(AdConversion.InvalidAttributionWindow.selector, invalidDeadline));
        flywheel.createCampaign(address(hook), 997, hookData);
    }

    function test_campaignCreation_revert_hoursMinutesPrecision() public {
        // Test various invalid durations that are not in days precision
        uint48[] memory invalidDurations = new uint48[](4);
        invalidDurations[0] = 2 hours; // Just hours
        invalidDurations[1] = 3 days + 5 hours; // Days with hours
        invalidDurations[2] = 7 days + 30 minutes; // Days with minutes
        invalidDurations[3] = 10 days + 45 seconds; // Days with seconds

        for (uint256 i = 0; i < invalidDurations.length; i++) {
            AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
            configs[0] =
                AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config"});

            string[] memory allowedRefCodes = new string[](0);
            bytes memory hookData = abi.encode(
                attributionProvider,
                advertiser,
                "https://example.com/campaign",
                allowedRefCodes,
                configs,
                invalidDurations[i]
            );

            vm.expectRevert(abi.encodeWithSelector(AdConversion.InvalidAttributionWindow.selector, invalidDurations[i]));
            flywheel.createCampaign(address(hook), 996 - i, hookData);
        }
    }

    function test_finalization_usesPerCampaignDeadline() public {
        // Create campaign with 21-day attribution deadline
        uint48 customDeadline = 21 days;
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config"});

        string[] memory allowedRefCodes = new string[](0);
        bytes memory hookData = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs, customDeadline
        );

        address customCampaign = flywheel.createCampaign(address(hook), 996, hookData);

        // Activate and then finalize
        vm.prank(attributionProvider);
        flywheel.updateStatus(customCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        uint256 beforeFinalize = block.timestamp;
        vm.prank(advertiser);
        flywheel.updateStatus(customCampaign, Flywheel.CampaignStatus.FINALIZING, "");

        // Check that attribution deadline uses custom duration
        (,,,, uint48 deadline) = hook.state(customCampaign);
        assertEq(deadline, beforeFinalize + customDeadline);
    }

    function test_hasPublisherAllowlist_noAllowlist() public {
        assertEq(hook.hasPublisherAllowlist(campaign), false);
    }

    function test_hasPublisherAllowlist_withAllowlist() public {
        // Create campaign with allowlist using ref codes
        string[] memory allowedRefCodes = new string[](1);
        allowedRefCodes[0] = "TEST_REF_CODE";

        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/metadata"});

        bytes memory hookData = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs, 7 days
        );

        address campaignWithAllowlist = flywheel.createCampaign(address(hook), 2, hookData);

        assertEq(hook.hasPublisherAllowlist(campaignWithAllowlist), true);
    }

    function test_campaignCreation_oneDayDeadlineAllowed() public {
        // Create campaign with 1 day (minimum) attribution deadline
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config"});

        string[] memory allowedRefCodes = new string[](0);
        bytes memory hookData = abi.encode(
            attributionProvider,
            advertiser,
            "https://example.com/campaign",
            allowedRefCodes,
            configs,
            uint48(1 days) // Minimum allowed value
        );

        address minCampaign = flywheel.createCampaign(address(hook), 995, hookData);

        // Should use 1 day
        (,,, uint48 storedDuration,) = hook.state(minCampaign);
        assertEq(storedDuration, 1 days);
    }

    function test_campaignCreation_largeDeadlineAllowed() public {
        // Create campaign with 365-day attribution deadline (now allowed since no max)
        uint48 largeDeadline = 365 days;
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config"});

        string[] memory allowedRefCodes = new string[](0);
        bytes memory hookData = abi.encode(
            attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs, largeDeadline
        );

        address largeCampaign = flywheel.createCampaign(address(hook), 994, hookData);

        // Should use the large deadline
        (,,, uint48 storedDuration,) = hook.state(largeCampaign);
        assertEq(storedDuration, largeDeadline);
        assertEq(storedDuration, 365 days); // Verify it's actually 365 days
    }

    function test_finalization_usesMinimumDeadline() public {
        // Create campaign with 1 day deadline (minimum)
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config"});

        string[] memory allowedRefCodes = new string[](0);
        bytes memory hookData = abi.encode(
            attributionProvider,
            advertiser,
            "https://example.com/campaign",
            allowedRefCodes,
            configs,
            uint48(1 days) // Minimum deadline
        );

        address minCampaign = flywheel.createCampaign(address(hook), 993, hookData);

        // Activate and then finalize
        vm.prank(attributionProvider);
        flywheel.updateStatus(minCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        uint256 beforeFinalize = block.timestamp;
        vm.prank(advertiser);
        flywheel.updateStatus(minCampaign, Flywheel.CampaignStatus.FINALIZING, "");

        // Check that attribution deadline uses 1 day
        (,,,, uint48 deadline) = hook.state(minCampaign);
        assertEq(deadline, beforeFinalize + 1 days);
    }

    function test_finalization_instantWithZeroDeadline() public {
        // Create campaign with 0 deadline (instant finalization)
        AdConversion.ConversionConfigInput[] memory configs = new AdConversion.ConversionConfigInput[](1);
        configs[0] =
            AdConversion.ConversionConfigInput({isEventOnchain: false, metadataURI: "https://example.com/config"});

        string[] memory allowedRefCodes = new string[](0);
        bytes memory hookData = abi.encode(
            attributionProvider,
            advertiser,
            "https://example.com/campaign",
            allowedRefCodes,
            configs,
            uint48(0) // Zero deadline for instant finalization
        );

        address instantCampaign = flywheel.createCampaign(address(hook), 992, hookData);

        // Activate
        vm.prank(attributionProvider);
        flywheel.updateStatus(instantCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Move to finalizing
        vm.prank(advertiser);
        flywheel.updateStatus(instantCampaign, Flywheel.CampaignStatus.FINALIZING, "");

        // With zero deadline, advertiser can finalize immediately
        vm.prank(advertiser);
        flywheel.updateStatus(instantCampaign, Flywheel.CampaignStatus.FINALIZED, "");

        // Verify campaign is finalized
        assertEq(uint256(flywheel.campaignStatus(instantCampaign)), uint256(Flywheel.CampaignStatus.FINALIZED));
    }

    function test_onUpdateMetadata_success() public {
        bytes memory hookData = abi.encode("test data");

        // Should succeed when called by advertiser
        vm.prank(address(flywheel));
        hook.onUpdateMetadata(advertiser, campaign, hookData);
    }

    function test_onUpdateMetadata_revert_unauthorized() public {
        bytes memory hookData = abi.encode("test data");

        vm.expectRevert(AdConversion.Unauthorized.selector);
        vm.prank(address(flywheel));
        hook.onUpdateMetadata(randomUser, campaign, hookData);
    }
}

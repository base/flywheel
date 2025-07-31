// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../src/Flywheel.sol";
import {ReferralCodeRegistry} from "../src/ReferralCodeRegistry.sol";
import {AdvertisementConversion} from "../src/hooks/AdvertisementConversion.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AdvertisementConversionTest is Test {
    Flywheel public flywheel;
    ReferralCodeRegistry public publisherRegistry;
    AdvertisementConversion public hook;
    DummyERC20 public token;

    address public owner = address(0x1);
    address public advertiser = address(0x2);
    address public attributionProvider = address(0x3);
    address public randomUser = address(0x4);

    address public campaign;

    function setUp() public {
        // Deploy contracts
        flywheel = new Flywheel();

        // Deploy ReferralCodeRegistry as upgradeable proxy
        ReferralCodeRegistry implementation = new ReferralCodeRegistry();
        bytes memory initData = abi.encodeWithSelector(
            ReferralCodeRegistry.initialize.selector,
            owner,
            address(0x999) // signer address
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        publisherRegistry = ReferralCodeRegistry(address(proxy));

        hook = new AdvertisementConversion(address(flywheel), owner, address(publisherRegistry));

        // Deploy token with initial holders
        address[] memory initialHolders = new address[](1);
        initialHolders[0] = address(this);
        token = new DummyERC20(initialHolders);

        // Register randomUser as a publisher with ref code
        vm.prank(owner);
        publisherRegistry.registerCustom(
            "TEST_REF_CODE",
            randomUser,
            randomUser, // default payout address
            "https://example.com/publisher"
        );

        // Create a campaign with conversion configs
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](2);
        configs[0] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: true,
            conversionMetadataUrl: "https://example.com/config0"
        });
        configs[1] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: false,
            conversionMetadataUrl: "https://example.com/config1"
        });

        string[] memory allowedRefCodes = new string[](0);

        bytes memory hookData =
            abi.encode(attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs);

        campaign = flywheel.createCampaign(address(hook), 1, hookData);
    }

    function test_updateConversionConfigMetadata_asAdvertiser() public {
        // Update as advertiser
        vm.prank(advertiser);
        hook.updateConversionConfigMetadata(campaign, 1);

        // Verify the metadata URL hasn't changed
        AdvertisementConversion.ConversionConfig memory config = hook.getConversionConfig(campaign, 1);
        assertEq(config.conversionMetadataUrl, "https://example.com/config0");
    }

    function test_updateConversionConfigMetadata_asAttributionProvider() public {
        // Update as attribution provider
        vm.prank(attributionProvider);
        hook.updateConversionConfigMetadata(campaign, 2);

        // Verify the metadata URL hasn't changed
        AdvertisementConversion.ConversionConfig memory config = hook.getConversionConfig(campaign, 2);
        assertEq(config.conversionMetadataUrl, "https://example.com/config1");
    }

    function test_updateConversionConfigMetadata_emitsEvent() public {
        // Expect the event
        vm.expectEmit(true, true, false, true);
        emit AdvertisementConversion.ConversionConfigMetadataUpdated(campaign, 1);

        // Update as advertiser
        vm.prank(advertiser);
        hook.updateConversionConfigMetadata(campaign, 1);
    }

    function test_updateConversionConfigMetadata_revert_unauthorized() public {
        // Try to update as random user
        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
        vm.prank(randomUser);
        hook.updateConversionConfigMetadata(campaign, 1);
    }

    function test_updateConversionConfigMetadata_revert_invalidConfigId() public {
        // Try to update metadata for non-existent config ID (3, when we only have 2 configs)
        vm.expectRevert(AdvertisementConversion.InvalidConversionConfigId.selector);
        vm.prank(advertiser);
        hook.updateConversionConfigMetadata(campaign, 3);
    }

    function test_updateConversionConfigMetadata_revert_zeroConfigId() public {
        // Try to update metadata for config ID 0 (invalid in 1-indexed system)
        vm.expectRevert(AdvertisementConversion.InvalidConversionConfigId.selector);
        vm.prank(advertiser);
        hook.updateConversionConfigMetadata(campaign, 0);
    }

    function test_onReward_valid_onchainConversion() public {
        // Set attribution provider fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(1000); // 10%

        // Create attribution with logBytes for ONCHAIN config
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 1, // ONCHAIN config (1-indexed)
                publisherRefCode: "TEST_REF_CODE",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(
                AdvertisementConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0})
            )
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
        // Set attribution provider fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(1000); // 10%

        // Create attribution without logBytes for OFFCHAIN config
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 2, // OFFCHAIN config (1-indexed)
                publisherRefCode: "TEST_REF_CODE",
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
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 1, // ONCHAIN config (1-indexed)
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: "" // Empty logBytes for ONCHAIN is invalid
        });

        bytes memory hookData = abi.encode(attributions);

        // Expect revert
        vm.expectRevert(AdvertisementConversion.InvalidConversionType.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, campaign, address(token), hookData);
    }

    function test_onReward_revert_offchainConversionWithLogBytes() public {
        // Create attribution with logBytes for OFFCHAIN config (invalid)
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 2, // OFFCHAIN config (1-indexed)
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(
                AdvertisementConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0})
            ) // logBytes for OFFCHAIN is invalid
        });

        bytes memory hookData = abi.encode(attributions);

        // Expect revert
        vm.expectRevert(AdvertisementConversion.InvalidConversionType.selector);
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
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(999)), // Unique ID for OFAC re-routing
                clickId: "ofac_sanctioned_funds",
                conversionConfigId: 0, // No config - unregistered conversion
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
        emit AdvertisementConversion.OffchainConversionProcessed(
            campaign,
            AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(999)),
                clickId: "ofac_sanctioned_funds",
                conversionConfigId: 0,
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
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](2);
        configs[0] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: true,
            conversionMetadataUrl: "https://example.com/config0"
        });
        configs[1] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: false,
            conversionMetadataUrl: "https://example.com/config1"
        });

        string[] memory allowedRefCodes = new string[](0);

        bytes memory hookData =
            abi.encode(attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs);

        // Calculate expected campaign address
        address expectedCampaign = flywheel.campaignAddress(2, hookData);

        // Expect events for each config (with isActive: true added automatically)
        vm.expectEmit(true, true, false, true);
        emit AdvertisementConversion.ConversionConfigAdded(
            expectedCampaign,
            1,
            AdvertisementConversion.ConversionConfig({
                isActive: true,
                isEventOnchain: true,
                conversionMetadataUrl: "https://example.com/config0"
            })
        );

        vm.expectEmit(true, true, false, true);
        emit AdvertisementConversion.ConversionConfigAdded(
            expectedCampaign,
            2,
            AdvertisementConversion.ConversionConfig({
                isActive: true,
                isEventOnchain: false,
                conversionMetadataUrl: "https://example.com/config1"
            })
        );

        // Create campaign
        address newCampaign = flywheel.createCampaign(address(hook), 2, hookData);

        assertEq(newCampaign, expectedCampaign);
    }

    function test_createCampaign_emitsPublisherAddedToAllowlistEvents() public {
        // Register additional publishers
        vm.startPrank(owner);
        publisherRegistry.registerCustom("PUB1", address(0x1001), address(0x1001), "https://example.com/pub1");
        publisherRegistry.registerCustom("PUB2", address(0x1002), address(0x1002), "https://example.com/pub2");
        vm.stopPrank();

        // Create empty conversion configs
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](0);

        // Create allowlist
        string[] memory allowedRefCodes = new string[](3);
        allowedRefCodes[0] = "PUB1";
        allowedRefCodes[1] = "PUB2";
        allowedRefCodes[2] = "TEST_REF_CODE";

        bytes memory hookData =
            abi.encode(attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs);

        // Calculate expected campaign address
        address expectedCampaign = flywheel.campaignAddress(3, hookData);

        // Expect events for each publisher
        vm.expectEmit(true, false, false, true);
        emit AdvertisementConversion.PublisherAddedToAllowlist(expectedCampaign, "PUB1");

        vm.expectEmit(true, false, false, true);
        emit AdvertisementConversion.PublisherAddedToAllowlist(expectedCampaign, "PUB2");

        vm.expectEmit(true, false, false, true);
        emit AdvertisementConversion.PublisherAddedToAllowlist(expectedCampaign, "TEST_REF_CODE");

        // Create campaign
        address newCampaign = flywheel.createCampaign(address(hook), 3, hookData);

        assertEq(newCampaign, expectedCampaign);
    }

    function test_addAllowedPublisherRefCode_emitsEvent() public {
        // First create a campaign with allowlist enabled
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](0);
        string[] memory allowedRefCodes = new string[](1);
        allowedRefCodes[0] = "TEST_REF_CODE";

        bytes memory hookData =
            abi.encode(attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs);

        address allowlistCampaign = flywheel.createCampaign(address(hook), 4, hookData);

        // Register a new publisher
        vm.prank(owner);
        publisherRegistry.registerCustom("NEW_PUB", address(0x2001), address(0x2001), "https://example.com/newpub");

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit AdvertisementConversion.PublisherAddedToAllowlist(allowlistCampaign, "NEW_PUB");

        // Add publisher to allowlist
        vm.prank(advertiser);
        hook.addAllowedPublisherRefCode(allowlistCampaign, "NEW_PUB");

        // Verify it was added
        assertTrue(hook.isPublisherAllowed(allowlistCampaign, "NEW_PUB"));
    }

    // =============================================================
    //                    ATTRIBUTION PROVIDER FEE MANAGEMENT
    // =============================================================

    function test_setAttributionProviderFee_success() public {
        uint16 newFee = 750; // 7.5%

        vm.expectEmit(true, false, false, true);
        emit AdvertisementConversion.AttributionProviderFeeUpdated(attributionProvider, 0, newFee); // old, new

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
        vm.expectRevert(abi.encodeWithSelector(AdvertisementConversion.InvalidFeeBps.selector, 10001));
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
        AdvertisementConversion.ConversionConfigInput memory newConfig = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: true,
            conversionMetadataUrl: "https://example.com/new-config"
        });

        vm.expectEmit(true, true, false, true);
        emit AdvertisementConversion.ConversionConfigAdded(
            campaign,
            3, // Next ID
            AdvertisementConversion.ConversionConfig({
                isActive: true,
                isEventOnchain: true,
                conversionMetadataUrl: "https://example.com/new-config"
            })
        );

        vm.prank(advertiser);
        hook.addConversionConfig(campaign, newConfig);

        // Verify config was added
        AdvertisementConversion.ConversionConfig memory retrievedConfig = hook.getConversionConfig(campaign, 3);
        assertTrue(retrievedConfig.isActive);
        assertTrue(retrievedConfig.isEventOnchain);
        assertEq(retrievedConfig.conversionMetadataUrl, "https://example.com/new-config");
    }

    function test_addConversionConfig_revert_unauthorized() public {
        AdvertisementConversion.ConversionConfigInput memory newConfig = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: false,
            conversionMetadataUrl: "https://example.com/unauthorized"
        });

        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
        vm.prank(randomUser);
        hook.addConversionConfig(campaign, newConfig);
    }

    function test_disableConversionConfig_success() public {
        vm.expectEmit(true, true, false, true);
        emit AdvertisementConversion.ConversionConfigStatusChanged(campaign, 1, false);

        vm.prank(advertiser);
        hook.disableConversionConfig(campaign, 1);

        AdvertisementConversion.ConversionConfig memory config = hook.getConversionConfig(campaign, 1);
        assertFalse(config.isActive);
    }

    function test_disableConversionConfig_revert_unauthorized() public {
        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
        vm.prank(randomUser);
        hook.disableConversionConfig(campaign, 1);
    }

    function test_disableConversionConfig_revert_invalidId() public {
        vm.expectRevert(AdvertisementConversion.InvalidConversionConfigId.selector);
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

    function test_isPublisherAllowed_noAllowlist() public {
        // Campaign with empty allowlist should allow all publishers
        assertTrue(hook.isPublisherAllowed(campaign, "ANY_REF_CODE"));
        assertTrue(hook.isPublisherAllowed(campaign, "NONEXISTENT_CODE"));
    }

    // =============================================================
    //                    EDGE CASES AND ERROR HANDLING
    // =============================================================

    function test_onReward_revert_unauthorizedAttributionProvider() public {
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 1,
                publisherRefCode: "TEST_REF_CODE",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(
                AdvertisementConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0})
            )
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
        vm.prank(address(flywheel)); // Called from flywheel but with wrong attribution provider
        hook.onReward(randomUser, campaign, address(token), hookData); // randomUser not the campaign's attribution provider
    }

    function test_onReward_revert_invalidConversionConfigId() public {
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 99, // Invalid config ID
                publisherRefCode: "TEST_REF_CODE",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: ""
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(AdvertisementConversion.InvalidConversionConfigId.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, campaign, address(token), hookData);
    }

    function test_onReward_revert_disabledConversionConfig() public {
        // Disable config 1
        vm.prank(advertiser);
        hook.disableConversionConfig(campaign, 1);

        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 1, // Disabled config
                publisherRefCode: "TEST_REF_CODE",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(
                AdvertisementConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0})
            )
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(AdvertisementConversion.ConversionConfigDisabled.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, campaign, address(token), hookData);
    }

    function test_onReward_revert_publisherNotInAllowlist() public {
        // Register a publisher that will NOT be in the allowlist
        vm.prank(owner);
        publisherRegistry.registerCustom(
            "NOT_ALLOWED_PUBLISHER", address(0x9999), address(0x9999), "https://notallowed.com"
        );

        // Create campaign with specific allowlist that DOESN'T include the registered publisher
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](1);
        configs[0] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: false,
            conversionMetadataUrl: "https://example.com/config"
        });

        string[] memory allowedRefCodes = new string[](1);
        allowedRefCodes[0] = "TEST_REF_CODE"; // Only TEST_REF_CODE is allowed

        bytes memory hookData =
            abi.encode(attributionProvider, advertiser, "https://example.com/campaign", allowedRefCodes, configs);

        address restrictedCampaign = flywheel.createCampaign(address(hook), 5, hookData);

        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 1,
                publisherRefCode: "NOT_ALLOWED_PUBLISHER", // Registered but not in allowlist
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: ""
        });

        bytes memory rewardData = abi.encode(attributions);

        vm.expectRevert(AdvertisementConversion.PublisherNotAllowed.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, restrictedCampaign, address(token), rewardData);
    }

    function test_onReward_revert_publisherNotRegistered() public {
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 2,
                publisherRefCode: "NONEXISTENT_PUBLISHER",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: ""
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(AdvertisementConversion.InvalidPublisherRefCode.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, campaign, address(token), hookData);
    }

    // =============================================================
    //                    BATCH ATTRIBUTION PROCESSING
    // =============================================================

    function test_onReward_batchAttributions() public {
        // Register additional publishers
        vm.startPrank(owner);
        publisherRegistry.registerCustom("PUB1", address(0x1001), address(0x1001), "https://pub1.com");
        publisherRegistry.registerCustom("PUB2", address(0x1002), address(0x1002), "https://pub2.com");
        vm.stopPrank();

        // Set attribution provider fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(500); // 5%

        // Create batch of attributions
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](3);

        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click1",
                conversionConfigId: 1,
                publisherRefCode: "TEST_REF_CODE",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(
                AdvertisementConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0})
            )
        });

        attributions[1] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(2)),
                clickId: "click2",
                conversionConfigId: 2,
                publisherRefCode: "PUB1",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 200 ether
            }),
            logBytes: ""
        });

        attributions[2] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(3)),
                clickId: "click3",
                conversionConfigId: 2,
                publisherRefCode: "PUB2",
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

        // First attribution: TEST_REF_CODE publisher (randomUser)
        assertEq(payouts[0].recipient, randomUser);
        assertEq(payouts[0].amount, 95 ether); // 100 - 5%

        // Second attribution: PUB1 publisher
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
        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
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
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 1,
                publisherRefCode: "TEST_REF_CODE",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(
                AdvertisementConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0})
            )
        });

        bytes memory hookData = abi.encode(attributions);

        vm.expectRevert(); // Should revert with unsupported operation
        vm.prank(address(flywheel));
        hook.onAllocate(attributionProvider, campaign, address(token), hookData);
    }

    function test_onDeallocate_revert_unsupported() public {
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 1,
                publisherRefCode: "TEST_REF_CODE",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 100 ether
            }),
            logBytes: abi.encode(
                AdvertisementConversion.Log({chainId: block.chainid, transactionHash: bytes32(uint256(1)), index: 0})
            )
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
        AdvertisementConversion.ConversionConfig memory config1 = hook.getConversionConfig(campaign, 1);
        assertTrue(config1.isActive);
        assertTrue(config1.isEventOnchain);
        assertEq(config1.conversionMetadataUrl, "https://example.com/config0");

        AdvertisementConversion.ConversionConfig memory config2 = hook.getConversionConfig(campaign, 2);
        assertTrue(config2.isActive);
        assertFalse(config2.isEventOnchain);
        assertEq(config2.conversionMetadataUrl, "https://example.com/config1");
    }

    function test_getConversionConfig_revert_invalidId() public {
        vm.expectRevert(AdvertisementConversion.InvalidConversionConfigId.selector);
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

    function test_attributionProvider_canPauseCampaign_advertiserCannotUnpause() public {
        // Start with ACTIVE campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));
        
        // Attribution provider can pause campaign (ACTIVE → INACTIVE)
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.INACTIVE, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.INACTIVE));
        
        // Advertiser CANNOT unpause their own campaign (INACTIVE → ACTIVE)
        vm.prank(advertiser);
        vm.expectRevert(AdvertisementConversion.Unauthorized.selector);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        
        // Campaign remains paused - advertiser is hostage to attribution provider
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.INACTIVE));
    }

    function test_onlyAttributionProvider_canUnpauseCampaign() public {
        // Start ACTIVE, attribution provider pauses
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.INACTIVE, "");
        
        // Only attribution provider can unpause
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));
    }

    function test_maliciousPause_campaignKilledForever() public {
        // Start ACTIVE campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        
        // Malicious/uncooperative attribution provider pauses campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.INACTIVE, "");
        
        // Advertiser's ONLY escape route is to finalize and withdraw
        // They can go INACTIVE → FINALIZING (this works)
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        
        // Wait for deadline to pass
        vm.warp(block.timestamp + 8 days);
        
        // Then finalize (this works)
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");
        
        // Campaign is now permanently dead - can never be reactivated
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZED));
        
        // Advertiser can withdraw funds but campaign is killed forever
        // No way to ever resume the campaign for publishers/users
    }
}

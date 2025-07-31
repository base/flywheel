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
        publisherRegistry.registerPublisherCustom("PUB1", address(0x1001), "https://example.com/pub1", address(0x1001));
        publisherRegistry.registerPublisherCustom("PUB2", address(0x1002), "https://example.com/pub2", address(0x1002));
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
        publisherRegistry.registerPublisherCustom(
            "NEW_PUB", address(0x2001), "https://example.com/newpub", address(0x2001)
        );

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit AdvertisementConversion.PublisherAddedToAllowlist(allowlistCampaign, "NEW_PUB");

        // Add publisher to allowlist
        vm.prank(advertiser);
        hook.addAllowedPublisherRefCode(allowlistCampaign, "NEW_PUB");

        // Verify it was added
        assertTrue(hook.isPublisherAllowed(allowlistCampaign, "NEW_PUB"));
    }
}

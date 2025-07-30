// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../src/Flywheel.sol";
import {ReferralCodeRegistry} from "../../src/ReferralCodeRegistry.sol";
import {AdvertisementConversion} from "../../src/hooks/AdvertisementConversion.sol";
import {DummyERC20} from "../mocks/DummyERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AdBatchRewardsTest is Test {
    Flywheel public flywheel;
    ReferralCodeRegistry public publisherRegistry;
    AdvertisementConversion public hook;
    DummyERC20 public token;

    address public owner = address(0x1);
    address public advertiser = address(0x2);
    address public attributionProvider = address(0x3);
    address public publisherTba = address(0x4);

    address public campaign;

    // Constants
    uint256 public constant CAMPAIGN_FUNDING = 10000 * 1e6; // 10,000 tokens (6 decimals)
    uint256 public constant PAYOUT_PER_EVENT = 10 * 1e6; // 10 tokens per event
    uint16 public constant ATTRIBUTION_FEE_BPS = 500; // 5% fee in basis points
    string public constant PUBLISHER_REF_CODE = "tba_ref_code";
    string public constant PUBLISHER_METADATA_URL = "https://tba.publisher.com";
    string public constant CAMPAIGN_METADATA_URL = "https://example.com/campaign";

    uint8 public constant RECIPIENT_TYPE_REFERRENT = 0;
    uint8 public constant RECIPIENT_TYPE_PUBLISHER = 1;
    uint8 public constant RECIPIENT_TYPE_USER = 2;

    // Conversion config metadata URLs
    string public constant ONCHAIN_CONFIG_1_URL = "https://example.com/onchain-config-1";
    string public constant ONCHAIN_CONFIG_2_URL = "https://example.com/onchain-config-2";
    string public constant OFFCHAIN_CONFIG_1_URL = "https://example.com/offchain-config-1";

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

        // Deploy token and fund test account
        address[] memory initialHolders = new address[](1);
        initialHolders[0] = address(this);
        token = new DummyERC20(initialHolders);

        // Create campaign with 3 conversion configs (2 onchain, 1 offchain)
        AdvertisementConversion.ConversionConfig[] memory configs = new AdvertisementConversion.ConversionConfig[](3);
        configs[0] = AdvertisementConversion.ConversionConfig({
            isActive: true,
            isEventOnchain: true,
            conversionMetadataUrl: ONCHAIN_CONFIG_1_URL
        });
        configs[1] = AdvertisementConversion.ConversionConfig({
            isActive: true,
            isEventOnchain: true,
            conversionMetadataUrl: ONCHAIN_CONFIG_2_URL
        });
        configs[2] = AdvertisementConversion.ConversionConfig({
            isActive: true,
            isEventOnchain: false,
            conversionMetadataUrl: OFFCHAIN_CONFIG_1_URL
        });

        string[] memory allowedRefCodes = new string[](1);
        allowedRefCodes[0] = PUBLISHER_REF_CODE;

        bytes memory hookData =
            abi.encode(attributionProvider, advertiser, CAMPAIGN_METADATA_URL, allowedRefCodes, configs);

        campaign = flywheel.createCampaign(address(hook), 1, hookData);

        // Fund the campaign
        token.transfer(campaign, CAMPAIGN_FUNDING);

        // Set campaign to ACTIVE status
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Set attribution provider fee
        vm.prank(attributionProvider);
        hook.setAttributionProviderFee(ATTRIBUTION_FEE_BPS);

        // Register publisher
        vm.prank(owner);
        publisherRegistry.registerCustom(PUBLISHER_REF_CODE, publisherTba, publisherTba, PUBLISHER_METADATA_URL);
    }

    function _createAttribution(uint256 eventId, string memory clickIdPrefix, uint8 configId, uint256 txHashSeed)
        internal
        view
        returns (AdvertisementConversion.Attribution memory)
    {
        bool isOffchain = (configId == 3);

        // Generate realistic UUID-like clickId (32 hex chars, no dashes)
        bytes32 hash = keccak256(abi.encode(eventId, block.timestamp));
        string memory clickId = string(abi.encodePacked(clickIdPrefix, vm.toString(uint256(hash))));

        return AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(eventId)),
                clickId: clickId,
                conversionConfigId: configId,
                publisherRefCode: PUBLISHER_REF_CODE,
                timestamp: uint32(block.timestamp),
                payoutRecipient: publisherTba,
                payoutAmount: PAYOUT_PER_EVENT
            }),
            logBytes: isOffchain
                ? bytes("")
                : abi.encode(
                    AdvertisementConversion.Log({
                        chainId: block.chainid,
                        transactionHash: bytes32(uint256(txHashSeed)),
                        index: uint256(eventId)
                    })
                )
        });
    }

    function _createAttributionWithRecipient(
        uint256 eventId,
        string memory clickIdPrefix,
        uint8 configId,
        uint256 txHashSeed,
        address recipient,
        string memory refCode
    ) internal view returns (AdvertisementConversion.Attribution memory) {
        bool isOffchain = (configId == 3);

        // Generate realistic UUID-like clickId (32 hex chars, no dashes)
        bytes32 hash = keccak256(abi.encode(eventId, txHashSeed));
        string memory clickId = string(abi.encodePacked(clickIdPrefix, "0x", _toHexString(uint256(hash))));

        return AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(eventId)),
                clickId: clickId,
                conversionConfigId: configId,
                publisherRefCode: refCode,
                timestamp: uint32(block.timestamp),
                payoutRecipient: recipient,
                payoutAmount: PAYOUT_PER_EVENT
            }),
            logBytes: isOffchain
                ? bytes("")
                : abi.encode(
                    AdvertisementConversion.Log({
                        chainId: 1, // Use fixed chainId for consistency
                        transactionHash: bytes32(uint256(txHashSeed)),
                        index: uint256(eventId)
                    })
                )
        });
    }

    function _toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 16;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 16)));
            if (uint8(buffer[digits]) > 57) {
                buffer[digits] = bytes1(uint8(buffer[digits]) + 39);
            }
            value /= 16;
        }
        return string(buffer);
    }

    function test_batchRewards_1000Events() public {
        uint256 numEvents = 1000;
        // Create 1000 attribution events cycling through all configs
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](numEvents);

        for (uint256 i = 0; i < numEvents; i++) {
            uint8 configId = uint8((i % 3) + 1); // Cycle through configs 1, 2, 3
            attributions[i] = _createAttribution(i + 1, "click_", configId, i + 1);
        }

        bytes memory hookData = abi.encode(attributions);

        // Record initial balances
        uint256 initialCampaignBalance = token.balanceOf(campaign);
        uint256 initialPublisherBalance = token.balanceOf(publisherTba);

        // Execute batch attribution
        vm.prank(attributionProvider);
        flywheel.reward(campaign, address(token), hookData);

        // Calculate expected amounts
        uint256 totalPayout = numEvents * PAYOUT_PER_EVENT;
        uint256 expectedFee = (totalPayout * ATTRIBUTION_FEE_BPS) / 10000;
        uint256 expectedNetPayout = totalPayout - expectedFee;

        // Verify campaign balance decreased by net payout amount only (fee stays in campaign until distributed)
        assertEq(
            token.balanceOf(campaign),
            initialCampaignBalance - expectedNetPayout,
            "Campaign balance should decrease by net payout amount"
        );

        // Verify publisher received net payout
        assertEq(
            token.balanceOf(publisherTba),
            initialPublisherBalance + expectedNetPayout,
            "Publisher should receive net payout after fees"
        );

        // Verify attribution provider fee is allocated (not transferred immediately)
        assertEq(
            flywheel.fees(campaign, address(token), attributionProvider),
            expectedFee,
            "Attribution provider fee should be allocated"
        );

        // Verify total amounts add up correctly
        assertEq(expectedNetPayout + expectedFee, totalPayout, "Net payout plus fee should equal total payout");
    }

    function test_batchRewards_1000Events_10Publishers() public {
        uint256 numEvents = 1000;
        uint256 numPublishers = 10;

        // Register 10 additional publishers
        address[] memory publishers = new address[](numPublishers);
        publishers[0] = publisherTba; // Use existing publisher as first one

        for (uint256 i = 1; i < numPublishers; i++) {
            publishers[i] = address(uint160(0x1000 + i)); // Create unique addresses

            // Register each publisher
            vm.prank(owner);
            publisherRegistry.registerCustom(
                string(abi.encodePacked("pub_", vm.toString(i))),
                publishers[i],
                publishers[i],
                string(abi.encodePacked("https://publisher", vm.toString(i), ".com"))
            );
        }

        // Create a new campaign that allows all publishers (empty allowedRefCodes = allow all)
        AdvertisementConversion.ConversionConfig[] memory configs = new AdvertisementConversion.ConversionConfig[](3);
        configs[0] = AdvertisementConversion.ConversionConfig({
            isActive: true,
            isEventOnchain: true,
            conversionMetadataUrl: ONCHAIN_CONFIG_1_URL
        });
        configs[1] = AdvertisementConversion.ConversionConfig({
            isActive: true,
            isEventOnchain: true,
            conversionMetadataUrl: ONCHAIN_CONFIG_2_URL
        });
        configs[2] = AdvertisementConversion.ConversionConfig({
            isActive: true,
            isEventOnchain: false,
            conversionMetadataUrl: OFFCHAIN_CONFIG_1_URL
        });

        string[] memory allowedRefCodes = new string[](0); // Empty = allow all publishers

        bytes memory newHookData =
            abi.encode(attributionProvider, advertiser, CAMPAIGN_METADATA_URL, allowedRefCodes, configs);

        address multiPublisherCampaign = flywheel.createCampaign(address(hook), 2, newHookData);

        // Fund the new campaign
        token.transfer(multiPublisherCampaign, CAMPAIGN_FUNDING);

        // Set campaign to ACTIVE status
        vm.prank(attributionProvider);
        flywheel.updateStatus(multiPublisherCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Create 1000 attribution events distributed across 10 publishers (100 each)
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](numEvents);

        for (uint256 i = 0; i < numEvents; i++) {
            uint8 configId = uint8((i % 3) + 1); // Cycle through configs 1, 2, 3
            uint256 publisherIndex = i % numPublishers; // Distribute evenly across publishers
            string memory refCode =
                publisherIndex == 0 ? PUBLISHER_REF_CODE : string(abi.encodePacked("pub_", vm.toString(publisherIndex)));

            attributions[i] = AdvertisementConversion.Attribution({
                conversion: AdvertisementConversion.Conversion({
                    eventId: bytes16(uint128(i + 1)),
                    clickId: string(abi.encodePacked("click_", vm.toString(i))),
                    conversionConfigId: configId,
                    publisherRefCode: refCode,
                    timestamp: uint32(block.timestamp),
                    payoutRecipient: address(0),
                    payoutAmount: PAYOUT_PER_EVENT
                }),
                logBytes: configId == 3
                    ? bytes("")
                    : abi.encode(
                        AdvertisementConversion.Log({
                            chainId: block.chainid,
                            transactionHash: bytes32(uint256(i + 1)),
                            index: uint256(i)
                        })
                    )
            });
        }

        bytes memory hookData = abi.encode(attributions);

        // Record initial balances
        uint256 initialCampaignBalance = token.balanceOf(multiPublisherCampaign);
        uint256[] memory initialPublisherBalances = new uint256[](numPublishers);
        for (uint256 i = 0; i < numPublishers; i++) {
            initialPublisherBalances[i] = token.balanceOf(publishers[i]);
        }

        // Execute batch attribution
        vm.prank(attributionProvider);
        flywheel.reward(multiPublisherCampaign, address(token), hookData);

        // Calculate expected amounts
        uint256 totalPayout = numEvents * PAYOUT_PER_EVENT;
        uint256 expectedFee = (totalPayout * ATTRIBUTION_FEE_BPS) / 10000;
        uint256 expectedNetPayout = totalPayout - expectedFee;
        uint256 expectedPayoutPerPublisher = expectedNetPayout / numPublishers;

        // Verify campaign balance decreased by net payout amount
        assertEq(
            token.balanceOf(multiPublisherCampaign),
            initialCampaignBalance - expectedNetPayout,
            "Campaign balance should decrease by net payout amount"
        );

        // Verify each publisher received their share
        for (uint256 i = 0; i < numPublishers; i++) {
            assertEq(
                token.balanceOf(publishers[i]),
                initialPublisherBalances[i] + expectedPayoutPerPublisher,
                string(abi.encodePacked("Publisher ", vm.toString(i), " should receive correct payout"))
            );
        }

        // Verify attribution provider fee is allocated
        assertEq(
            flywheel.fees(multiPublisherCampaign, address(token), attributionProvider),
            expectedFee,
            "Attribution provider fee should be allocated"
        );
    }

    function test_batchRewards_1000Events_UniqueUsers() public {
        uint256 numEvents = 1000;

        // Create a new campaign that allows all publishers
        AdvertisementConversion.ConversionConfig[] memory configs = new AdvertisementConversion.ConversionConfig[](3);
        configs[0] = AdvertisementConversion.ConversionConfig({
            isActive: true,
            isEventOnchain: true,
            conversionMetadataUrl: ONCHAIN_CONFIG_1_URL
        });
        configs[1] = AdvertisementConversion.ConversionConfig({
            isActive: true,
            isEventOnchain: true,
            conversionMetadataUrl: ONCHAIN_CONFIG_2_URL
        });
        configs[2] = AdvertisementConversion.ConversionConfig({
            isActive: true,
            isEventOnchain: false,
            conversionMetadataUrl: OFFCHAIN_CONFIG_1_URL
        });

        string[] memory allowedRefCodes = new string[](0); // Empty = allow all publishers

        bytes memory newHookData =
            abi.encode(attributionProvider, advertiser, CAMPAIGN_METADATA_URL, allowedRefCodes, configs);

        address userCampaign = flywheel.createCampaign(address(hook), 3, newHookData);

        // Fund the new campaign
        token.transfer(userCampaign, CAMPAIGN_FUNDING);

        // Set campaign to ACTIVE status
        vm.prank(attributionProvider);
        flywheel.updateStatus(userCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Create 1000 attribution events with unique user recipients (recipient type = 2)
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](numEvents);
        address[] memory uniqueUsers = new address[](numEvents);

        for (uint256 i = 0; i < numEvents; i++) {
            uint8 configId = uint8((i % 3) + 1); // Cycle through configs 1, 2, 3
            uniqueUsers[i] = address(uint160(0x2000 + i)); // Create unique user addresses

            attributions[i] = _createAttributionWithRecipient(
                i + 1,
                "click_",
                configId,
                i + 1,
                uniqueUsers[i], // Each event pays a different user
                PUBLISHER_REF_CODE
            );
        }

        bytes memory hookData = abi.encode(attributions);

        // Record initial balances
        uint256 initialCampaignBalance = token.balanceOf(userCampaign);
        uint256[] memory initialUserBalances = new uint256[](numEvents);
        for (uint256 i = 0; i < numEvents; i++) {
            initialUserBalances[i] = token.balanceOf(uniqueUsers[i]);
        }

        // Execute batch attribution
        vm.prank(attributionProvider);
        flywheel.reward(userCampaign, address(token), hookData);

        // Calculate expected amounts
        uint256 totalPayout = numEvents * PAYOUT_PER_EVENT;
        uint256 expectedFee = (totalPayout * ATTRIBUTION_FEE_BPS) / 10000;
        uint256 expectedNetPayout = totalPayout - expectedFee;
        uint256 expectedPayoutPerUser = (PAYOUT_PER_EVENT * (10000 - ATTRIBUTION_FEE_BPS)) / 10000;

        // Verify campaign balance decreased by net payout amount
        assertEq(
            token.balanceOf(userCampaign),
            initialCampaignBalance - expectedNetPayout,
            "Campaign balance should decrease by net payout amount"
        );

        // Verify each user received their individual payout (sampling first 10 for efficiency)
        for (uint256 i = 0; i < 10; i++) {
            assertEq(
                token.balanceOf(uniqueUsers[i]),
                initialUserBalances[i] + expectedPayoutPerUser,
                string(abi.encodePacked("User ", vm.toString(i), " should receive correct payout"))
            );
        }

        // Verify attribution provider fee is allocated
        assertEq(
            flywheel.fees(userCampaign, address(token), attributionProvider),
            expectedFee,
            "Attribution provider fee should be allocated"
        );
    }
}

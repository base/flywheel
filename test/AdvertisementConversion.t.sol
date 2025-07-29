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

contract AdvertisementConversionTest is Test {
    Flywheel public flywheel;
    FlywheelPublisherRegistry public publisherRegistry;
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

        // Deploy FlywheelPublisherRegistry as upgradeable proxy
        FlywheelPublisherRegistry implementation = new FlywheelPublisherRegistry();
        bytes memory initData = abi.encodeWithSelector(
            FlywheelPublisherRegistry.initialize.selector,
            owner,
            address(0x999) // signer address
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        publisherRegistry = FlywheelPublisherRegistry(address(proxy));

        hook = new AdvertisementConversion(address(flywheel), owner, address(publisherRegistry));

        // Deploy token with initial holders
        address[] memory initialHolders = new address[](1);
        initialHolders[0] = address(this);
        token = new DummyERC20(initialHolders);

        // Create a campaign with conversion configs
        ConversionConfig[] memory configs = new ConversionConfig[](2);
        configs[0] = ConversionConfig({
            status: ConversionConfigStatus.ACTIVE,
            eventType: EventType.ONCHAIN,
            conversionMetadataUrl: "https://example.com/config0"
        });
        configs[1] = ConversionConfig({
            status: ConversionConfigStatus.ACTIVE,
            eventType: EventType.OFFCHAIN,
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
        ConversionConfig memory config = hook.getConversionConfig(campaign, 1);
        assertEq(config.conversionMetadataUrl, "https://example.com/config0");
    }

    function test_updateConversionConfigMetadata_asAttributionProvider() public {
        // Update as attribution provider
        vm.prank(attributionProvider);
        hook.updateConversionConfigMetadata(campaign, 2);

        // Verify the metadata URL hasn't changed
        ConversionConfig memory config = hook.getConversionConfig(campaign, 2);
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
            payout: Flywheel.Payout({recipient: randomUser, amount: 100 ether, extraData: ""}),
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 1, // ONCHAIN config (1-indexed)
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                recipientType: 0,
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
            payout: Flywheel.Payout({recipient: randomUser, amount: 100 ether, extraData: ""}),
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 2, // OFFCHAIN config (1-indexed)
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                recipientType: 0,
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
            payout: Flywheel.Payout({recipient: randomUser, amount: 100 ether, extraData: ""}),
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 1, // ONCHAIN config (1-indexed)
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                recipientType: 0,
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
            payout: Flywheel.Payout({recipient: randomUser, amount: 100 ether, extraData: ""}),
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 2, // OFFCHAIN config (1-indexed)
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                recipientType: 0,
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

    function test_onReward_revert_invalidConfigId_zero() public {
        // Create attribution with config ID 0 (invalid in 1-indexed system)
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            payout: Flywheel.Payout({recipient: randomUser, amount: 100 ether, extraData: ""}),
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 0, // Invalid - IDs start at 1
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                recipientType: 0,
                payoutAmount: 100 ether
            }),
            logBytes: ""
        });

        bytes memory hookData = abi.encode(attributions);

        // Expect revert
        vm.expectRevert(AdvertisementConversion.InvalidConversionConfigId.selector);
        vm.prank(address(flywheel));
        hook.onReward(attributionProvider, campaign, address(token), hookData);
    }
}

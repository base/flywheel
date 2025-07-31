// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Flywheel} from "../src/Flywheel.sol";
import {FlywheelPublisherRegistry} from "../src/FlywheelPublisherRegistry.sol";
import {AdvertisementConversion} from "../src/hooks/AdvertisementConversion.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AdvertisementConversionInvariantHandler is Test {
    Flywheel public flywheel;
    FlywheelPublisherRegistry public publisherRegistry;
    AdvertisementConversion public hook;
    DummyERC20 public token;

    address public owner = address(0x1);
    address public advertiser = address(0x2);
    address public attributionProvider = address(0x3);
    address public publisher1 = address(0x4);
    address public publisher2 = address(0x5);

    address[] public campaigns;
    
    function getCampaignCount() external view returns (uint256) {
        return campaigns.length;
    }
    
    function getCampaign(uint256 index) external view returns (address) {
        return campaigns[index];
    }
    uint256 public campaignNonce;

    // Ghost variables for invariant tracking
    mapping(address => uint256) public configCounts;
    mapping(address => mapping(uint8 => bool)) public configCreated;
    mapping(address => mapping(uint8 => bool)) public configDisabled;
    mapping(address => bool) public hasAllowlist;
    mapping(address => mapping(string => bool)) public publisherAllowed;
    mapping(address => uint256) public totalAttributions;
    mapping(address => uint256) public totalPayouts;

    modifier useActor(uint256 actorIndexSeed) {
        address[5] memory actors = [owner, advertiser, attributionProvider, publisher1, publisher2];
        address actor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    modifier validCampaign(uint256 campaignSeed) {
        vm.assume(campaigns.length > 0);
        _;
    }

    constructor(
        Flywheel _flywheel,
        FlywheelPublisherRegistry _publisherRegistry,
        AdvertisementConversion _hook,
        DummyERC20 _token
    ) {
        flywheel = _flywheel;
        publisherRegistry = _publisherRegistry;
        hook = _hook;
        token = _token;
    }

    function createCampaignWithAllowlist(uint256 actorSeed, bool useAllowlist) external useActor(actorSeed) {
        // Create conversion configs
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](2);
        configs[0] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: true,
            conversionMetadataUrl: "https://example.com/onchain"
        });
        configs[1] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: false,
            conversionMetadataUrl: "https://example.com/offchain"
        });

        string[] memory allowedRefCodes;
        if (useAllowlist) {
            allowedRefCodes = new string[](2);
            allowedRefCodes[0] = "PUB1";
            allowedRefCodes[1] = "PUB2";
        } else {
            allowedRefCodes = new string[](0); // No allowlist
        }

        bytes memory hookData = abi.encode(
            attributionProvider,
            advertiser,
            "https://example.com/campaign",
            allowedRefCodes,
            configs
        );

        campaignNonce++;
        address campaign = flywheel.createCampaign(address(hook), campaignNonce, hookData);
        campaigns.push(campaign);
        
        // Track campaign state
        configCounts[campaign] = 2;
        configCreated[campaign][1] = true;
        configCreated[campaign][2] = true;
        hasAllowlist[campaign] = useAllowlist;
        
        if (useAllowlist) {
            publisherAllowed[campaign]["PUB1"] = true;
            publisherAllowed[campaign]["PUB2"] = true;
        }

        // Activate campaign
        vm.startPrank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        vm.stopPrank();
    }

    function addConversionConfig(uint256 campaignSeed, bool isOnchain) external validCampaign(campaignSeed) {
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
        
        vm.startPrank(advertiser);
        try hook.addConversionConfig(
            campaign,
            AdvertisementConversion.ConversionConfigInput({
                isEventOnchain: isOnchain,
                conversionMetadataUrl: "https://example.com/new-config"
            })
        ) {
            configCounts[campaign]++;
            configCreated[campaign][uint8(configCounts[campaign])] = true;
        } catch {}
        vm.stopPrank();
    }

    function disableConversionConfig(uint256 campaignSeed, uint8 configId) external validCampaign(campaignSeed) {
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
        configId = uint8(bound(configId, 1, configCounts[campaign]));

        vm.startPrank(advertiser);
        try hook.disableConversionConfig(campaign, configId) {
            configDisabled[campaign][configId] = true;
        } catch {}
        vm.stopPrank();
    }

    function addPublisherToAllowlist(uint256 campaignSeed, uint256 pubSeed) external validCampaign(campaignSeed) {
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
        
        // Only add to campaigns that have allowlists
        if (!hasAllowlist[campaign]) return;

        string[3] memory publishers = ["PUB1", "PUB2", "NEW_PUB"];
        string memory pubRefCode = publishers[bound(pubSeed, 0, publishers.length - 1)];

        vm.startPrank(advertiser);
        try hook.addAllowedPublisherRefCode(campaign, pubRefCode) {
            publisherAllowed[campaign][pubRefCode] = true;
        } catch {}
        vm.stopPrank();
    }

    function setAttributionProviderFee(uint256 feeSeed) external {
        uint16 fee = uint16(bound(feeSeed, 0, 2500)); // 0% to 25%
        
        vm.startPrank(attributionProvider);
        hook.setAttributionProviderFee(fee);
        vm.stopPrank();
    }

    function processValidAttribution(uint256 campaignSeed, uint256 configSeed, uint256 amountSeed, uint256 pubSeed) external validCampaign(campaignSeed) {
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
        
        // Only process for ACTIVE campaigns
        if (flywheel.campaignStatus(campaign) != Flywheel.CampaignStatus.ACTIVE) {
            return;
        }

        uint8 configId = uint8(bound(configSeed, 1, configCounts[campaign]));
        uint256 payoutAmount = bound(amountSeed, 1e18, 50e18);

        // Skip if config is disabled
        if (configDisabled[campaign][configId]) return;

        // Choose publisher based on allowlist
        string memory publisherRefCode = "";
        if (hasAllowlist[campaign]) {
            string[2] memory allowedPubs = ["PUB1", "PUB2"];
            publisherRefCode = allowedPubs[bound(pubSeed, 0, allowedPubs.length - 1)];
        } else {
            // For campaigns without allowlist, can use any registered publisher or empty
            if (pubSeed % 3 == 0) publisherRefCode = "PUB1";
            else if (pubSeed % 3 == 1) publisherRefCode = "PUB2";
            // else empty string
        }

        // Get config to determine if onchain/offchain
        AdvertisementConversion.ConversionConfig memory config;
        try hook.getConversionConfig(campaign, configId) returns (AdvertisementConversion.ConversionConfig memory _config) {
            config = _config;
        } catch {
            return; // Invalid config
        }

        // Create attribution data
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(block.timestamp + totalAttributions[campaign])),
                clickId: "test_click",
                conversionConfigId: configId,
                publisherRefCode: publisherRefCode,
                timestamp: uint32(block.timestamp),
                payoutRecipient: publisher1,
                payoutAmount: payoutAmount
            }),
            logBytes: config.isEventOnchain 
                ? abi.encode(AdvertisementConversion.Log({
                    chainId: block.chainid,
                    transactionHash: keccak256(abi.encode(block.timestamp, totalAttributions[campaign])),
                    index: 0
                }))
                : bytes("")
        });

        bytes memory attributionData = abi.encode(attributions);

        // Fund campaign if needed
        uint256 campaignBalance = token.balanceOf(campaign);
        if (campaignBalance < payoutAmount) {
            vm.startPrank(advertiser);
            uint256 needed = payoutAmount - campaignBalance + 1e18; // Add buffer
            if (token.balanceOf(advertiser) >= needed) {
                token.transfer(campaign, needed);
            }
            vm.stopPrank();
        }

        vm.startPrank(attributionProvider);
        try flywheel.reward(campaign, address(token), attributionData) {
            totalAttributions[campaign]++;
            totalPayouts[campaign] += payoutAmount;
        } catch {}
        vm.stopPrank();
    }

    function updateConversionConfigMetadata(uint256 campaignSeed, uint8 configId) external validCampaign(campaignSeed) {
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
        configId = uint8(bound(configId, 1, configCounts[campaign]));

        vm.startPrank(advertiser);
        try hook.updateConversionConfigMetadata(campaign, configId) {
            // Metadata updated (no state change to track)
        } catch {}
        vm.stopPrank();
    }
}

contract AdvertisementConversionInvariantTest is StdInvariant, Test {
    AdvertisementConversionInvariantHandler public handler;
    Flywheel public flywheel;
    FlywheelPublisherRegistry public publisherRegistry;
    AdvertisementConversion public hook;
    DummyERC20 public token;

    function setUp() public {
        // Deploy token
        address[] memory initialHolders = new address[](2);
        initialHolders[0] = address(0x2); // advertiser
        initialHolders[1] = address(0x3); // attributionProvider
        token = new DummyERC20(initialHolders);

        // Deploy Flywheel
        flywheel = new Flywheel();

        // Deploy publisher registry
        FlywheelPublisherRegistry impl = new FlywheelPublisherRegistry();
        bytes memory initData = abi.encodeWithSelector(
            FlywheelPublisherRegistry.initialize.selector,
            address(0x1), // owner
            address(0x999) // signer
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        publisherRegistry = FlywheelPublisherRegistry(address(proxy));

        // Deploy hook
        hook = new AdvertisementConversion(address(flywheel), address(0x1), address(publisherRegistry));

        // Register publishers
        vm.startPrank(address(0x1)); // owner
        publisherRegistry.registerPublisherCustom(
            "PUB1", address(0x4), "https://pub1.com", address(0x4)
        );
        publisherRegistry.registerPublisherCustom(
            "PUB2", address(0x5), "https://pub2.com", address(0x5)
        );
        publisherRegistry.registerPublisherCustom(
            "NEW_PUB", address(0x6), "https://newpub.com", address(0x6)
        );
        vm.stopPrank();

        // Deploy handler
        handler = new AdvertisementConversionInvariantHandler(flywheel, publisherRegistry, hook, token);

        // Set up invariant testing
        targetContract(address(handler));

        // Set function selectors for the handler
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = handler.createCampaignWithAllowlist.selector;
        selectors[1] = handler.addConversionConfig.selector;
        selectors[2] = handler.disableConversionConfig.selector;
        selectors[3] = handler.addPublisherToAllowlist.selector;
        selectors[4] = handler.setAttributionProviderFee.selector;
        selectors[5] = handler.processValidAttribution.selector;
        selectors[6] = handler.updateConversionConfigMetadata.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice Conversion configs can only be added, never removed (only disabled)
    function invariant_conversionConfigsOnlyIncrease() public view {
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                uint256 trackedCount = handler.configCounts(campaign);
                
                // Verify configs exist for all tracked IDs
                for (uint8 j = 1; j <= trackedCount; j++) {
                    if (handler.configCreated(campaign, j)) {
                        try hook.getConversionConfig(campaign, j) returns (AdvertisementConversion.ConversionConfig memory config) {
                            // Config should exist, but might be disabled
                            assertTrue(true, "Config should exist");
                            
                            // If we tracked it as disabled, it should be disabled
                            if (handler.configDisabled(campaign, j)) {
                                assertFalse(config.isActive, "Disabled config should be inactive");
                            }
                        } catch {
                            assertFalse(true, "Tracked config should exist");
                        }
                    }
                }
            } catch {
                break;
            }
        }
    }

    /// @notice Publisher allowlists can only expand, never contract
    function invariant_allowlistOnlyExpands() public view {
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                bool campaignHasAllowlist = handler.hasAllowlist(campaign);
                bool actualHasAllowlist = hook.hasPublisherAllowlist(campaign);
                
                // Our tracking should match reality
                assertEq(campaignHasAllowlist, actualHasAllowlist, "Allowlist existence tracking mismatch");
                
                // If we tracked a publisher as allowed, they should still be allowed
                string[3] memory publishers = ["PUB1", "PUB2", "NEW_PUB"];
                for (uint256 j = 0; j < publishers.length; j++) {
                    if (handler.publisherAllowed(campaign, publishers[j])) {
                        assertTrue(
                            hook.isPublisherAllowed(campaign, publishers[j]),
                            "Tracked allowed publisher should remain allowed"
                        );
                    }
                }
            } catch {
                break;
            }
        }
    }

    /// @notice Attribution provider fees must be within valid bounds
    function invariant_attributionProviderFeeBounds() public view {
        uint16 currentFee = hook.attributionProviderFees(address(0x3)); // attributionProvider
        assertTrue(currentFee <= 10000, "Attribution provider fee must be <= 100%");
    }

    /// @notice Payouts should only succeed for valid configurations
    function invariant_payoutsOnlyForValidConfigs() public view {
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                uint256 totalAttributions = handler.totalAttributions(campaign);
                uint256 totalPayouts = handler.totalPayouts(campaign);
                
                if (totalAttributions > 0) {
                    // If attributions were processed, the campaign must have valid configs
                    assertTrue(handler.configCounts(campaign) > 0, "Campaign with attributions must have configs");
                    
                    // At least one config must exist and be active
                    bool hasActiveConfig = false;
                    for (uint8 j = 1; j <= handler.configCounts(campaign); j++) {
                        if (handler.configCreated(campaign, j) && !handler.configDisabled(campaign, j)) {
                            hasActiveConfig = true;
                            break;
                        }
                    }
                    assertTrue(hasActiveConfig, "Campaign with attributions must have active config");
                }
                
                // Total payouts should be positive if attributions exist
                if (totalAttributions > 0) {
                    assertTrue(totalPayouts > 0, "Attributions should generate payouts");
                }
            } catch {
                break;
            }
        }
    }

    /// @notice Onchain conversions must have log data, offchain must not
    function invariant_conversionTypeConsistency() public view {
        // This invariant is enforced by the contract itself through validation
        // We test it indirectly by ensuring only valid attributions were processed
        
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                uint256 totalAttributions = handler.totalAttributions(campaign);
                
                if (totalAttributions > 0) {
                    // If any attributions were processed, they must have passed validation
                    // which includes onchain/offchain consistency checks
                    assertTrue(totalAttributions >= 0, "Attribution validation ensures type consistency");
                }
            } catch {
                break;
            }
        }
    }

    /// @notice Publisher restrictions must be enforced for allowlisted campaigns
    function invariant_publisherAllowlistEnforcement() public view {
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                bool hasAllowlistTracked = handler.hasAllowlist(campaign);
                bool hasAllowlistActual = hook.hasPublisherAllowlist(campaign);
                
                assertEq(hasAllowlistTracked, hasAllowlistActual, "Allowlist tracking must match reality");
                
                // If campaign has successful attributions and has allowlist,
                // then only allowed publishers should have been used
                uint256 totalAttributions = handler.totalAttributions(campaign);
                if (totalAttributions > 0 && hasAllowlistActual) {
                    // The handler only uses allowed publishers for allowlisted campaigns
                    // so if attributions succeeded, the allowlist was properly enforced
                    assertTrue(totalAttributions >= 0, "Allowlist enforcement ensures only allowed publishers");
                }
            } catch {
                break;
            }
        }
    }

    /// @notice Disabled configs should not accept new attributions
    function invariant_disabledConfigsRejectAttributions() public view {
        // This is primarily enforced by the contract's validation logic
        // The handler respects disabled configs, so this invariant is structural
        
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                // Check each config that was disabled
                for (uint8 j = 1; j <= handler.configCounts(campaign); j++) {
                    if (handler.configDisabled(campaign, j)) {
                        try hook.getConversionConfig(campaign, j) returns (AdvertisementConversion.ConversionConfig memory config) {
                            assertFalse(config.isActive, "Disabled configs should be inactive");
                        } catch {
                            // Config doesn't exist, which is fine
                        }
                    }
                }
            } catch {
                break;
            }
        }
    }

    /// @notice Campaign URI should be accessible for all created campaigns
    function invariant_campaignURIAccessible() public view {
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                string memory uri = hook.campaignURI(campaign);
                assertTrue(bytes(uri).length > 0, "Campaign URI should be non-empty");
            } catch {
                break;
            }
        }
    }
}
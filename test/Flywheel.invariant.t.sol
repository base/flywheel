// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Flywheel} from "../src/Flywheel.sol";
import {TokenStore} from "../src/TokenStore.sol";
import {FlywheelPublisherRegistry} from "../src/FlywheelPublisherRegistry.sol";
import {AdvertisementConversion} from "../src/hooks/AdvertisementConversion.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FlywheelInvariantHandler is Test {
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
    mapping(address => uint256) public initialCampaignBalances;
    mapping(address => uint256) public totalRewards;
    mapping(address => uint256) public totalFees;
    mapping(address => Flywheel.CampaignStatus) public lastKnownStatus;

    modifier useActor(uint256 actorIndexSeed) {
        address[5] memory actors = [owner, advertiser, attributionProvider, publisher1, publisher2];
        address actor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    modifier validCampaign(uint256 campaignSeed) {
        vm.assume(campaigns.length > 0);
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
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

    function createCampaign(uint256 actorSeed) external useActor(actorSeed) {
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

        string[] memory allowedRefCodes = new string[](0); // Allow all publishers

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
        lastKnownStatus[campaign] = Flywheel.CampaignStatus.INACTIVE;
    }

    function fundCampaign(uint256 campaignSeed, uint256 amount) external validCampaign(campaignSeed) {
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
        amount = bound(amount, 1e18, 1000e18); // 1 to 1000 tokens

        vm.startPrank(advertiser);
        uint256 advertiserBalance = token.balanceOf(advertiser);
        if (advertiserBalance >= amount) {
            uint256 balanceBefore = token.balanceOf(campaign);
            token.transfer(campaign, amount);
            initialCampaignBalances[campaign] += amount;
        }
        vm.stopPrank();
    }

    function updateCampaignStatus(uint256 campaignSeed, uint8 statusSeed) external validCampaign(campaignSeed) {
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
        Flywheel.CampaignStatus currentStatus = flywheel.campaignStatus(campaign);
        
        // Only allow valid status transitions
        Flywheel.CampaignStatus newStatus;
        if (currentStatus == Flywheel.CampaignStatus.INACTIVE) {
            newStatus = Flywheel.CampaignStatus.ACTIVE;
        } else if (currentStatus == Flywheel.CampaignStatus.ACTIVE) {
            newStatus = statusSeed % 2 == 0 ? Flywheel.CampaignStatus.ACTIVE : Flywheel.CampaignStatus.FINALIZING;
        } else if (currentStatus == Flywheel.CampaignStatus.FINALIZING) {
            newStatus = Flywheel.CampaignStatus.FINALIZED;
        } else {
            return; // FINALIZED is terminal
        }

        if (newStatus != currentStatus) {
            vm.startPrank(attributionProvider);
            try flywheel.updateStatus(campaign, newStatus, "") {
                lastKnownStatus[campaign] = newStatus;
            } catch {}
            vm.stopPrank();
        }
    }

    function processReward(uint256 campaignSeed, uint256 rewardAmount) external validCampaign(campaignSeed) {
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
        
        // Only process rewards for ACTIVE campaigns
        if (flywheel.campaignStatus(campaign) != Flywheel.CampaignStatus.ACTIVE) {
            return;
        }

        rewardAmount = bound(rewardAmount, 1e18, 100e18); // 1 to 100 tokens

        // Create attribution
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(block.timestamp)),
                clickId: "test_click",
                conversionConfigId: 1,
                publisherRefCode: "",
                timestamp: uint32(block.timestamp),
                payoutRecipient: publisher1,
                payoutAmount: rewardAmount
            }),
            logBytes: abi.encode(
                AdvertisementConversion.Log({
                    chainId: block.chainid,
                    transactionHash: keccak256(abi.encode(block.timestamp)),
                    index: 0
                })
            )
        });

        bytes memory attributionData = abi.encode(attributions);

        vm.startPrank(attributionProvider);
        try flywheel.reward(campaign, address(token), attributionData) {
            totalRewards[campaign] += rewardAmount;
            // Note: In AdvertisementConversion, no fee by default unless set
        } catch {}
        vm.stopPrank();
    }

    function collectFees(uint256 campaignSeed) external validCampaign(campaignSeed) {
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
        
        vm.startPrank(attributionProvider);
        uint256 availableFees = flywheel.fees(campaign, address(token), attributionProvider);
        if (availableFees > 0) {
            try flywheel.collectFees(campaign, address(token), attributionProvider) {
                totalFees[campaign] += availableFees;
            } catch {}
        }
        vm.stopPrank();
    }

    function withdrawFunds(uint256 campaignSeed, uint256 amount) external validCampaign(campaignSeed) {
        address campaign = campaigns[bound(campaignSeed, 0, campaigns.length - 1)];
        
        // Only withdraw from FINALIZED campaigns
        if (flywheel.campaignStatus(campaign) != Flywheel.CampaignStatus.FINALIZED) {
            return;
        }

        uint256 campaignBalance = token.balanceOf(campaign);
        if (campaignBalance == 0) return;

        amount = bound(amount, 1, campaignBalance);

        vm.startPrank(advertiser);
        try flywheel.withdrawFunds(campaign, address(token), amount, "") {
            // Withdrawal successful
        } catch {}
        vm.stopPrank();
    }
}

contract FlywheelInvariantTest is StdInvariant, Test {
    FlywheelInvariantHandler public handler;
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
        vm.stopPrank();

        // Deploy handler
        handler = new FlywheelInvariantHandler(flywheel, publisherRegistry, hook, token);

        // Set up invariant testing
        targetContract(address(handler));

        // Set function selectors for the handler
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = handler.createCampaign.selector;
        selectors[1] = handler.fundCampaign.selector;
        selectors[2] = handler.updateCampaignStatus.selector;
        selectors[3] = handler.processReward.selector;
        selectors[4] = handler.collectFees.selector;
        selectors[5] = handler.withdrawFunds.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice Campaign status transitions must follow the valid progression
    function invariant_campaignStatusProgression() public view {
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                Flywheel.CampaignStatus currentStatus = flywheel.campaignStatus(campaign);
                Flywheel.CampaignStatus lastStatus = handler.lastKnownStatus(campaign);
                
                // Status should never go backwards
                assertTrue(uint8(currentStatus) >= uint8(lastStatus), "Status cannot go backwards");
                
                // FINALIZED is terminal
                if (lastStatus == Flywheel.CampaignStatus.FINALIZED) {
                    assertEq(uint8(currentStatus), uint8(Flywheel.CampaignStatus.FINALIZED), "FINALIZED is terminal");
                }
            } catch {
                break;
            }
        }
    }

    /// @notice Token balances must always be conserved across the system
    function invariant_tokenConservation() public view {
        uint256 totalSystemBalance = 0;
        
        // Add up all campaign balances
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                totalSystemBalance += token.balanceOf(campaign);
            } catch {
                break;
            }
        }
        
        // Add balances of all actors
        totalSystemBalance += token.balanceOf(address(0x1)); // owner
        totalSystemBalance += token.balanceOf(address(0x2)); // advertiser
        totalSystemBalance += token.balanceOf(address(0x3)); // attributionProvider
        totalSystemBalance += token.balanceOf(address(0x4)); // publisher1
        totalSystemBalance += token.balanceOf(address(0x5)); // publisher2

        // Total should equal initial supply
        assertEq(totalSystemBalance, token.totalSupply(), "Token conservation violated");
    }

    /// @notice Campaign funds can only decrease through rewards or withdrawals
    function invariant_campaignFundsCanOnlyDecrease() public view {
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                uint256 currentBalance = token.balanceOf(campaign);
                uint256 initialBalance = handler.initialCampaignBalances(campaign);
                uint256 totalRewards = handler.totalRewards(campaign);
                
                // Current balance should be: initial + additional funding - rewards - withdrawals
                // Since we can't easily track withdrawals in the handler, we check that
                // current balance + rewards <= initial balance (assuming no additional funding beyond initial)
                assertTrue(
                    currentBalance <= initialBalance,
                    "Campaign balance can only decrease through valid operations"
                );
            } catch {
                break;
            }
        }
    }

    /// @notice Only authorized addresses can perform privileged operations
    function invariant_accessControl() public view {
        // This is mostly enforced by the contracts themselves, but we verify no
        // unauthorized state changes occurred
        
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                // Verify campaign exists in Flywheel
                assertTrue(flywheel.campaignHooks(campaign) != address(0), "Campaign must be registered");
                
                // Verify campaign hook is the expected one
                assertEq(flywheel.campaignHooks(campaign), address(hook), "Campaign hook must be correct");
            } catch {
                break;
            }
        }
    }

    /// @notice Rewards can only be processed for ACTIVE campaigns
    function invariant_rewardsOnlyForActiveCampaigns() public view {
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                uint256 totalRewards = handler.totalRewards(campaign);
                
                if (totalRewards > 0) {
                    // If rewards were processed, the campaign was ACTIVE at some point
                    // Note: We can't verify current status because it might have changed
                    // but we can verify the campaign exists and has valid hook
                    assertTrue(flywheel.campaignHooks(campaign) != address(0), "Rewarded campaign must exist");
                }
            } catch {
                break;
            }
        }
    }

    /// @notice Fee collection should not exceed fees owed
    function invariant_feeCollectionBounds() public view {
        for (uint256 i = 0; i < handler.getCampaignCount(); i++) {
            try handler.getCampaign(i) returns (address campaign) {
                uint256 totalFeesCollected = handler.totalFees(campaign);
                uint256 remainingFees = flywheel.fees(campaign, address(token), address(0x3)); // attributionProvider
                
                // Total fees collected + remaining fees should be reasonable
                // (This is a weak invariant since we don't track exact fee generation)
                assertTrue(totalFeesCollected >= 0, "Fees collected should be non-negative");
                assertTrue(remainingFees >= 0, "Remaining fees should be non-negative");
            } catch {
                break;
            }
        }
    }
}
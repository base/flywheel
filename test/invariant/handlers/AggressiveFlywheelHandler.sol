// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {StdUtils} from "forge-std/StdUtils.sol";
import {Vm} from "forge-std/Vm.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";
import {MockERC20} from "../../lib/mocks/MockERC20.sol";
import {Constants} from "../../../src/Constants.sol";

/// @title AggressiveFlywheelHandler
/// @notice AGGRESSIVE handler that tries to break invariants
/// @dev This handler allows "bad" calls to test protocol robustness
contract AggressiveFlywheelHandler is StdUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    Flywheel public immutable flywheel;
    SimpleRewards public immutable simpleRewards;
    MockERC20 public immutable token;

    // State tracking
    address[] public campaigns;
    mapping(address campaign => mapping(address token => bytes32[])) public payoutKeys;
    mapping(address campaign => Flywheel.CampaignStatus) public previousStatus;

    // Test constants
    address public constant OWNER = address(0x1);
    address public constant MANAGER = address(0x2);
    string public constant CAMPAIGN_URI = "https://example.com/campaign";

    address[] public actors;
    uint256 public constant MAX_AMOUNT = 1e24;
    uint256 public constant MAX_CAMPAIGNS = 10;
    uint256 public nextNonce = 1;

    // Metrics to track what we're actually testing
    uint256 public successfulAllocations = 0;
    uint256 public failedAllocations = 0;
    uint256 public solvencyViolationAttempts = 0;
    uint256 public invalidStatusAttempts = 0;

    constructor(Flywheel _flywheel, SimpleRewards _simpleRewards, MockERC20 _token) {
        flywheel = _flywheel;
        simpleRewards = _simpleRewards;
        token = _token;

        // Initialize actors
        for (uint256 i = 0; i < 5; i++) {
            address actor = address(uint160(0x1000 + i));
            actors.push(actor);
        }
    }

    /// @notice Creates campaigns - this can succeed or fail naturally
    function createCampaign(uint256 fundingAmount, uint256 shouldFund) public {
        fundingAmount = bound(fundingAmount, 0, MAX_AMOUNT); // Allow zero funding!
        shouldFund = bound(shouldFund, 0, 100);

        if (campaigns.length >= MAX_CAMPAIGNS) return;

        bytes memory hookData = abi.encode(OWNER, MANAGER, CAMPAIGN_URI);
        address campaign = flywheel.createCampaign(address(simpleRewards), nextNonce, hookData);

        // Track campaign
        bool isNewCampaign = true;
        for (uint256 i = 0; i < campaigns.length; i++) {
            if (campaigns[i] == campaign) {
                isNewCampaign = false;
                break;
            }
        }

        if (isNewCampaign) {
            campaigns.push(campaign);
            previousStatus[campaign] = flywheel.campaignStatus(campaign);
        }

        // Sometimes don't fund the campaign at all!
        if (shouldFund > 20) { // 80% chance of funding
            token.mint(campaign, fundingAmount);
            vm.deal(campaign, fundingAmount);
        }

        nextNonce++;
    }

    /// @notice AGGRESSIVE allocation - tries to break solvency!
    function allocatePayouts(
        uint256 campaignIndex,
        uint256 recipientSeed,
        uint256 amount,
        bool useNativeToken,
        uint256 aggressiveness
    ) public {
        if (campaigns.length == 0) return;

        campaignIndex = bound(campaignIndex, 0, campaigns.length - 1);
        amount = bound(amount, 1, MAX_AMOUNT); // Full range!
        aggressiveness = bound(aggressiveness, 0, 100);

        address campaign = campaigns[campaignIndex];
        address recipient = actors[recipientSeed % actors.length];
        address tokenAddr = useNativeToken ? Constants.NATIVE_TOKEN : address(token);

        // Get current state
        Flywheel.CampaignStatus status = flywheel.campaignStatus(campaign);
        uint256 currentBalance = useNativeToken ? campaign.balance : token.balanceOf(campaign);
        uint256 currentAllocated = flywheel.totalAllocatedPayouts(campaign, tokenAddr)
            + flywheel.totalAllocatedFees(campaign, tokenAddr);

        // Check if this would violate solvency
        bool wouldViolateSolvency = currentBalance < currentAllocated + amount;

        // Check if status allows allocations
        bool invalidStatus = (status == Flywheel.CampaignStatus.INACTIVE ||
                             status == Flywheel.CampaignStatus.FINALIZED);

        // Track what we're attempting
        if (wouldViolateSolvency) solvencyViolationAttempts++;
        if (invalidStatus) invalidStatusAttempts++;

        // AGGRESSIVE MODE: Sometimes try the call even if we expect it to fail!
        bool shouldAttempt = true;

        if (aggressiveness < 70) { // 70% conservative
            if (invalidStatus || wouldViolateSolvency) {
                shouldAttempt = false;
            }
        }
        // 30% of the time, we try even "bad" calls to see what happens!

        if (!shouldAttempt) return;

        // Create allocation and attempt it
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: recipient, amount: amount, extraData: ""});
        bytes memory hookData = abi.encode(payouts);

        vm.prank(MANAGER);
        try flywheel.allocate(campaign, tokenAddr, hookData) {
            // Success! Track it
            bytes32 key = bytes32(bytes20(recipient));
            _addPayoutKey(campaign, tokenAddr, key);
            successfulAllocations++;
        } catch {
            // Failed! This is actually valuable - we're testing protocol robustness
            failedAllocations++;
        }
    }

    /// @notice AGGRESSIVE distribution - tries to distribute more than allocated
    function distributePayouts(
        uint256 campaignIndex,
        uint256 recipientSeed,
        uint256 amount,
        bool useNativeToken,
        uint256 aggressiveness
    ) public {
        if (campaigns.length == 0) return;

        campaignIndex = bound(campaignIndex, 0, campaigns.length - 1);
        amount = bound(amount, 1, MAX_AMOUNT);
        aggressiveness = bound(aggressiveness, 0, 100);

        address campaign = campaigns[campaignIndex];
        address recipient = actors[recipientSeed % actors.length];
        address tokenAddr = useNativeToken ? Constants.NATIVE_TOKEN : address(token);

        bytes32 key = bytes32(bytes20(recipient));
        uint256 allocated = flywheel.allocatedPayout(campaign, tokenAddr, key);

        // AGGRESSIVE: Sometimes try to distribute more than allocated!
        if (aggressiveness > 80 && allocated > 0) {
            uint256 maxAttempt = allocated * 2;
            if (maxAttempt > allocated) {
                amount = bound(amount, allocated, maxAttempt); // Up to 2x over-distribution!
            } else {
                amount = allocated; // Fallback
            }
        } else if (allocated > 0) {
            amount = bound(amount, 1, allocated); // Normal case
        } else {
            return; // Nothing allocated
        }

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: recipient, amount: amount, extraData: ""});
        bytes memory hookData = abi.encode(payouts);

        vm.prank(MANAGER);
        try flywheel.distribute(campaign, tokenAddr, hookData) {
            // Success
        } catch {
            // Expected for over-distribution attempts
        }
    }

    /// @notice AGGRESSIVE withdrawal - tries to withdraw more than available
    function withdrawFunds(
        uint256 campaignIndex,
        uint256 amount,
        bool useNativeToken,
        uint256 aggressiveness
    ) public {
        if (campaigns.length == 0) return;

        campaignIndex = bound(campaignIndex, 0, campaigns.length - 1);
        amount = bound(amount, 1, MAX_AMOUNT);
        aggressiveness = bound(aggressiveness, 0, 100);

        address campaign = campaigns[campaignIndex];
        address tokenAddr = useNativeToken ? Constants.NATIVE_TOKEN : address(token);

        uint256 totalBalance = useNativeToken ? campaign.balance : token.balanceOf(campaign);
        Flywheel.CampaignStatus status = flywheel.campaignStatus(campaign);

        // Required solvency depends on campaign status (matches core protocol logic):
        // - FINALIZED: Only need to cover allocated fees (payouts can be withdrawn by owner)
        // - Other statuses: Must cover both allocated payouts + allocated fees
        uint256 requiredSolvency = status == Flywheel.CampaignStatus.FINALIZED
            ? flywheel.totalAllocatedFees(campaign, tokenAddr)
            : flywheel.totalAllocatedPayouts(campaign, tokenAddr) + flywheel.totalAllocatedFees(campaign, tokenAddr);

        // AGGRESSIVE: Sometimes try to withdraw allocated funds!
        if (aggressiveness > 85 && totalBalance > 0) {
            amount = bound(amount, 1, totalBalance); // Try to withdraw everything!
        } else {
            uint256 available = totalBalance > requiredSolvency ? totalBalance - requiredSolvency : 0;
            if (available == 0) return;
            amount = bound(amount, 1, available);
        }

        Flywheel.Payout memory payout = Flywheel.Payout({recipient: OWNER, amount: amount, extraData: ""});
        bytes memory hookData = abi.encode(payout);

        vm.prank(OWNER);
        try flywheel.withdrawFunds(campaign, tokenAddr, hookData) {
            // Success
        } catch {
            // Expected for aggressive attempts
        }
    }

    /// @notice Adds funding to campaigns
    function addFunding(uint256 campaignIndex, uint256 amount, bool useNativeToken) public {
        if (campaigns.length == 0) return;

        campaignIndex = bound(campaignIndex, 0, campaigns.length - 1);
        amount = bound(amount, 1, MAX_AMOUNT);

        address campaign = campaigns[campaignIndex];

        if (useNativeToken) {
            vm.deal(campaign, campaign.balance + amount);
        } else {
            token.mint(campaign, amount);
        }
    }

    /// @notice Status updates - allows any transition attempts
    function updateStatus(uint256 campaignIndex, uint256 newStatusSeed) public {
        if (campaigns.length == 0) return;

        campaignIndex = bound(campaignIndex, 0, campaigns.length - 1);
        address campaign = campaigns[campaignIndex];

        // Try ANY status transition (some will fail)
        Flywheel.CampaignStatus newStatus = Flywheel.CampaignStatus(newStatusSeed % 4);
        Flywheel.CampaignStatus currentStatus = flywheel.campaignStatus(campaign);

        if (newStatus == currentStatus) return;

        vm.prank(MANAGER);
        try flywheel.updateStatus(campaign, newStatus, "") {
            previousStatus[campaign] = currentStatus;
        } catch {
            // Failed transition - this tests the state machine!
        }
    }

    // Helper functions
    function getCampaigns() external view returns (address[] memory) {
        return campaigns;
    }

    function getPayoutKeys(address campaign, address tokenAddr) external view returns (bytes32[] memory) {
        return payoutKeys[campaign][tokenAddr];
    }

    function getFeeKeys(address campaign, address tokenAddr) external view returns (bytes32[] memory) {
        bytes32[] memory empty;
        return empty; // Simplified for aggressive handler
    }

    function getPreviousStatus(address campaign) external view returns (Flywheel.CampaignStatus) {
        return previousStatus[campaign];
    }

    function _addPayoutKey(address campaign, address tokenAddr, bytes32 key) internal {
        bytes32[] storage keys = payoutKeys[campaign][tokenAddr];
        for (uint256 i = 0; i < keys.length; i++) {
            if (keys[i] == key) return;
        }
        keys.push(key);
    }
}
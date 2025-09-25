// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {StdUtils} from "forge-std/StdUtils.sol";
import {Vm} from "forge-std/Vm.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";
import {MockERC20} from "../../lib/mocks/MockERC20.sol";
import {Constants} from "../../../src/Constants.sol";

/// @title CampaignSolvencyHandler
/// @notice Handler contract for invariant testing of campaign solvency
/// @dev Provides fuzzing actions that interact with campaigns while maintaining proper state tracking
contract CampaignSolvencyHandler is StdUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    Flywheel public immutable flywheel;
    SimpleRewards public immutable simpleRewards;
    MockERC20 public immutable token;

    // State tracking for invariant validation
    address[] public campaigns;
    mapping(address campaign => mapping(address token => bytes32[])) public payoutKeys;
    mapping(address campaign => mapping(address token => bytes32[])) public feeKeys;
    mapping(address campaign => Flywheel.CampaignStatus) public previousStatus;

    // Constants for testing
    address public constant OWNER = address(0x1);
    address public constant MANAGER = address(0x2);
    string public constant CAMPAIGN_URI = "https://example.com/campaign";

    // Actor addresses for fuzzing
    address[] public actors;
    mapping(address => bool) public isValidActor;

    // Bounds for fuzzing
    uint256 public constant MAX_AMOUNT = 1e24; // 1M tokens with 18 decimals
    uint256 public constant MAX_CAMPAIGNS = 5;
    uint256 public constant MAX_RECIPIENTS = 10;

    // Nonce for campaign creation
    uint256 public nextNonce = 1;

    // Metrics to prove we're doing real work
    uint256 public successfulAllocations = 0;
    uint256 public successfulDistributions = 0;
    uint256 public successfulWithdrawals = 0;

    constructor(Flywheel _flywheel, SimpleRewards _simpleRewards, MockERC20 _token) {
        flywheel = _flywheel;
        simpleRewards = _simpleRewards;
        token = _token;

        // Initialize actors
        for (uint256 i = 0; i < 5; i++) {
            address actor = address(uint160(0x1000 + i));
            actors.push(actor);
            isValidActor[actor] = true;
            vm.label(actor, string(abi.encodePacked("Actor", vm.toString(i))));
        }

        // Label key addresses
        vm.label(OWNER, "Owner");
        vm.label(MANAGER, "Manager");
    }

    /// @notice Creates a new campaign with funding
    /// @param fundingAmount Amount to fund the campaign with
    function createCampaign(uint256 fundingAmount) public {
        fundingAmount = bound(fundingAmount, 1, MAX_AMOUNT);

        if (campaigns.length >= MAX_CAMPAIGNS) return;

        // Create campaign
        bytes memory hookData = abi.encode(OWNER, MANAGER, CAMPAIGN_URI);
        address campaign = flywheel.createCampaign(address(simpleRewards), nextNonce, hookData);

        // Only add to our tracking if it's a new campaign
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

        // Fund the campaign
        token.mint(campaign, fundingAmount);

        // Also send some native tokens for native token testing
        vm.deal(campaign, fundingAmount);

        nextNonce++;
    }

    /// @notice Allocates payouts for a campaign
    /// @param campaignIndex Index of campaign to allocate for
    /// @param recipientSeed Seed for recipient selection
    /// @param amount Amount to allocate
    /// @param useNativeToken Whether to use native token instead of ERC20
    function allocatePayouts(uint256 campaignIndex, uint256 recipientSeed, uint256 amount, bool useNativeToken)
        public
    {
        if (campaigns.length == 0) return;

        campaignIndex = bound(campaignIndex, 0, campaigns.length - 1);
        amount = bound(amount, 1, MAX_AMOUNT / 10); // Smaller amounts for allocations

        address campaign = campaigns[campaignIndex];
        Flywheel.CampaignStatus status = flywheel.campaignStatus(campaign);

        // Only allocate if campaign accepts payouts
        if (status == Flywheel.CampaignStatus.INACTIVE || status == Flywheel.CampaignStatus.FINALIZED) {
            return;
        }

        // Select recipient
        address recipient = actors[recipientSeed % actors.length];
        address tokenAddr = useNativeToken ? Constants.NATIVE_TOKEN : address(token);

        // Check if campaign has enough funds before allocation
        uint256 currentBalance = useNativeToken ? campaign.balance : token.balanceOf(campaign);
        uint256 currentTotalAllocated = flywheel.totalAllocatedPayouts(campaign, tokenAddr)
            + flywheel.totalAllocatedFees(campaign, tokenAddr);

        if (currentBalance < currentTotalAllocated + amount) {
            return; // Skip if would cause insolvency
        }

        // Create allocation
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: recipient, amount: amount, extraData: ""});

        bytes memory hookData = abi.encode(payouts);

        // Execute allocation as manager
        vm.prank(MANAGER);
        try flywheel.allocate(campaign, tokenAddr, hookData) {
            // Track the allocation key
            bytes32 key = bytes32(bytes20(recipient));
            _addPayoutKey(campaign, tokenAddr, key);
            successfulAllocations++; // Proof of real work!
        } catch {
            // Allocation failed, which is fine for invariant testing
        }
    }

    /// @notice Distributes allocated payouts
    /// @param campaignIndex Index of campaign
    /// @param recipientSeed Seed for recipient selection
    /// @param amount Amount to distribute
    /// @param useNativeToken Whether to use native token
    function distributePayouts(uint256 campaignIndex, uint256 recipientSeed, uint256 amount, bool useNativeToken)
        public
    {
        if (campaigns.length == 0) return;

        campaignIndex = bound(campaignIndex, 0, campaigns.length - 1);
        amount = bound(amount, 1, MAX_AMOUNT / 10);

        address campaign = campaigns[campaignIndex];
        Flywheel.CampaignStatus status = flywheel.campaignStatus(campaign);

        // Only distribute if campaign accepts payouts
        if (status == Flywheel.CampaignStatus.INACTIVE || status == Flywheel.CampaignStatus.FINALIZED) {
            return;
        }

        address recipient = actors[recipientSeed % actors.length];
        address tokenAddr = useNativeToken ? Constants.NATIVE_TOKEN : address(token);

        // Check if there are allocated funds to distribute
        bytes32 key = bytes32(bytes20(recipient));
        uint256 allocated = flywheel.allocatedPayout(campaign, tokenAddr, key);
        if (allocated == 0) return;

        // Bound amount to what's actually allocated
        amount = bound(amount, 1, allocated);

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: recipient, amount: amount, extraData: ""});

        bytes memory hookData = abi.encode(payouts);

        vm.prank(MANAGER);
        try flywheel.distribute(campaign, tokenAddr, hookData) {
            // Distribution succeeded
        } catch {
            // Distribution failed, which is fine
        }
    }

    /// @notice Deallocates payouts
    /// @param campaignIndex Index of campaign
    /// @param recipientSeed Seed for recipient selection
    /// @param amount Amount to deallocate
    /// @param useNativeToken Whether to use native token
    function deallocatePayouts(uint256 campaignIndex, uint256 recipientSeed, uint256 amount, bool useNativeToken)
        public
    {
        if (campaigns.length == 0) return;

        campaignIndex = bound(campaignIndex, 0, campaigns.length - 1);
        amount = bound(amount, 1, MAX_AMOUNT / 10);

        address campaign = campaigns[campaignIndex];
        Flywheel.CampaignStatus status = flywheel.campaignStatus(campaign);

        // Only deallocate if campaign accepts payouts
        if (status == Flywheel.CampaignStatus.INACTIVE || status == Flywheel.CampaignStatus.FINALIZED) {
            return;
        }

        address recipient = actors[recipientSeed % actors.length];
        address tokenAddr = useNativeToken ? Constants.NATIVE_TOKEN : address(token);

        // Check if there are allocated funds to deallocate
        bytes32 key = bytes32(bytes20(recipient));
        uint256 allocated = flywheel.allocatedPayout(campaign, tokenAddr, key);
        if (allocated == 0) return;

        // Bound amount to what's actually allocated
        amount = bound(amount, 1, allocated);

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: recipient, amount: amount, extraData: ""});

        bytes memory hookData = abi.encode(payouts);

        vm.prank(MANAGER);
        try flywheel.deallocate(campaign, tokenAddr, hookData) {
            // Deallocation succeeded
        } catch {
            // Deallocation failed, which is fine
        }
    }

    /// @notice Withdraws funds from a campaign
    /// @param campaignIndex Index of campaign
    /// @param amount Amount to withdraw
    /// @param useNativeToken Whether to use native token
    function withdrawFunds(uint256 campaignIndex, uint256 amount, bool useNativeToken) public {
        if (campaigns.length == 0) return;

        campaignIndex = bound(campaignIndex, 0, campaigns.length - 1);
        amount = bound(amount, 1, MAX_AMOUNT / 10);

        address campaign = campaigns[campaignIndex];
        address tokenAddr = useNativeToken ? Constants.NATIVE_TOKEN : address(token);

        // Calculate available funds based on campaign status - matches core protocol logic
        uint256 totalBalance = useNativeToken ? campaign.balance : token.balanceOf(campaign);
        Flywheel.CampaignStatus status = flywheel.campaignStatus(campaign);

        // Required solvency depends on campaign status:
        // - FINALIZED: Only need to cover allocated fees (payouts can be withdrawn by owner)
        // - Other statuses: Must cover both allocated payouts + allocated fees
        uint256 requiredSolvency = status == Flywheel.CampaignStatus.FINALIZED
            ? flywheel.totalAllocatedFees(campaign, tokenAddr)
            : flywheel.totalAllocatedPayouts(campaign, tokenAddr) + flywheel.totalAllocatedFees(campaign, tokenAddr);

        if (totalBalance <= requiredSolvency) return; // No funds available to withdraw

        uint256 availableToWithdraw = totalBalance - requiredSolvency;
        amount = bound(amount, 1, availableToWithdraw);

        Flywheel.Payout memory payout = Flywheel.Payout({recipient: OWNER, amount: amount, extraData: ""});
        bytes memory hookData = abi.encode(payout);

        vm.prank(OWNER);
        try flywheel.withdrawFunds(campaign, tokenAddr, hookData) {
            // Withdrawal succeeded
        } catch {
            // Withdrawal failed, which is fine
        }
    }

    /// @notice Updates campaign status
    /// @param campaignIndex Index of campaign
    /// @param newStatusSeed Seed for new status selection
    function updateStatus(uint256 campaignIndex, uint256 newStatusSeed) public {
        if (campaigns.length == 0) return;

        campaignIndex = bound(campaignIndex, 0, campaigns.length - 1);
        address campaign = campaigns[campaignIndex];

        Flywheel.CampaignStatus currentStatus = flywheel.campaignStatus(campaign);

        // Define possible transitions based on current status
        Flywheel.CampaignStatus newStatus;
        uint256 statusChoice = newStatusSeed % 4;

        if (currentStatus == Flywheel.CampaignStatus.INACTIVE) {
            newStatus = Flywheel.CampaignStatus.ACTIVE;
        } else if (currentStatus == Flywheel.CampaignStatus.ACTIVE) {
            newStatus = statusChoice % 2 == 0 ? Flywheel.CampaignStatus.FINALIZING : Flywheel.CampaignStatus.ACTIVE;
        } else if (currentStatus == Flywheel.CampaignStatus.FINALIZING) {
            newStatus = statusChoice % 2 == 0 ? Flywheel.CampaignStatus.FINALIZED : Flywheel.CampaignStatus.ACTIVE;
        } else {
            return; // FINALIZED - no valid transitions
        }

        if (newStatus == currentStatus) return;

        vm.prank(MANAGER);
        try flywheel.updateStatus(campaign, newStatus, "") {
            previousStatus[campaign] = currentStatus;
        } catch {
            // Status update failed, which is fine
        }
    }

    /// @notice Adds funding to a campaign
    /// @param campaignIndex Index of campaign
    /// @param amount Amount to add
    /// @param useNativeToken Whether to use native token
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

    // Getter functions for invariant testing

    function getCampaigns() external view returns (address[] memory) {
        return campaigns;
    }

    function getPayoutKeys(address campaign, address tokenAddr) external view returns (bytes32[] memory) {
        return payoutKeys[campaign][tokenAddr];
    }

    function getFeeKeys(address campaign, address tokenAddr) external view returns (bytes32[] memory) {
        return feeKeys[campaign][tokenAddr];
    }

    function getPreviousStatus(address campaign) external view returns (Flywheel.CampaignStatus) {
        return previousStatus[campaign];
    }

    // Internal helper functions

    function _addPayoutKey(address campaign, address tokenAddr, bytes32 key) internal {
        bytes32[] storage keys = payoutKeys[campaign][tokenAddr];
        for (uint256 i = 0; i < keys.length; i++) {
            if (keys[i] == key) return; // Key already exists
        }
        keys.push(key);
    }

    function _addFeeKey(address campaign, address tokenAddr, bytes32 key) internal {
        bytes32[] storage keys = feeKeys[campaign][tokenAddr];
        for (uint256 i = 0; i < keys.length; i++) {
            if (keys[i] == key) return; // Key already exists
        }
        keys.push(key);
    }
}
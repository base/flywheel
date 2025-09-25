// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";

import {Flywheel} from "../../src/Flywheel.sol";
import {MockCampaignHooksWithFees} from "./mocks/MockCampaignHooksWithFees.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @title FlywheelTestBase
/// @notice Minimal shared setup for Flywheel unit tests using MockCampaignHooksWithFees as the hook
/// @dev Provides helpers for creating/activating campaigns, funding, and building payout data
abstract contract FlywheelTest is Test {
    // Core contracts
    Flywheel public flywheel;
    MockCampaignHooksWithFees public mockCampaignHooksWithFees;
    MockERC20 public mockToken;

    // Default actors
    address public owner; // Campaign owner (authorized withdrawer in MockCampaignHooksWithFees)
    address public manager; // Campaign manager (authorized to call payout functions in MockCampaignHooksWithFees)

    // Default values
    uint256 public constant INITIAL_TOKEN_BALANCE = 1_000_000e18;

    // Maximum amount for fuzzing to stay within MockERC20 balance limits
    // Set to half of initial balance to allow for multiple operations and overhead
    uint256 public constant MAX_FUZZ_AMOUNT = INITIAL_TOKEN_BALANCE / 2;

    /// @notice Sets up Flywheel + MockCampaignHooksWithFees and a default ERC20 for tests
    /// @dev Intended to be called in each test's setUp
    function setUpFlywheelBase() public virtual {
        flywheel = new Flywheel();
        mockCampaignHooksWithFees = new MockCampaignHooksWithFees(address(flywheel));

        // Default actors
        owner = address(0xA11CE);
        manager = address(0xB0B);

        // Deploy mock token with initial holders funded
        address[] memory initialHolders = new address[](3);
        initialHolders[0] = owner;
        initialHolders[1] = manager;
        initialHolders[2] = address(this);
        mockToken = new MockERC20(initialHolders);

        // Ensure balances are present for convenient funding
        // MockERC20 mints to provided holders in its constructor
    }

    /// @notice Creates a MockCampaignHooksWithFees campaign via Flywheel
    /// @param owner_ Campaign owner
    /// @param manager_ Campaign manager (authorized to call payout functions)
    /// @param uri Campaign URI stored by MockCampaignHooksWithFees
    /// @param nonce Deterministic salt for the campaign address
    /// @return campaign The newly created (or already deployed) campaign address
    function createSimpleCampaign(address owner_, address manager_, string memory uri, uint256 nonce)
        public
        returns (address campaign)
    {
        bytes memory hookData = abi.encode(owner_, manager_, uri);
        campaign = flywheel.createCampaign(address(mockCampaignHooksWithFees), nonce, hookData);
    }

    /// @notice Predicts a MockCampaignHooksWithFees campaign address without deploying it
    /// @param owner_ Campaign owner
    /// @param manager_ Campaign manager
    /// @param uri Campaign URI
    /// @param nonce Salt
    /// @return predicted Predicted campaign address
    function predictSimpleCampaign(address owner_, address manager_, string memory uri, uint256 nonce)
        public
        view
        returns (address predicted)
    {
        bytes memory hookData = abi.encode(owner_, manager_, uri);
        predicted = flywheel.predictCampaignAddress(address(mockCampaignHooksWithFees), nonce, hookData);
    }

    /// @notice Activates a campaign using MockCampaignHooksWithFees manager
    /// @param campaign Campaign address
    /// @param manager_ Manager authorized in SimpleRewards
    function activateCampaign(address campaign, address manager_) public {
        vm.prank(manager_);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
    }

    /// @notice Finalizes a campaign (ACTIVE -> FINALIZED)
    /// @param campaign Campaign address
    /// @param manager_ Manager authorized in MockCampaignHooksWithFees
    function finalizeCampaign(address campaign, address manager_) public {
        vm.startPrank(manager_);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");
        vm.stopPrank();
    }

    /// @notice Funds a campaign with ERC20 tokens
    /// @param campaign Campaign address
    /// @param amount Amount to transfer
    /// @param funder Address that sends tokens
    function fundCampaign(address campaign, uint256 amount, address funder) public {
        vm.prank(funder);
        mockToken.transfer(campaign, amount);
    }

    /// @notice Builds a single payout entry array
    /// @param recipient Address to receive payout
    /// @param amount Amount to send
    /// @param extraData Extra data for event payloads
    /// @return payouts An array with one payout entry
    function buildSinglePayout(address recipient, uint256 amount, bytes memory extraData)
        public
        pure
        returns (Flywheel.Payout[] memory payouts)
    {
        payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: recipient, amount: amount, extraData: extraData});
    }

    /// @notice Calls Flywheel.send as the MockCampaignHooksWithFees manager
    /// @param campaign Campaign address
    /// @param tokenAddress Token to use
    /// @param payouts Payout array to encode into hookData
    function managerSend(address campaign, address tokenAddress, Flywheel.Payout[] memory payouts) public {
        vm.prank(manager);
        flywheel.send(campaign, tokenAddress, abi.encode(payouts));
    }

    /// @notice Calls Flywheel.allocate as the MockCampaignHooksWithFees manager
    /// @param campaign Campaign address
    /// @param tokenAddress Token to use
    /// @param payouts Payout array (used to derive allocations)
    function managerAllocate(address campaign, address tokenAddress, Flywheel.Payout[] memory payouts) public {
        vm.prank(manager);
        flywheel.allocate(campaign, tokenAddress, abi.encode(payouts));
    }

    /// @notice Calls Flywheel.deallocate as the MockCampaignHooksWithFees manager
    /// @param campaign Campaign address
    /// @param tokenAddress Token to use
    /// @param payouts Payout array (used to derive allocations)
    function managerDeallocate(address campaign, address tokenAddress, Flywheel.Payout[] memory payouts) public {
        vm.prank(manager);
        flywheel.deallocate(campaign, tokenAddress, abi.encode(payouts));
    }

    /// @notice Calls Flywheel.distribute as the MockCampaignHooksWithFees manager
    /// @param campaign Campaign address
    /// @param tokenAddress Token to use
    /// @param payouts Payout array (used to derive distributions)
    function managerDistribute(address campaign, address tokenAddress, Flywheel.Payout[] memory payouts) public {
        vm.prank(manager);
        flywheel.distribute(campaign, tokenAddress, abi.encode(payouts));
    }

    /// @notice Calls Flywheel.withdrawFunds as the MockCampaignHooksWithFees owner
    /// @param campaign Campaign address
    /// @param tokenAddress Token to withdraw
    /// @param recipient Recipient of withdrawn funds
    /// @param amount Amount to withdraw
    function ownerWithdraw(address campaign, address tokenAddress, address recipient, uint256 amount) public {
        vm.prank(owner);
        flywheel.withdrawFunds(
            campaign, tokenAddress, abi.encode(Flywheel.Payout({recipient: recipient, amount: amount, extraData: ""}))
        );
    }

    // ============ Fuzz Utilities ============

    /// @notice Bounds an amount to be non-zero and within MAX_FUZZ_AMOUNT
    /// @param amount Fuzzed amount input
    /// @return Bounded amount between 1 and MAX_FUZZ_AMOUNT
    function boundToValidAmount(uint256 amount) public pure returns (uint256) {
        return bound(amount, 1, MAX_FUZZ_AMOUNT);
    }

    /// @notice Bounds an amount to be within MAX_FUZZ_AMOUNT (allows zero)
    /// @param amount Fuzzed amount input
    /// @return Bounded amount between 0 and MAX_FUZZ_AMOUNT
    function boundToMaxAmount(uint256 amount) public pure returns (uint256) {
        return bound(amount, 0, MAX_FUZZ_AMOUNT);
    }

    /// @notice Bounds an address to be non-zero
    /// @param addr Fuzzed address input
    /// @return Bounded address that is not address(0)
    function boundToValidAddress(address addr) public pure returns (address) {
        return address(uint160(bound(uint160(addr), 1, type(uint160).max)));
    }

    /// @notice Bounds two amounts for multi-allocation tests where total must not exceed MAX_FUZZ_AMOUNT
    /// @param amount1 First fuzzed amount
    /// @param amount2 Second fuzzed amount
    /// @return amount1Bounded First bounded amount (1 to MAX_FUZZ_AMOUNT/2)
    /// @return amount2Bounded Second bounded amount (1 to remaining capacity)
    function boundToValidMultiAmounts(uint256 amount1, uint256 amount2)
        public
        pure
        returns (uint256 amount1Bounded, uint256 amount2Bounded)
    {
        amount1Bounded = bound(amount1, 1, MAX_FUZZ_AMOUNT / 2);
        uint256 remaining = MAX_FUZZ_AMOUNT - amount1Bounded;
        amount2Bounded = bound(amount2, 1, remaining);
    }
}

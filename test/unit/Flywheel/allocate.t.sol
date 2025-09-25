// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title AllocateTest
/// @notice Tests for Flywheel.allocate
contract AllocateTest is Test {
    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts when campaign does not exist
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignDoesNotExist(address token, bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is INACTIVE
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignInactive(address token, bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is FINALIZED
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignFinalized(address token, bytes memory hookData) public {}

    /// @dev Expects InsufficientCampaignFunds
    /// @dev Reverts if campaign is insufficiently funded
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_reverts_ifCampaignIsInsufficientlyFunded(address recipient, uint256 amount) public {}

    /// @dev Verifies that allocate calls are allowed for campaign in ACTIVE state
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_succeeds_whenCampaignActive(address recipient, uint256 amount) public {}

    /// @dev Verifies that allocate remains allowed for campaign in FINALIZING state
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_succeeds_whenCampaignFinalizing(address recipient, uint256 amount) public {}

    /// @dev Verifies that allocate calls work with an ERC20 token
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_succeeds_withERC20Token(address recipient, uint256 amount) public {}

    /// @dev Verifies that allocate calls work with native token
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_succeeds_withNativeToken(address recipient, uint256 amount) public {}

    /// @dev Ignores zero-amount allocations (no-op)
    /// @dev Verifies totals for zero amounts
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_ignoresZeroAmountAllocations(address recipient, uint256 amount) public {}

    /// @dev Verifies that allocate calls work with multiple allocations
    /// @param recipient1 First recipient address
    /// @param recipient2 Second recipient address
    /// @param amount1 First allocation amount
    /// @param amount2 Second allocation amount
    function test_succeeds_withMultipleAllocations(
        address recipient1,
        address recipient2,
        uint256 amount1,
        uint256 amount2
    ) public {}

    /// @dev Emits PayoutAllocated event
    /// @param recipient Recipient address
    /// @param amount Allocation amount
    function test_emitsPayoutAllocatedEvent(address recipient, uint256 amount) public {}
}

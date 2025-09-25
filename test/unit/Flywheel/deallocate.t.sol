// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title DeallocateTest
/// @notice Tests for Flywheel.deallocate
contract DeallocateTest is Test {
    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts if campaign does not exist
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignDoesNotExist(address token, bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts if campaign is INACTIVE
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignInactive(address token, bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts if campaign is FINALIZED
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignFinalized(address token, bytes memory hookData) public {}

    /// @dev Expects InsufficientCampaignFunds
    /// @dev Verifies that deallocate reverts if campaign is insufficiently funded
    /// @param amount Deallocation amount
    function test_reverts_ifCampaignIsInsufficientlyFunded(uint256 amount) public {}

    /// @dev Verifies that deallocate calls are allowed for campaign in ACTIVE state
    /// @param amount Deallocation amount
    function test_succeeds_whenCampaignActive(uint256 amount) public {}

    /// @dev Verifies that deallocate remains allowed for campaign in FINALIZING state
    /// @param amount Deallocation amount
    function test_succeeds_whenCampaignFinalizing(uint256 amount) public {}

    /// @dev Verifies that deallocate calls work with an ERC20 token
    /// @param amount Deallocation amount
    function test_succeeds_withERC20Token(uint256 amount) public {}

    /// @dev Verifies that deallocate calls work with native token
    /// @param amount Deallocation amount
    function test_succeeds_withNativeToken(uint256 amount) public {}

    /// @notice Ignores zero-amount deallocations (no-op)
    /// @dev Verifies totals unchanged and no event for zero amounts using the deployed token
    function test_ignoresZeroAmountDeallocations() public {}

    /// @dev Verifies that deallocate calls work with multiple deallocations
    /// @param amount1 First deallocation amount
    /// @param amount2 Second deallocation amount
    function test_succeeds_withMultipleDeallocations(uint256 amount1, uint256 amount2) public {}

    /// @dev Verifies that the PayoutsDeallocated event is emitted for each deallocation
    /// @param amount Deallocation amount
    function test_emitsPayoutsDeallocatedEvent(uint256 amount) public {}
}

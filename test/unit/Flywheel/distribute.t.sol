// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title DistributeTest
/// @notice Tests for Flywheel.distribute
contract DistributeTest is Test {
    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts when campaign does not exist
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_distribute_reverts_whenCampaignDoesNotExist(address token, bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is INACTIVE
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_distribute_reverts_whenCampaignInactive(address token, bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is FINALIZED
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_distribute_reverts_whenCampaignFinalized(address token, bytes memory hookData) public {}

    /// @dev Expects SendFailed
    /// @dev Reverts when token transfer fails with an ERC20 token
    /// @param amount Distribution amount
    function test_distribute_reverts_whenSendFailed_ERC20(uint256 amount) public {}

    /// @dev Expects SendFailed
    /// @dev Reverts when token transfer fails with native token
    /// @param amount Distribution amount
    function test_distribute_reverts_whenSendFailed_nativeToken(uint256 amount) public {}

    /// @dev Verifies that distribute calls are allowed when campaign is ACTIVE
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_distribute_succeeds_whenCampaignActive(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute remains allowed when campaign is FINALIZING
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_distribute_succeeds_whenCampaignFinalizing(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute calls work with an ERC20 token
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_distribute_succeeds_withERC20Token(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute calls work with native token
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_distribute_succeeds_withNativeToken(address recipient, uint256 amount) public {}

    /// @notice Ignores zero-amount distributions (no-op)
    /// @dev Verifies totals unchanged and no event for zero amounts using the deployed token
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_distribute_ignoresZeroAmountDistributions(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute calls work with multiple distributions
    /// @param recipient1 First recipient address
    /// @param recipient2 Second recipient address
    /// @param amount1 First distribution amount
    /// @param amount2 Second distribution amount
    function test_distribute_succeeds_withMultipleDistributions(
        address recipient1,
        address recipient2,
        uint256 amount1,
        uint256 amount2
    ) public {}

    /// @dev Verifies that the PayoutsDistributed event is emitted for each distribution
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_distribute_emitsPayoutsDistributedEvent(address recipient, uint256 amount) public {}
}

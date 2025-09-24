// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title DistributeFeesTest
/// @notice Test stubs for Flywheel.distributeFees
contract DistributeFeesTest is Test {
    /// @notice Distributes allocated fees to recipients and emits FeesDistributed
    /// @dev Verifies clearing of allocatedFee for distributed amounts using deployed token
    /// @param amount Fee amount (fuzzed)
    function test_distributeFees_sendsFees_andClearsAllocation(uint256 amount) public {}

    /// @notice Emits FeeTransferFailed and keeps allocation when send fails
    /// @dev Verifies failure path keeps allocatedFee and emits failure event
    /// @param token ERC20 token address under test (fuzzed)
    /// @param amount Fee amount (fuzzed)
    function test_distributeFees_emitsFailure_andKeepsAllocationOnSendFailure(address token, uint256 amount) public {}

    /// @notice OnlyExists modifier enforced (campaign must exist)
    /// @dev Expects CampaignDoesNotExist when using unknown address
    /// @param token ERC20 token address under test (fuzzed)
    function test_distributeFees_reverts_whenCampaignDoesNotExist(address token, address unknownCampaign) public {}
}

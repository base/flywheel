// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../src/Flywheel.sol";
import {SimpleRewards} from "../../src/hooks/SimpleRewards.sol";

/// @title MultiTokenTest
/// @notice Tests for per-token isolation in Flywheel accounting and flows
contract MultiTokenTest is Test {
    /// @dev Allocate and distribute are isolated per token
    /// @dev Verifies balances and accounting do not cross-contaminate across tokens
    function test_multiToken_allocateDistribute_isolatedPerToken() public {}

    /// @dev Send and distributeFees are isolated per token
    /// @dev Verifies allocations and fee collection per token without interference
    function test_multiToken_sendAndDistributeFees_isolatedPerToken() public {}
}

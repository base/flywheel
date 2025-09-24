// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title DistributeFeesTest
/// @notice Tests for Flywheel.distributeFees
contract DistributeFeesTest is Test {
    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts when campaign does not exist
    /// @param token ERC20 token address under test
    /// @param unknownCampaign Non-existent campaign address
    function test_distributeFees_reverts_whenCampaignDoesNotExist(address token, address unknownCampaign) public {}

    /// @dev Verifies fees distribution succeeds with an ERC20 token and clears allocated fee
    /// @param recipient Fee recipient address
    /// @param amount Fee amount
    function test_distributeFees_succeeds_withERC20Token(address recipient, uint256 amount) public {}

    /// @dev Verifies fees distribution succeeds with native token and clears allocated fee
    /// @param recipient Fee recipient address
    /// @param amount Fee amount
    function test_distributeFees_succeeds_withNativeToken(address recipient, uint256 amount) public {}

    /// @dev Keeps allocation when send fails with ERC20; emits failure
    /// @param amount Fee amount
    function test_distributeFees_keepsAllocation_onSendFailure_ERC20(uint256 amount) public {}

    /// @dev Keeps allocation when send fails with native token; emits failure
    /// @param amount Fee amount
    function test_distributeFees_keepsAllocation_onSendFailure_nativeToken(uint256 amount) public {}

    /// @notice Ignores zero-amount fee distributions (no-op)
    /// @dev Verifies totals unchanged and no send attempt for zero amounts
    /// @param recipient Fee recipient address
    /// @param amount Fee amount
    function test_distributeFees_ignoresZeroAmountDistributions(address recipient, uint256 amount) public {}

    /// @dev Verifies multiple fee distributions in a single call
    /// @param recipient1 First recipient address
    /// @param recipient2 Second recipient address
    /// @param amount1 First fee amount
    /// @param amount2 Second fee amount
    function test_distributeFees_succeeds_withMultipleDistributions(
        address recipient1,
        address recipient2,
        uint256 amount1,
        uint256 amount2
    ) public {}

    /// @dev Verifies that FeesDistributed event is emitted on successful distribution
    /// @param recipient Fee recipient address
    /// @param amount Fee amount
    function test_distributeFees_emitsFeesDistributed(address recipient, uint256 amount) public {}

    /// @dev Verifies that FeeTransferFailed event is emitted on failed send
    /// @param recipient Fee recipient address
    /// @param amount Fee amount
    function test_distributeFees_emitsFeeTransferFailed(address recipient, uint256 amount) public {}
}

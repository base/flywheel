// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title SendTest
/// @notice Test stubs for Flywheel.send
contract SendTest is Test {
    /// @notice Transfers immediate payouts and emits PayoutSent events
    /// @dev Uses SimpleRewards as manager-controlled payouts and a deployed test token
    /// @param amount Payout amount (fuzzed)
    function test_send_transfersPayouts_andEmitsEvents(uint256 amount) public {}

    /// @notice Succeeds when campaign is FINALIZING
    /// @dev Verifies that send remains allowed in FINALIZING state
    /// @param amount Payout amount (fuzzed)
    function test_send_succeeds_whenCampaignFinalizing(uint256 amount) public {}

    /// @notice Reverts when campaign is INACTIVE
    /// @dev Expects InvalidCampaignStatus
    /// @param token ERC20 token address under test (fuzzed)
    /// @param hookData Raw hook data (fuzzed)
    function test_send_reverts_whenCampaignInactive(address token, bytes memory hookData) public {}

    /// @notice Reverts when campaign is FINALIZED
    /// @dev Expects InvalidCampaignStatus
    /// @param token ERC20 token address under test (fuzzed)
    /// @param hookData Raw hook data (fuzzed)
    function test_send_reverts_whenCampaignFinalized(address token, bytes memory hookData) public {}

    /// @notice Handles zero-amount payouts gracefully (skips transfer)
    /// @dev Confirms event emission and no token transfer using deployed token
    /// @param hookData Raw hook data (fuzzed)
    function test_send_handlesZeroAmountPayouts(bytes memory hookData) public {}

    /// @notice Reverts when token send fails without fallback
    /// @dev Expects SendFailed
    /// @param token ERC20 token address under test (fuzzed)
    /// @param hookData Raw hook data (fuzzed)
    function test_send_reverts_whenSendFailed(address token, bytes memory hookData) public {}
}

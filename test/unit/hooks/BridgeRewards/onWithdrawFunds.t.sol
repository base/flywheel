// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnWithdrawFundsTest is BridgeRewardsTest {
    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Returns payout struct decoded directly from hookData
    /// @param recipient Address to receive withdrawn funds
    /// @param amount Amount to withdraw
    /// @param extraData Additional payout data
    function test_onWithdrawFunds_success_passesThoughPayoutData(address recipient, uint256 amount, bytes memory extraData) public {}

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies payout recipient matches hookData recipient
    /// @param recipient Expected recipient address
    /// @param amount Withdrawal amount
    function test_onWithdrawFunds_correctRecipient(address recipient, uint256 amount) public {}

    /// @dev Verifies payout amount matches hookData amount
    /// @param recipient Recipient address
    /// @param amount Expected withdrawal amount
    function test_onWithdrawFunds_correctAmount(address recipient, uint256 amount) public {}

    /// @dev Verifies payout extraData matches hookData extraData
    /// @param recipient Recipient address
    /// @param amount Withdrawal amount
    /// @param extraData Expected extra data
    function test_onWithdrawFunds_correctExtraData(address recipient, uint256 amount, bytes memory extraData) public {}
}

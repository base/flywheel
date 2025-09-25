// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnWithdrawFundsTest is BridgeRewardsTest {
    /// @notice Tests that onWithdrawFunds reverts when called by non-Flywheel address
    ///
    /// @dev Should revert with access control error when called directly instead of through Flywheel
    ///
    /// @param hookData The hook data to test with
    function test_onWithdrawFunds_revert_onlyFlywheel(bytes memory hookData) public {}

    /// @notice Tests that onWithdrawFunds reverts when hookData has invalid format
    ///
    /// @dev Should revert when hookData cannot be decoded as Flywheel.Payout struct
    ///
    /// @param hookData The malformed hook data that should cause revert
    function test_onWithdrawFunds_revert_invalidHookData(bytes memory hookData) public {}

    /// @notice Tests that onWithdrawFunds reverts when campaign has insufficient funds
    ///
    /// @dev Should revert when trying to withdraw more than available campaign balance
    ///      excluding allocated fees
    ///
    /// @param user The original recipient address
    /// @param bridgedAmount The original bridged amount
    /// @param feeBps The fee basis points
    function test_onWithdrawFunds_revert_campaignInsufficientFunds(address user, uint256 bridgedAmount, uint16 feeBps)
        public
    {}

    /// @notice Tests successful fund withdrawal with specified payout parameters
    ///
    /// @dev Verifies funds are withdrawn to specified recipient with correct amount
    ///      Tests that withdrawal bypasses normal bridge reward logic
    ///
    /// @param recipient The recipient address for withdrawal
    /// @param amount The amount to withdraw
    /// @param extraData Additional data for the payout
    function test_onWithdrawFunds_success_erc20(address recipient, uint256 amount, bytes memory extraData) public {}

    /// @notice Tests successful fund withdrawal with native token (ETH)
    ///
    /// @dev Verifies withdrawal works with native token instead of ERC20
    ///      Tests ETH withdrawal functionality
    ///
    /// @param recipient The recipient address for withdrawal
    /// @param amount The amount to withdraw
    /// @param extraData Additional data for the payout
    function test_onWithdrawFunds_success_nativeToken(address recipient, uint256 amount, bytes memory extraData)
        public
    {}
}

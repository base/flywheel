// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnSendTest is BridgeRewardsTest {
    /// @notice Tests that onSend reverts when called by non-Flywheel address
    ///
    /// @dev Should revert with access control error when called directly instead of through Flywheel
    ///
    /// @param hookData The hook data to test with
    function test_onSend_revert_onlyFlyweel(bytes memory hookData) public {}

    /// @notice Tests that onSend reverts when hookData has invalid format
    ///
    /// @dev Should revert when hookData cannot be decoded as (address, uint256, bytes32, uint16)
    ///
    /// @param hookData The malformed hook data that should cause revert
    function test_onSend_revert_invalidHookData(bytes memory hookData) public {}

    /// @notice Tests that onSend reverts when bridged amount is zero
    ///
    /// @dev Should revert with ZeroBridgedAmount error when bridgedAmount parameter is 0
    ///
    /// @param user The recipient address
    /// @param feeBps The fee basis points
    function test_onSend_revert_zeroBridgedAmount(address user, uint16 feeBps) public {}

    /// @notice Tests that onSend reverts when payout transfer fails
    ///
    /// @dev Should revert when token transfer to user fails (e.g., token contract rejects transfer)
    ///
    /// @param user The recipient address
    /// @param bridgedAmount The amount being bridged
    /// @param feeBps The fee basis points
    function test_onSend_revert_payoutFailed(address user, uint256 bridgedAmount, uint16 feeBps) public {}

    /// @notice Tests that onSend reverts when campaign has insufficient funds
    ///
    /// @dev Should revert when campaign balance is less than bridgedAmount
    ///
    /// @param user The recipient address
    /// @param bridgedAmount The amount being bridged (exceeds campaign balance)
    /// @param feeBps The fee basis points
    function test_onSend_revert_campaignInsufficientFunds(address user, uint256 bridgedAmount, uint16 feeBps) public {}

    /// @notice Tests successful onSend with payout and fee distribution
    ///
    /// @dev Verifies user receives bridgedAmount minus fee, builder receives fee
    ///      Tests with registered builder code and valid fee
    ///
    /// @param user The recipient address
    /// @param bridgedAmount The amount being bridged
    /// @param feeBps The fee basis points (within valid range)
    function test_onSend_success_erc20PayoutAndFeeSent(address user, uint256 bridgedAmount, uint16 feeBps) public {}

    /// @notice Tests onSend with native token (ETH) instead of ERC20
    ///
    /// @dev Verifies bridge rewards work with native token transfers
    ///      Tests ETH payouts and fee distributions
    ///
    /// @param user The recipient address
    /// @param bridgedAmount The amount being bridged
    /// @param feeBps The fee basis points
    function test_onSend_success_nativeTokenPayoutAndFeeSent(address user, uint256 bridgedAmount, uint16 feeBps)
        public
    {}

    /// @notice Tests onSend when builder code is not registered
    ///
    /// @dev Should set fee to 0 when builder code is not registered, user receives full amount
    ///
    /// @param user The recipient address
    /// @param bridgedAmount The amount being bridged
    /// @param feeBps The fee basis points (ignored due to unregistered code)
    function test_onSend_success_builderCodeNotRegistered(address user, uint256 bridgedAmount, uint16 feeBps) public {}

    /// @notice Tests onSend when fee exceeds maximum allowed fee
    ///
    /// @dev Should cap fee at MAX_FEE_BASIS_POINTS (200 bps = 2%) when feeBps exceeds maximum
    ///
    /// @param user The recipient address
    /// @param bridgedAmount The amount being bridged
    /// @param feeBps The fee basis points (exceeds MAX_FEE_BASIS_POINTS)
    function test_onSend_success_feeExceedsMaxFeeBps(address user, uint256 bridgedAmount, uint16 feeBps) public {}

    /// @notice Tests onSend with zero fee
    ///
    /// @dev Verifies user receives full bridgedAmount when fee is 0, no fee distribution
    ///
    /// @param user The recipient address
    /// @param bridgedAmount The amount being bridged
    /// @param code The builder code (fee will be 0)
    function test_onSend_success_zeroFee(address user, uint256 bridgedAmount, bytes32 code) public {}

    /// @notice Tests onSend when fee send fails but payout succeeds
    ///
    /// @dev Verifies user still receives payout, fee is allocated for later distribution
    ///      Tests graceful handling of failed fee transfers
    ///
    /// @param user The recipient address
    /// @param bridgedAmount The amount being bridged
    /// @param feeBps The fee basis points
    function test_onSend_success_feeSendFails(address user, uint256 bridgedAmount, uint16 feeBps) public {}
}

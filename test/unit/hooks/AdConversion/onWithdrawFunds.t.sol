// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

abstract contract OnWithdrawFundsTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when caller is not the advertiser
    /// @param unauthorizedCaller Unauthorized caller address (not advertiser)
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param recipient Withdrawal recipient address
    /// @param amount Withdrawal amount
    function test_revert_unauthorizedCaller(
        address unauthorizedCaller,
        address campaign,
        address token,
        address recipient,
        uint256 amount
    ) public virtual;

    /// @dev Reverts when campaign is not in FINALIZED status
    /// @param caller Authorized advertiser address
    /// @param campaign Campaign address in non-finalized status
    /// @param token Token address
    /// @param recipient Withdrawal recipient address
    /// @param amount Withdrawal amount
    /// @param currentStatus Current non-finalized campaign status
    function test_revert_campaignNotFinalized(
        address caller,
        address campaign,
        address token,
        address recipient,
        uint256 amount,
        uint8 currentStatus
    ) public virtual;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully processes fund withdrawal by advertiser from finalized campaign
    /// @param advertiser Advertiser address
    /// @param campaign Finalized campaign address
    /// @param token Token address
    /// @param recipient Withdrawal recipient address
    /// @param amount Withdrawal amount
    function test_success_authorizedWithdrawal(
        address advertiser,
        address campaign,
        address token,
        address recipient,
        uint256 amount
    ) public virtual;

    /// @dev Successfully processes withdrawal with advertiser as recipient
    /// @param advertiser Advertiser address (same as recipient)
    /// @param campaign Finalized campaign address
    /// @param token Token address
    /// @param amount Withdrawal amount
    function test_success_advertiserAsRecipient(address advertiser, address campaign, address token, uint256 amount)
        public
        virtual;

    /// @dev Successfully processes withdrawal with different recipient
    /// @param advertiser Advertiser address
    /// @param campaign Finalized campaign address
    /// @param token Token address
    /// @param differentRecipient Different withdrawal recipient address
    /// @param amount Withdrawal amount
    function test_success_differentRecipient(
        address advertiser,
        address campaign,
        address token,
        address differentRecipient,
        uint256 amount
    ) public virtual;

    /// @dev Successfully processes withdrawal with native token
    /// @param advertiser Advertiser address
    /// @param campaign Finalized campaign address
    /// @param recipient Withdrawal recipient address
    /// @param amount Withdrawal amount
    function test_success_nativeToken(address advertiser, address campaign, address recipient, uint256 amount)
        public
        virtual;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles withdrawal of zero amount
    /// @param advertiser Advertiser address
    /// @param campaign Finalized campaign address
    /// @param token Token address
    /// @param recipient Withdrawal recipient address
    function test_edge_zeroAmount(address advertiser, address campaign, address token, address recipient)
        public
        virtual;

    /// @dev Handles withdrawal of maximum uint256 amount
    /// @param advertiser Advertiser address
    /// @param campaign Finalized campaign address
    /// @param token Token address
    /// @param recipient Withdrawal recipient address
    function test_edge_maximumAmount(address advertiser, address campaign, address token, address recipient)
        public
        virtual;

    /// @dev Handles multiple withdrawals from same campaign
    /// @param advertiser Advertiser address
    /// @param campaign Finalized campaign address
    /// @param token Token address
    /// @param recipient1 First withdrawal recipient
    /// @param recipient2 Second withdrawal recipient
    /// @param amount1 First withdrawal amount
    /// @param amount2 Second withdrawal amount
    function test_edge_multipleWithdrawals(
        address advertiser,
        address campaign,
        address token,
        address recipient1,
        address recipient2,
        uint256 amount1,
        uint256 amount2
    ) public virtual;

    // ========================================
    // RETURN VALUE VERIFICATION
    // ========================================

    /// @dev Verifies correct withdrawal data in return value
    /// @param advertiser Advertiser address
    /// @param campaign Finalized campaign address
    /// @param token Token address
    /// @param recipient Withdrawal recipient address
    /// @param amount Withdrawal amount
    function test_returnsCorrectWithdrawalData(
        address advertiser,
        address campaign,
        address token,
        address recipient,
        uint256 amount
    ) public virtual;
}

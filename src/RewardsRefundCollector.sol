// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TokenCollector} from "commerce-payments/collectors/TokenCollector.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";
import {CampaignHooks} from "./CampaignHooks.sol";

/// @title RewardsRefundCollector
/// @notice Collect refunds using ERC-20 allowances from operators, deducting for any rewards that were allocated for the payment,
/// reimbursing the rewarders, and returning the remainder to the payer.
/// @author Coinbase
contract RewardsRefundCollector is TokenCollector {
    /// @notice The rewards hook contract for which the collector will honor reward reimbursements
    CampaignHooks public immutable rewardsHook;

    /// @inheritdoc TokenCollector
    TokenCollector.CollectorType public constant override collectorType = TokenCollector.CollectorType.Refund;

    /// @notice Constructor
    /// @param authCaptureEscrow_ AuthCaptureEscrow singleton that calls to collect tokens
    constructor(address authCaptureEscrow_, address rewardsHook_) TokenCollector(authCaptureEscrow_) {
        rewardsHook = CampaignHooks(rewardsHook_);
    }

    /// @inheritdoc TokenCollector
    /// @dev Transfers from operator directly to token store, requiring previous ERC-20 allowance set by operator on this token collector
    /// @dev Only operator can initate token collection so authentication is inherited from Escrow
    function _collectTokens(
        AuthCaptureEscrow.PaymentInfo calldata paymentInfo,
        address tokenStore,
        uint256 amount,
        bytes calldata
    ) internal override {
        /// note that amount here is what is expected by the AuthCaptureEscrow, so that needs to be the net amount that will
        /// be sent to the actual payer. Additional reimbursements will be sent to the rewarders, also from the operator's
        /// liquidity.

        SafeERC20.safeTransferFrom(IERC20(paymentInfo.token), paymentInfo.operator, tokenStore, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";
import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnWithdrawFundsTest is BridgeRewardsTest {
    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Returns payout struct decoded directly from hookData
    /// @param recipient Address to receive withdrawn funds
    /// @param amount Amount to withdraw
    /// @param extraData Additional payout data
    function test_onWithdrawFunds_success_passesThoughPayoutData(
        address recipient,
        uint256 amount,
        bytes memory extraData
    ) public {
        vm.assume(amount > 0); // Flywheel rejects zero amount withdrawals
        Flywheel.Payout memory expectedPayout =
            Flywheel.Payout({recipient: recipient, amount: amount, extraData: extraData});

        bytes memory hookData = abi.encode(expectedPayout);

        // Fund campaign to enable withdrawal
        usdc.mint(bridgeRewardsCampaign, amount);

        uint256 recipientBalanceBefore = usdc.balanceOf(recipient);

        flywheel.withdrawFunds(bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(
            usdc.balanceOf(recipient), recipientBalanceBefore + amount, "Recipient should receive withdrawal amount"
        );
    }

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies payout recipient matches hookData recipient
    /// @param recipient Expected recipient address
    /// @param amount Withdrawal amount
    function test_onWithdrawFunds_correctRecipient(address recipient, uint256 amount) public {
        Flywheel.Payout memory payout = Flywheel.Payout({recipient: recipient, amount: amount, extraData: ""});

        bytes memory hookData = abi.encode(payout);

        // Call onWithdrawFunds directly to check return values
        vm.prank(address(flywheel));
        Flywheel.Payout memory returnedPayout =
            bridgeRewards.onWithdrawFunds(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(returnedPayout.recipient, recipient, "Returned payout recipient should match expected");
    }

    /// @dev Verifies payout amount matches hookData amount
    /// @param recipient Recipient address
    /// @param amount Expected withdrawal amount
    function test_onWithdrawFunds_correctAmount(address recipient, uint256 amount) public {
        Flywheel.Payout memory payout = Flywheel.Payout({recipient: recipient, amount: amount, extraData: ""});

        bytes memory hookData = abi.encode(payout);

        vm.prank(address(flywheel));
        Flywheel.Payout memory returnedPayout =
            bridgeRewards.onWithdrawFunds(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(returnedPayout.amount, amount, "Returned payout amount should match expected");
    }

    /// @dev Verifies payout extraData matches hookData extraData
    /// @param recipient Recipient address
    /// @param amount Withdrawal amount
    /// @param extraData Expected extra data
    function test_onWithdrawFunds_correctExtraData(address recipient, uint256 amount, bytes memory extraData) public {
        Flywheel.Payout memory payout = Flywheel.Payout({recipient: recipient, amount: amount, extraData: extraData});

        bytes memory hookData = abi.encode(payout);

        vm.prank(address(flywheel));
        Flywheel.Payout memory returnedPayout =
            bridgeRewards.onWithdrawFunds(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(
            keccak256(returnedPayout.extraData), keccak256(extraData), "Returned payout extraData should match expected"
        );
    }
}

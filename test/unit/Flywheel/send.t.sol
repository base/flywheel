// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title SendTest
/// @notice Tests for Flywheel.send
contract SendTest is Test {
    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts when campaign does not exist
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignDoesNotExist(address token, bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is INACTIVE
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignInactive(address token, bytes memory hookData) public {}

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is FINALIZED
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignFinalized(address token, bytes memory hookData) public {}

    /// @dev Expects SendFailed
    /// @dev Reverts when token transfer fails with an ERC20 token
    /// @param amount Payout amount
    function test_reverts_whenSendFailed_ERC20(uint256 amount) public {}

    /// @dev Expects SendFailed
    /// @dev Reverts when token transfer fails with native token
    /// @param amount Payout amount
    function test_reverts_whenSendFailed_nativeToken(uint256 amount) public {}

    /// @dev Expects InsufficientCampaignFunds
    /// @dev Reverts when campaign is not solvent
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_reverts_whenCampaignIsNotSolvent(address recipient, uint256 amount) public {}

    /// @dev Verifies that send calls are allowed when campaign is ACTIVE
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_succeeds_whenCampaignActive(address recipient, uint256 amount) public {}

    /// @dev Verifies that send remains allowed when campaign is FINALIZING
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_succeeds_whenCampaignFinalizing(address recipient, uint256 amount) public {}

    /// @dev Verifies that send calls work with an ERC20 token
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_succeeds_withERC20Token(address recipient, uint256 amount) public {}

    /// @dev Verifies that send calls work with native token
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_succeeds_withNativeToken(address recipient, uint256 amount) public {}

    /// @dev Verifies that send enforces campaign solvency
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_enforcesCampaignSolvency(address recipient, uint256 amount) public {}

    /// @dev Ignores zero-amount payouts (no-op)
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_ignoresZeroAmountPayouts(address recipient, uint256 amount) public {}

    /// @dev Verifies that send calls work with multiple payouts
    /// @param recipient1 First recipient address
    /// @param recipient2 Second recipient address
    /// @param amount1 First payout amount
    /// @param amount2 Second payout amount
    function test_succeeds_withMultiplePayouts(address recipient1, address recipient2, uint256 amount1, uint256 amount2)
        public
    {}

    /// @dev Verifies that send calls work with deferred fees (allocated, not sent)
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_succeeds_withDeferredFees(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {}

    /// @dev Verifies that send calls work with immediate fees (sent now if possible)
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_succeeds_withImmediateFees(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {}

    /// @dev Verifies that allocated fees are updated when immediate fee send fails
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_updatesAllocatedFees_onFeeSendFailure(
        address recipient,
        uint256 amount,
        uint256 feeBp,
        address feeRecipient
    ) public {}

    /// @dev Verifies that distribute skips fees of zero amount
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_skipsFeesOfZeroAmount(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {}

    /// @dev Verifies that send handles multiple fees in a single call
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_handlesMultipleFees(address recipient, uint256 amount, uint256 feeBp, address feeRecipient) public {}

    /// @dev Verifies that the PayoutSent event is emitted for each payout
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_emitsPayoutSentEvent(address recipient, uint256 amount) public {}

    /// @dev Verifies that the FeeSent event is emitted on successful immediate fee send
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_emitsFeeSentEvent_ifFeeSendSucceeds(
        address recipient,
        uint256 amount,
        uint256 feeBp,
        address feeRecipient
    ) public {}

    /// @dev Verifies that the FeeTransferFailed event is emitted on failed immediate fee send
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_emitsFeeTransferFailedEvent_ifFeeSendFails(
        address recipient,
        uint256 amount,
        uint256 feeBp,
        address feeRecipient
    ) public {}

    /// @dev Verifies that the FeeAllocated event is emitted when immediate fee send fails
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_emitsFeeAllocatedEvent_ifFeeSendFails(
        address recipient,
        uint256 amount,
        uint256 feeBp,
        address feeRecipient
    ) public {}

    /// @dev Verifies that the FeeAllocated event is emitted for deferred fees
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_emitsFeeAllocatedEvent_forDeferredFees(
        address recipient,
        uint256 amount,
        uint256 feeBp,
        address feeRecipient
    ) public {}
}

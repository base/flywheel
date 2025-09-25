// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {SimpleRewards} from "../../../src/hooks/SimpleRewards.sol";

/// @title DistributeTest
/// @notice Tests for Flywheel.distribute
contract DistributeTest is Test {
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
    /// @param amount Distribution amount
    function test_reverts_whenSendFailed_ERC20(uint256 amount) public {}

    /// @dev Expects SendFailed
    /// @dev Reverts when token transfer fails with native token
    /// @param amount Distribution amount
    function test_reverts_whenSendFailed_nativeToken(uint256 amount) public {}

    /// @dev Expects InsufficientCampaignFunds
    /// @dev Reverts when campaign is not solvent
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_reverts_ifCampaignIsNotSolvent(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute calls are allowed when campaign is ACTIVE
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_succeeds_whenCampaignActive(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute remains allowed when campaign is FINALIZING
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_succeeds_whenCampaignFinalizing(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute calls work with an ERC20 token
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_succeeds_withERC20Token(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute calls work with native token
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_succeeds_withNativeToken(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute enforces campaign solvency
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_enforcesCampaignSolvency(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute calls work with fees
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_succeeds_withDeferredFees(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {}

    /// @dev Verifies that distribute calls work with immediate fees
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_succeeds_withImmediateFees(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {}

    /// @dev Verifies that distribute updates allocated fees on fee send failure
    /// @param recipient Recipient address
    /// @param amount Distribution amount
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
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_skipsFeesOfZeroAmount(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {}

    /// @dev Verifies that distribute handles multiple fees
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_handlesMultipleFees(address recipient, uint256 amount, uint256 feeBp, address feeRecipient) public {}

    /// @notice Ignores zero-amount distributions (no-op)
    /// @dev Verifies totals unchanged and no event for zero amounts using the deployed token
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_ignoresZeroAmountDistributions(address recipient, uint256 amount) public {}

    /// @dev Verifies that distribute calls work with multiple distributions
    /// @param recipient1 First recipient address
    /// @param recipient2 Second recipient address
    /// @param amount1 First distribution amount
    /// @param amount2 Second distribution amount
    function test_succeeds_withMultipleDistributions(
        address recipient1,
        address recipient2,
        uint256 amount1,
        uint256 amount2
    ) public {}

    /// @dev Verifies that the PayoutsDistributed event is emitted for each distribution
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_emitsPayoutsDistributedEvent(address recipient, uint256 amount) public {}

    /// @dev Verifies that the PayoutsDistributed event is emitted for each distribution
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_emitsFeeSentEvent_ifFeeSendSucceeds(
        address recipient,
        uint256 amount,
        uint256 feeBp,
        address feeRecipient
    ) public {}

    /// @dev Verifies that the FeeTransferFailed event is emitted for each failed fee distribution
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_emitsFeeTransferFailedEvent_ifFeeSendFails(
        address recipient,
        uint256 amount,
        uint256 feeBp,
        address feeRecipient
    ) public {}

    /// @dev Verifies that the FeeAllocated event is emitted for each allocated fee
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_emitsFeeAllocatedEvent_ifFeeSendFails(
        address recipient,
        uint256 amount,
        uint256 feeBp,
        address feeRecipient
    ) public {}

    /// @dev Verifies that the FeeAllocated event is emitted for each deferred fee
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_emitsFeeAllocatedEvent_forDeferredFees(
        address recipient,
        uint256 amount,
        uint256 feeBp,
        address feeRecipient
    ) public {}

    /// @dev Verifies that the FeesDistributed event is emitted for each fee distribution
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_emitsFeesDistributedEvent(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../src/Flywheel.sol";
import {Constants} from "../../../src/Constants.sol";
import {FlywheelTest} from "../../lib/FlywheelTestBase.sol";
import {RevertingReceiver} from "../../lib/mocks/RevertingReceiver.sol";
import {FailingERC20} from "../../lib/mocks/FailingERC20.sol";

/// @title SendTest
/// @notice Tests for Flywheel.send
contract SendTest is FlywheelTest {
    address public campaign;

    function setUp() public {
        setUpFlywheelBase();
        campaign = createSimpleCampaign(owner, manager, "Test Campaign", 1);
    }

    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts when campaign does not exist
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignDoesNotExist(address token, bytes memory hookData) public {
        address nonExistentCampaign = address(0x1234);

        vm.expectRevert(Flywheel.CampaignDoesNotExist.selector);
        flywheel.send(nonExistentCampaign, token, hookData);
    }

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is INACTIVE
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignInactive(address token, bytes memory hookData) public {
        // Campaign starts as INACTIVE by default
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.INACTIVE));
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        vm.prank(manager);
        flywheel.send(campaign, token, hookData);
    }

    /// @dev Expects InvalidCampaignStatus
    /// @dev Reverts when campaign is FINALIZED
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    function test_reverts_whenCampaignFinalized(address token, bytes memory hookData) public {
        activateCampaign(campaign, manager);
        finalizeCampaign(campaign, manager);
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZED));

        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        vm.prank(manager);
        flywheel.send(campaign, token, hookData);
    }

    /// @dev Expects SendFailed
    /// @dev Reverts when token transfer fails with an ERC20 token
    /// @param amount Payout amount
    function test_reverts_whenSendFailed_ERC20(uint256 amount) public {
        address recipient = makeAddr("recipient");
        amount = boundToValidAmount(amount);

        // Use a failing ERC20 token that will cause transfers to fail
        FailingERC20 failingToken = new FailingERC20();

        activateCampaign(campaign, manager);
        // Fund campaign with the failing token
        failingToken.mint(campaign, amount);

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        vm.expectRevert(abi.encodeWithSelector(Flywheel.SendFailed.selector, address(failingToken), recipient, amount));
        vm.prank(manager);
        flywheel.send(campaign, address(failingToken), hookData);
    }

    /// @dev Expects SendFailed
    /// @dev Reverts when token transfer fails with native token
    /// @param amount Payout amount
    function test_reverts_whenSendFailed_nativeToken(uint256 amount) public {
        // Create a contract that will reject native token transfers by reverting in its receive function
        RevertingReceiver revertingRecipient = new RevertingReceiver();
        address recipient = address(revertingRecipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        // Fund campaign with native token
        vm.deal(campaign, amount);

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        vm.expectRevert(abi.encodeWithSelector(Flywheel.SendFailed.selector, Constants.NATIVE_TOKEN, recipient, amount));
        vm.prank(manager);
        flywheel.send(campaign, Constants.NATIVE_TOKEN, hookData);
    }

    /// @dev Expects InsufficientCampaignFunds
    /// @dev Reverts when campaign is not solvent
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_reverts_whenCampaignIsNotSolvent(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);

        // Fund campaign with exact amount needed for allocation
        fundCampaign(campaign, amount, address(this));

        // Allocate all funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, amount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now try to send additional amount - this should fail solvency check
        // because all funds are allocated but we're trying to send more
        address recipient2 = makeAddr("recipient2");
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient2, amount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        vm.expectRevert(Flywheel.InsufficientCampaignFunds.selector);
        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);
    }

    /// @dev Verifies that send calls are allowed when campaign is ACTIVE
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_succeeds_whenCampaignActive(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        vm.assume(recipient != campaign); // Avoid self-transfers which don't change balance
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));
        fundCampaign(campaign, amount, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);

        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance + amount);
    }

    /// @dev Verifies that send remains allowed when campaign is FINALIZING
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_succeeds_whenCampaignFinalizing(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        // Move to FINALIZING state
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZING));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);

        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance + amount);
    }

    /// @dev Verifies that send calls work with an ERC20 token
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_succeeds_withERC20Token(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);

        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance + amount);
    }

    /// @dev Verifies that send calls work with native token
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_succeeds_withNativeToken(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        vm.assume(recipient != campaign); // Avoid self-transfers
        vm.assume(recipient != address(vm)); // Avoid VM precompile that rejects ETH
        vm.assume(uint160(recipient) > 255); // Avoid precompile addresses (0x01-0xff)
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        // Fund campaign with native token
        vm.deal(campaign, amount);

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialRecipientBalance = recipient.balance;

        vm.prank(manager);
        flywheel.send(campaign, Constants.NATIVE_TOKEN, hookData);

        assertEq(recipient.balance, initialRecipientBalance + amount);
    }

    /// @dev Ignores zero-amount payouts (no-op)
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_ignoresZeroAmountPayouts(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount); // Fund with some amount, but send 0

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, 0, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);

        // Zero amount should not change recipient balance
        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance);
    }

    /// @dev Verifies that send calls work with multiple payouts
    /// @param recipient1 First recipient address
    /// @param recipient2 Second recipient address
    /// @param amount1 First payout amount
    /// @param amount2 Second payout amount
    function test_succeeds_withMultiplePayouts(address recipient1, address recipient2, uint256 amount1, uint256 amount2)
        public
    {
        recipient1 = boundToValidAddress(recipient1);
        recipient2 = boundToValidAddress(recipient2);
        vm.assume(recipient1 != recipient2);
        vm.assume(recipient1 != campaign); // Avoid self-transfers
        vm.assume(recipient2 != campaign); // Avoid self-transfers

        (amount1, amount2) = boundToValidMultiAmounts(amount1, amount2);
        uint256 totalAmount = amount1 + amount2;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalAmount, address(this));

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](2);
        payouts[0] = Flywheel.Payout({recipient: recipient1, amount: amount1, extraData: "payout1"});
        payouts[1] = Flywheel.Payout({recipient: recipient2, amount: amount2, extraData: "payout2"});

        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialBalance1 = mockToken.balanceOf(recipient1);
        uint256 initialBalance2 = mockToken.balanceOf(recipient2);

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);

        assertEq(mockToken.balanceOf(recipient1), initialBalance1 + amount1);
        assertEq(mockToken.balanceOf(recipient2), initialBalance2 + amount2);
    }

    /// @dev Verifies that send calls work with deferred fees (allocated, not sent)
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_succeeds_withDeferredFees(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {
        recipient = boundToValidAddress(recipient);
        feeRecipient = boundToValidAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        uint256 totalFunding = amount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee");
        bytes memory hookData = buildSendHookData(payouts, fees, false); // Deferred fees

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);
        uint256 initialFeeRecipientBalance = mockToken.balanceOf(feeRecipient);

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);

        // Payout should be sent
        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance + amount);
        // Fee should NOT be sent (deferred), but allocated
        assertEq(mockToken.balanceOf(feeRecipient), initialFeeRecipientBalance);
        assertEq(flywheel.allocatedFee(campaign, address(mockToken), feeKey), feeAmount);
    }

    /// @dev Verifies that send calls work with immediate fees (sent now if possible)
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_succeeds_withImmediateFees(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {
        recipient = boundToValidAddress(recipient);
        feeRecipient = boundToValidAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        vm.assume(recipient != campaign); // Avoid self-transfers
        vm.assume(feeRecipient != campaign); // Avoid campaign as fee recipient
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        uint256 totalFunding = amount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee");
        bytes memory hookData = buildSendHookData(payouts, fees, true); // Immediate fees

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);
        uint256 initialFeeRecipientBalance = mockToken.balanceOf(feeRecipient);

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);

        // Payout should be sent
        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance + amount);
        // Fee should be sent immediately
        assertEq(mockToken.balanceOf(feeRecipient), initialFeeRecipientBalance + feeAmount);
        // No allocated fees since they were sent immediately
        assertEq(flywheel.allocatedFee(campaign, address(mockToken), feeKey), 0);
    }

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
    ) public {
        recipient = boundToValidAddress(recipient);
        vm.assume(recipient != campaign); // Avoid self-transfers
        // Force fee recipient to be address(0) to make fee transfer fail
        feeRecipient = address(0);
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        // Skip test if fee amount is zero (no allocation will occur)
        vm.assume(feeAmount > 0);
        activateCampaign(campaign, manager);
        // Fund for both payout and fee since fee will be allocated when transfer to address(0) fails
        uint256 totalFunding = amount + feeAmount;
        fundCampaign(campaign, totalFunding, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee");
        bytes memory hookData = buildSendHookData(payouts, fees, true); // Try immediate fees

        uint256 initialFeeRecipientBalance = mockToken.balanceOf(feeRecipient);

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);

        // Fee should NOT be sent (insufficient funds)
        assertEq(mockToken.balanceOf(feeRecipient), initialFeeRecipientBalance);
        // Fee should be allocated instead when send fails
        assertEq(flywheel.allocatedFee(campaign, address(mockToken), feeKey), feeAmount);
    }

    /// @dev Verifies that distribute skips fees of zero amount
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_skipsFeesOfZeroAmount(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {
        recipient = boundToValidAddress(recipient);
        feeRecipient = boundToValidAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        vm.assume(recipient != campaign); // Avoid self-transfers
        vm.assume(feeRecipient != campaign); // Avoid campaign as fee recipient
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        // Create fee with zero amount
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, 0, "zero_fee");
        bytes memory hookData = buildSendHookData(payouts, fees, true);

        uint256 initialFeeRecipientBalance = mockToken.balanceOf(feeRecipient);

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);

        // Zero fee should be skipped - no balance change or allocation
        assertEq(mockToken.balanceOf(feeRecipient), initialFeeRecipientBalance);
        assertEq(flywheel.allocatedFee(campaign, address(mockToken), feeKey), 0);
    }

    /// @dev Verifies that send handles multiple fees in a single call
    /// @param recipient Recipient address
    /// @param amount Payout amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_handlesMultipleFees(address recipient, uint256 amount, uint256 feeBp, address feeRecipient) public {
        recipient = boundToValidAddress(recipient);
        feeRecipient = boundToValidAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        vm.assume(recipient != campaign); // Avoid self-transfers
        vm.assume(feeRecipient != campaign); // Avoid campaign as fee recipient
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        address feeRecipient2 = makeAddr("feeRecipient2");

        // Prevent overflow when calculating total funding
        uint256 totalFees = feeAmount * 2;
        vm.assume(totalFees >= feeAmount); // Check for overflow
        uint256 totalFunding = amount + totalFees;
        vm.assume(totalFunding >= amount); // Check for overflow
        vm.assume(totalFunding <= MAX_FUZZ_AMOUNT); // Stay within limits

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");

        // Create multiple fees
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](2);
        fees[0] = Flywheel.Distribution({
            recipient: feeRecipient,
            key: bytes32(bytes20(feeRecipient)),
            amount: feeAmount,
            extraData: "fee1"
        });
        fees[1] = Flywheel.Distribution({
            recipient: feeRecipient2,
            key: bytes32(bytes20(feeRecipient2)),
            amount: feeAmount,
            extraData: "fee2"
        });

        bytes memory hookData = buildSendHookData(payouts, fees, true);

        uint256 initialBalance1 = mockToken.balanceOf(feeRecipient);
        uint256 initialBalance2 = mockToken.balanceOf(feeRecipient2);

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);

        // Both fees should be sent
        assertEq(mockToken.balanceOf(feeRecipient), initialBalance1 + feeAmount);
        assertEq(mockToken.balanceOf(feeRecipient2), initialBalance2 + feeAmount);
    }

    /// @dev Verifies that the PayoutSent event is emitted for each payout
    /// @param recipient Recipient address
    /// @param amount Payout amount
    function test_emitsPayoutSentEvent(address recipient, uint256 amount) public {
        recipient = boundToValidAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "test_data");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        vm.expectEmit(true, true, true, true);
        emit Flywheel.PayoutSent(campaign, address(mockToken), recipient, amount, "test_data");

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);
    }

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
    ) public {
        recipient = boundToValidAddress(recipient);
        feeRecipient = boundToValidAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        // Skip test if fee amount is zero (no event will be emitted)
        vm.assume(feeAmount > 0);
        uint256 totalFunding = amount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee_data");
        bytes memory hookData = buildSendHookData(payouts, fees, true);

        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeeSent(campaign, address(mockToken), feeRecipient, feeAmount, "fee_data");

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);
    }

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
    ) public {
        recipient = boundToValidAddress(recipient);
        // Use zero address for fee recipient to force transfer failure
        feeRecipient = address(0);
        vm.assume(recipient != feeRecipient);
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        // Skip test if fee amount is zero (no event will be emitted)
        vm.assume(feeAmount > 0);

        activateCampaign(campaign, manager);
        // Fund exactly the fee amount - this satisfies solvency but fee send will still fail
        // due to a deliberate setup to make the fee transfer fail
        fundCampaign(campaign, feeAmount, address(this));

        // Empty payouts array to avoid payout failures - we only want to test fee failure
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](0);
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee_data");
        bytes memory hookData = buildSendHookData(payouts, fees, true); // Try immediate fee send which will fail

        // Expect both FeeTransferFailed and FeeAllocated events when immediate fee send fails
        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeeTransferFailed(campaign, address(mockToken), feeKey, feeRecipient, feeAmount, "fee_data");
        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeeAllocated(campaign, address(mockToken), feeKey, feeAmount, "fee_data");

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);
    }

    /// @dev Verifies that the FeeAllocated event is emitted when immediate fee send fails
    /// @param amount Payout amount
    /// @param recipient Recipient address
    /// @param feeBp Fee basis points
    function test_emitsFeeAllocatedEvent_ifFeeSendFails_send(uint256 amount, address recipient, uint256 feeBp) public {
        recipient = boundToValidAddress(recipient);
        // Use zero address for fee recipient to force transfer failure
        address feeRecipient = address(0);
        vm.assume(recipient != feeRecipient);
        // Use zero address for fee recipient to force transfer failure
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        // Skip test if fee amount is zero (no event will be emitted)
        vm.assume(feeAmount > 0);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, feeAmount, address(this));

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](0);
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee_data");
        bytes memory hookData = buildSendHookData(payouts, fees, true);

        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeeAllocated(campaign, address(mockToken), feeKey, feeAmount, "fee_data");

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);
    }

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
    ) public {
        recipient = boundToValidAddress(recipient);
        feeRecipient = boundToValidAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        // Skip test if fee amount is zero (no event will be emitted)
        vm.assume(feeAmount > 0);

        uint256 totalFunding = amount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee_data");
        bytes memory hookData = buildSendHookData(payouts, fees, false); // Deferred fees

        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeeAllocated(campaign, address(mockToken), feeKey, feeAmount, "fee_data");

        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), hookData);
    }
}

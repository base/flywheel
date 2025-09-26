// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../src/Flywheel.sol";
import {Constants} from "../../../src/Constants.sol";
import {FlywheelTest} from "../../lib/FlywheelTestBase.sol";
import {RevertingReceiver} from "../../lib/mocks/RevertingReceiver.sol";
import {FailingERC20} from "../../lib/mocks/FailingERC20.sol";

/// @title DistributeTest
/// @notice Tests for Flywheel.distribute
contract DistributeTest is FlywheelTest {
    address public campaign;

    function setUp() public {
        setUpFlywheelBase();
        campaign = createSimpleCampaign(owner, manager, "Test Campaign", 1);
    }

    /// @dev Expects CampaignDoesNotExist
    /// @dev Reverts when campaign does not exist
    /// @param token ERC20 token address under test
    /// @param hookData Raw hook data
    /// @param unknownCampaign Non-existent campaign address
    function test_reverts_whenCampaignDoesNotExist(address token, bytes memory hookData, address unknownCampaign)
        public
    {
        vm.assume(unknownCampaign != campaign);

        vm.expectRevert(Flywheel.CampaignDoesNotExist.selector);
        flywheel.distribute(unknownCampaign, token, hookData);
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
        flywheel.distribute(campaign, token, hookData);
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
        flywheel.distribute(campaign, token, hookData);
    }

    /// @dev Expects SendFailed
    /// @dev Reverts when token transfer fails with an ERC20 token
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    function test_reverts_whenSendFailed_ERC20(uint256 allocateAmount, uint256 distributeAmount) public {
        // Use a failing ERC20 token that will cause transfers to fail
        FailingERC20 failingToken = new FailingERC20();
        address recipient = makeAddr("recipient");
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        // Fund campaign with the failing token
        failingToken.mint(campaign, allocateAmount);

        // First allocate the funds so the allocation exists
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        vm.prank(manager);
        flywheel.allocate(campaign, address(failingToken), abi.encode(allocatedPayouts));

        // Try to distribute - allocation exists and campaign has tokens, but transfer will fail
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        vm.expectRevert(
            abi.encodeWithSelector(Flywheel.SendFailed.selector, address(failingToken), recipient, distributeAmount)
        );
        vm.prank(manager);
        flywheel.distribute(campaign, address(failingToken), hookData);
    }

    /// @dev Expects SendFailed
    /// @dev Reverts when token transfer fails with native token
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    function test_reverts_whenSendFailed_nativeToken(uint256 allocateAmount, uint256 distributeAmount) public {
        // Create a contract that will reject native token transfers by reverting in its receive function
        RevertingReceiver revertingRecipient = new RevertingReceiver();
        address recipient = address(revertingRecipient);
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        // Fund campaign with native token
        vm.deal(campaign, allocateAmount);

        // First allocate the funds so the allocation exists
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        managerAllocate(campaign, Constants.NATIVE_TOKEN, allocatedPayouts);

        // Try to distribute - allocation exists and campaign has funds, but recipient will reject transfer
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        vm.expectRevert(
            abi.encodeWithSelector(Flywheel.SendFailed.selector, Constants.NATIVE_TOKEN, recipient, distributeAmount)
        );
        vm.prank(manager);
        flywheel.distribute(campaign, Constants.NATIVE_TOKEN, hookData);
    }

    /// @dev Expects InsufficientCampaignFunds
    /// @dev Reverts when campaign is not solvent
    /// @param recipient Recipient address
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    function test_reverts_ifCampaignIsNotSolvent(address recipient, uint256 allocateAmount, uint256 distributeAmount)
        public
    {
        recipient = boundToValidPayableAddress(recipient);
        vm.assume(recipient != campaign); // Ensure recipient is not the campaign itself
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);
        address feeRecipient = makeAddr("feeRecipient");

        activateCampaign(campaign, manager);

        // Fund campaign with exact amount for allocation
        fundCampaign(campaign, allocateAmount, address(this));

        // Allocate all funds to recipient
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Try to distribute with additional fees that would make campaign insolvent
        // Campaign has 'allocateAmount' tokens, allocated to recipient
        // After distributing 'distributeAmount', adding deferred fees will increase totalAllocatedFees
        // making final solvency check fail: 0 < totalAllocatedFees
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        uint256 feeAmount = 1; // Any fee will make it insolvent since balance will be 0 after distribution
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee");
        bytes memory hookData = buildSendHookData(payouts, fees, false); // Deferred fees

        vm.expectRevert(Flywheel.InsufficientCampaignFunds.selector);
        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);
    }

    /// @dev Verifies that distribute calls are allowed when campaign is ACTIVE
    /// @param recipient Recipient address
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    function test_succeeds_whenCampaignActive(address recipient, uint256 allocateAmount, uint256 distributeAmount)
        public
    {
        recipient = boundToValidPayableAddress(recipient);
        vm.assume(recipient != campaign); // Avoid self-transfers which don't change balance
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.ACTIVE));
        fundCampaign(campaign, allocateAmount, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);

        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance + distributeAmount);
        // Allocation should be consumed after distribution
        assertEq(
            flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))),
            allocateAmount - distributeAmount
        );
    }

    /// @dev Verifies that distribute remains allowed when campaign is FINALIZING
    /// @param recipient Recipient address
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    function test_succeeds_whenCampaignFinalizing(address recipient, uint256 allocateAmount, uint256 distributeAmount)
        public
    {
        recipient = boundToValidPayableAddress(recipient);
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, allocateAmount, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Move to FINALIZING state
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        assertEq(uint256(flywheel.campaignStatus(campaign)), uint256(Flywheel.CampaignStatus.FINALIZING));

        // Now distribute
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);

        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance + distributeAmount);
    }

    /// @dev Verifies that distribute calls work with an ERC20 token
    /// @param recipient Recipient address
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    function test_succeeds_withERC20Token(address recipient, uint256 allocateAmount, uint256 distributeAmount) public {
        recipient = boundToValidPayableAddress(recipient);
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, allocateAmount, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);

        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance + distributeAmount);
    }

    /// @dev Verifies that distribute calls work with native token
    /// @param recipient Recipient address
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    function test_succeeds_withNativeToken(address recipient, uint256 allocateAmount, uint256 distributeAmount)
        public
    {
        // Use a simple, clean address to avoid any edge cases
        recipient = boundToValidPayableAddress(recipient);
        vm.assume(recipient != campaign); // Avoid self-transfers
        vm.assume(recipient != address(vm)); // Avoid VM precompile that rejects ETH
        vm.assume(recipient != address(0)); // Avoid zero address
        vm.assume(uint160(recipient) > 1000); // Avoid precompile addresses and low addresses
        vm.assume(recipient.code.length == 0); // Only EOAs to avoid contracts that might revert
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        // Fund campaign with native token
        vm.deal(campaign, allocateAmount);

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        managerAllocate(campaign, Constants.NATIVE_TOKEN, allocatedPayouts);

        // Now distribute
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialRecipientBalance = recipient.balance;

        vm.prank(manager);
        flywheel.distribute(campaign, Constants.NATIVE_TOKEN, hookData);

        assertEq(recipient.balance, initialRecipientBalance + distributeAmount);
    }

    /// @dev Verifies that distribute calls work with fees
    /// @param recipient Recipient address
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_succeeds_withDeferredFees(
        address recipient,
        uint256 allocateAmount,
        uint256 distributeAmount,
        uint256 feeBp,
        address feeRecipient
    ) public {
        recipient = boundToValidPayableAddress(recipient);
        feeRecipient = boundToValidPayableAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(distributeAmount, feeBpBounded);
        uint256 totalFunding = allocateAmount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute with deferred fees
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee");
        bytes memory hookData = buildSendHookData(payouts, fees, false); // Deferred fees

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);
        uint256 initialFeeRecipientBalance = mockToken.balanceOf(feeRecipient);

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);

        // Payout should be distributed
        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance + distributeAmount);
        // Fee should NOT be sent (deferred), but allocated
        assertEq(mockToken.balanceOf(feeRecipient), initialFeeRecipientBalance);
        assertEq(flywheel.allocatedFee(campaign, address(mockToken), feeKey), feeAmount);
    }

    /// @dev Verifies that distribute calls work with immediate fees
    /// @param recipient Recipient address
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_succeeds_withImmediateFees(
        address recipient,
        uint256 allocateAmount,
        uint256 distributeAmount,
        uint256 feeBp,
        address feeRecipient
    ) public {
        recipient = boundToValidPayableAddress(recipient);
        feeRecipient = boundToValidPayableAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        vm.assume(recipient != campaign); // Avoid self-transfers
        vm.assume(feeRecipient != campaign); // Avoid campaign as fee recipient
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(distributeAmount, feeBpBounded);
        uint256 totalFunding = allocateAmount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute with immediate fees
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee");
        bytes memory hookData = buildSendHookData(payouts, fees, true); // Immediate fees

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);
        uint256 initialFeeRecipientBalance = mockToken.balanceOf(feeRecipient);

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);

        // Payout should be distributed
        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance + distributeAmount);
        // Fee should be sent immediately
        assertEq(mockToken.balanceOf(feeRecipient), initialFeeRecipientBalance + feeAmount);
        // No allocated fees since they were sent immediately
        assertEq(flywheel.allocatedFee(campaign, address(mockToken), feeKey), 0);
    }

    /// @dev Verifies that distribute updates allocated fees on fee send failure
    /// @param recipient Recipient address
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_updatesAllocatedFees_onFeeSendFailure(
        address recipient,
        uint256 allocateAmount,
        uint256 distributeAmount,
        uint256 feeBp,
        address feeRecipient
    ) public {
        recipient = boundToValidPayableAddress(recipient);
        vm.assume(recipient != campaign); // Avoid self-transfers
        // Force fee recipient to be address(0) to make fee transfer fail
        feeRecipient = address(0);
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(distributeAmount, feeBpBounded);
        // Skip test if fee amount is zero (no allocation will occur)
        vm.assume(feeAmount > 0);
        uint256 totalFunding = allocateAmount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute with immediate fees that will fail
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee");
        bytes memory hookData = buildSendHookData(payouts, fees, true); // Try immediate fees

        uint256 initialFeeRecipientBalance = mockToken.balanceOf(feeRecipient);

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);

        // Fee should NOT be sent (transfer to address(0) fails)
        assertEq(mockToken.balanceOf(feeRecipient), initialFeeRecipientBalance);
        // Fee should be allocated instead when send fails
        assertEq(flywheel.allocatedFee(campaign, address(mockToken), feeKey), feeAmount);
    }

    /// @dev Verifies that distribute skips fees of zero amount
    /// @param recipient Recipient address
    /// @param allocateAmount Allocation amount
    /// @param distributeAmount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_skipsFeesOfZeroAmount(
        address recipient,
        uint256 allocateAmount,
        uint256 distributeAmount,
        uint256 feeBp,
        address feeRecipient
    ) public {
        recipient = boundToValidPayableAddress(recipient);
        feeRecipient = boundToValidPayableAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        vm.assume(recipient != campaign); // Avoid self-transfers
        vm.assume(feeRecipient != campaign); // Avoid campaign as fee recipient
        allocateAmount = boundToValidAmount(allocateAmount);
        distributeAmount = boundToValidAmount(distributeAmount);
        vm.assume(distributeAmount <= allocateAmount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, allocateAmount, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, allocateAmount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute with zero fees
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, distributeAmount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        // Create fee with zero amount
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, 0, "zero_fee");
        bytes memory hookData = buildSendHookData(payouts, fees, true);

        uint256 initialFeeRecipientBalance = mockToken.balanceOf(feeRecipient);

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);

        // Zero fee should be skipped - no balance change or allocation
        assertEq(mockToken.balanceOf(feeRecipient), initialFeeRecipientBalance);
        assertEq(flywheel.allocatedFee(campaign, address(mockToken), feeKey), 0);
    }

    /// @dev Verifies that distribute handles multiple fees
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_handlesMultipleFees(address recipient, uint256 amount, uint256 feeBp, address feeRecipient) public {
        recipient = boundToValidPayableAddress(recipient);
        feeRecipient = boundToValidPayableAddress(feeRecipient);
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

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, amount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute with multiple fees
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
        flywheel.distribute(campaign, address(mockToken), hookData);

        // Both fees should be sent
        assertEq(mockToken.balanceOf(feeRecipient), initialBalance1 + feeAmount);
        assertEq(mockToken.balanceOf(feeRecipient2), initialBalance2 + feeAmount);
    }

    /// @notice Ignores zero-amount distributions (no-op)
    /// @dev Verifies totals unchanged and no event for zero amounts using the deployed token
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_ignoresZeroAmountDistributions(address recipient, uint256 amount) public {
        recipient = boundToValidPayableAddress(recipient);
        amount = boundToValidAmount(amount); // Fund with some amount, but distribute 0

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        // First allocate some funds (but we'll distribute zero)
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, amount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute zero amount
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, 0, "");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialRecipientBalance = mockToken.balanceOf(recipient);
        uint256 initialAllocatedAmount =
            flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient)));

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);

        // Zero amount should not change recipient balance or allocations
        assertEq(mockToken.balanceOf(recipient), initialRecipientBalance);
        assertEq(
            flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient))), initialAllocatedAmount
        );
    }

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
    ) public {
        recipient1 = boundToValidPayableAddress(recipient1);
        recipient2 = boundToValidPayableAddress(recipient2);
        vm.assume(recipient1 != recipient2);
        vm.assume(recipient1 != campaign); // Avoid self-transfers
        vm.assume(recipient2 != campaign); // Avoid self-transfers

        (amount1, amount2) = boundToValidMultiAmounts(amount1, amount2);
        uint256 totalAmount = amount1 + amount2;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalAmount, address(this));

        // First allocate funds to both recipients
        Flywheel.Payout[] memory allocatedPayouts = new Flywheel.Payout[](2);
        allocatedPayouts[0] = Flywheel.Payout({recipient: recipient1, amount: amount1, extraData: "payout1"});
        allocatedPayouts[1] = Flywheel.Payout({recipient: recipient2, amount: amount2, extraData: "payout2"});
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute to both
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](2);
        payouts[0] = Flywheel.Payout({recipient: recipient1, amount: amount1, extraData: "payout1"});
        payouts[1] = Flywheel.Payout({recipient: recipient2, amount: amount2, extraData: "payout2"});

        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        uint256 initialBalance1 = mockToken.balanceOf(recipient1);
        uint256 initialBalance2 = mockToken.balanceOf(recipient2);

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);

        assertEq(mockToken.balanceOf(recipient1), initialBalance1 + amount1);
        assertEq(mockToken.balanceOf(recipient2), initialBalance2 + amount2);
        // Allocations should be consumed
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient1))), 0);
        assertEq(flywheel.allocatedPayout(campaign, address(mockToken), bytes32(bytes20(recipient2))), 0);
    }

    /// @dev Verifies that the PayoutsDistributed event is emitted for each distribution
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    function test_emitsPayoutsDistributedEvent(address recipient, uint256 amount) public {
        recipient = boundToValidPayableAddress(recipient);
        amount = boundToValidAmount(amount);

        activateCampaign(campaign, manager);
        fundCampaign(campaign, amount, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, amount, "test_data");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "test_data");
        Flywheel.Distribution[] memory fees = new Flywheel.Distribution[](0);
        bytes memory hookData = buildSendHookData(payouts, fees, false);

        vm.expectEmit(true, true, true, true);
        emit Flywheel.PayoutsDistributed(
            campaign, address(mockToken), bytes32(bytes20(recipient)), recipient, amount, "test_data"
        );

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);
    }

    /// @dev Verifies that the FeeSent event is emitted on successful immediate fee send
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_emitsFeeSentEvent_ifFeeSendSucceeds(
        address recipient,
        uint256 amount,
        uint256 feeBp,
        address feeRecipient
    ) public {
        recipient = boundToValidPayableAddress(recipient);
        feeRecipient = boundToValidPayableAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        // Skip test if fee amount is zero (no event will be emitted)
        vm.assume(feeAmount > 0);
        uint256 totalFunding = amount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, amount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute with immediate fees
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee_data");
        bytes memory hookData = buildSendHookData(payouts, fees, true);

        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeeSent(campaign, address(mockToken), feeRecipient, feeAmount, "fee_data");

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);
    }

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
    ) public {
        recipient = boundToValidPayableAddress(recipient);
        // Use zero address for fee recipient to force transfer failure
        feeRecipient = address(0);
        vm.assume(recipient != feeRecipient);
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        // Skip test if fee amount is zero (no event will be emitted)
        vm.assume(feeAmount > 0);
        uint256 totalFunding = amount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, amount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute with immediate fees that will fail
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee_data");
        bytes memory hookData = buildSendHookData(payouts, fees, true); // Try immediate fee send which will fail

        // Expect both FeeTransferFailed and FeeAllocated events when immediate fee send fails
        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeeTransferFailed(campaign, address(mockToken), feeKey, feeRecipient, feeAmount, "fee_data");
        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeeAllocated(campaign, address(mockToken), feeKey, feeAmount, "fee_data");

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);
    }

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
    ) public {
        recipient = boundToValidPayableAddress(recipient);
        // Use zero address for fee recipient to force transfer failure
        feeRecipient = address(0);
        vm.assume(recipient != feeRecipient);
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        // Skip test if fee amount is zero (no event will be emitted)
        vm.assume(feeAmount > 0);
        uint256 totalFunding = amount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, amount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute with immediate fees that will fail and be allocated
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee_data");
        bytes memory hookData = buildSendHookData(payouts, fees, true);

        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeeAllocated(campaign, address(mockToken), feeKey, feeAmount, "fee_data");

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);
    }

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
    ) public {
        recipient = boundToValidPayableAddress(recipient);
        feeRecipient = boundToValidPayableAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        // Skip test if fee amount is zero (no event will be emitted)
        vm.assume(feeAmount > 0);
        uint256 totalFunding = amount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        // First allocate the funds
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, amount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        // Now distribute with deferred fees
        Flywheel.Payout[] memory payouts = buildSinglePayout(recipient, amount, "");
        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        Flywheel.Distribution[] memory fees = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee_data");
        bytes memory hookData = buildSendHookData(payouts, fees, false); // Deferred fees

        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeeAllocated(campaign, address(mockToken), feeKey, feeAmount, "fee_data");

        vm.prank(manager);
        flywheel.distribute(campaign, address(mockToken), hookData);
    }

    /// @dev Verifies that the FeesDistributed event is emitted for each fee distribution
    /// @param recipient Recipient address
    /// @param amount Distribution amount
    /// @param feeBp Fee basis points
    /// @param feeRecipient Fee recipient address
    function test_emitsFeesDistributedEvent(address recipient, uint256 amount, uint256 feeBp, address feeRecipient)
        public
    {
        recipient = boundToValidPayableAddress(recipient);
        feeRecipient = boundToValidPayableAddress(feeRecipient);
        vm.assume(recipient != feeRecipient);
        amount = boundToValidAmount(amount);
        uint16 feeBpBounded = boundToValidFeeBp(feeBp);

        uint256 feeAmount = calculateFeeAmount(amount, feeBpBounded);
        // Skip test if fee amount is zero (no event will be emitted)
        vm.assume(feeAmount > 0);
        uint256 totalFunding = amount + feeAmount;

        activateCampaign(campaign, manager);
        fundCampaign(campaign, totalFunding, address(this));

        // First allocate both payout and fee
        Flywheel.Payout[] memory allocatedPayouts = buildSinglePayout(recipient, amount, "");
        managerAllocate(campaign, address(mockToken), allocatedPayouts);

        bytes32 feeKey = bytes32(bytes20(feeRecipient));
        // Allocate fee manually using distributeFees approach
        Flywheel.Distribution[] memory feeAllocations = buildSingleFee(feeRecipient, feeKey, feeAmount, "fee_data");
        vm.prank(manager);
        flywheel.send(campaign, address(mockToken), abi.encode(new Flywheel.Payout[](0), feeAllocations, false));

        // Now use distributeFees to emit FeesDistributed event
        vm.expectEmit(true, true, true, true);
        emit Flywheel.FeesDistributed(campaign, address(mockToken), feeKey, feeRecipient, feeAmount, "fee_data");

        vm.prank(manager);
        flywheel.distributeFees(campaign, address(mockToken), abi.encode(feeAllocations));
    }
}

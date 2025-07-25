pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";
import {Flywheel} from "./Flywheel.sol";
import {SimpleRewards} from "./hooks/SimpleRewards.sol";

contract CashbackOperator is Ownable {
    uint256 public constant MAX_CASHBACK_BPS = 10000;

    /// @notice Cashback percentage in basis points
    uint256 public cashbackBps;
    AuthCaptureEscrow public escrow;
    Flywheel public flywheel;
    SimpleRewards public rewardsHook;

    address public cashbackCampaign;

    /// @notice Tracks the refunded amount for each payment
    mapping(bytes32 paymentInfoHash => uint256 amountRefunded) public amountRefunded;

    /// @notice Tracks allocated cashback amount per payment
    mapping(bytes32 paymentInfoHash => uint256 allocatedAmount) public paymentAllocations;

    /// @notice Thrown when the caller is not the owner
    error OnlyOwner();

    /// @notice Thrown when the cashback percentage is invalid
    error InvalidCashbackBps();

    /// @notice Thrown when payment was not reclaimed
    error PaymentNotReclaimed();

    constructor(uint256 _cashbackBps, address _escrow, address _flywheel, address _rewardsHook, address _owner)
        Ownable(_owner)
    {
        if (_cashbackBps > MAX_CASHBACK_BPS) revert InvalidCashbackBps();
        cashbackBps = _cashbackBps;

        // TODO: checks for invalid addresses
        escrow = AuthCaptureEscrow(_escrow);
        flywheel = Flywheel(_flywheel);
        rewardsHook = SimpleRewards(_rewardsHook);

        // Create campaign with SimpleRewards hook
        bytes memory hookData = abi.encode(address(this)); // CashbackOperator is the manager

        cashbackCampaign = flywheel.createCampaign(
            address(rewardsHook),
            uint256(keccak256(abi.encode(address(this), block.timestamp))), // TODO what might make a better nonce?
            hookData
        );
        flywheel.updateStatus(cashbackCampaign, Flywheel.CampaignStatus.ACTIVE, "");
    }

    /// TODO: this is just a hack for initial PoC and tests to get around the fact that the refund collector needs to be able to spend
    /// the operator's tokens. The correct fix is a new refund token collector that can source liquidity from a different address.
    ///
    /// @notice Approves a token to be spent by a spender (e.g., refund collectors)
    /// @dev Only callable by owner for security
    /// @param token The token to approve
    /// @param spender The address to approve for spending
    /// @param amount The amount to approve (use type(uint256).max for unlimited)
    function approveToken(address token, address spender, uint256 amount) external onlyOwner {
        IERC20(token).approve(spender, amount);
    }

    /// @notice Transfers funds from payer to receiver in one step and rewards cashback to payer
    /// @dev If amount is less than the authorized amount, only amount is taken from payer
    /// @dev Reverts if the authorization has been voided or expired
    /// @param paymentInfo PaymentInfo struct
    /// @param amount Amount to charge and capture
    /// @param tokenCollector Address of the token collector
    /// @param collectorData Data to pass to the token collector
    /// @param feeBps Fee percentage to apply (must be within min/max range)
    /// @param feeReceiver Address to receive fees (should match the paymentInfo.feeReceiver unless that is 0 in which case it can be any address)
    function charge(
        AuthCaptureEscrow.PaymentInfo calldata paymentInfo,
        uint256 amount,
        address tokenCollector,
        bytes calldata collectorData,
        uint16 feeBps,
        address feeReceiver
    ) external {
        escrow.charge(paymentInfo, amount, tokenCollector, collectorData, feeBps, feeReceiver);
        _rewardCashback(paymentInfo, amount);
    }

    /// @notice Transfers funds from payer to escrow and allocates cashback reward for payer in flywheel
    /// @param paymentInfo PaymentInfo struct
    /// @param amount Amount to authorize
    /// @param tokenCollector Address of the token collector
    /// @param collectorData Data to pass to the token collector
    function authorize(
        AuthCaptureEscrow.PaymentInfo calldata paymentInfo,
        uint256 amount,
        address tokenCollector,
        bytes calldata collectorData
    ) external {
        // authorize payment in AuthCaptureEscrow
        escrow.authorize(paymentInfo, amount, tokenCollector, collectorData);
        _allocateCashback(paymentInfo, amount);
    }

    /// @notice Transfers previously-escrowed funds to receiver and distributes cashback to payer
    /// @dev Can be called multiple times up to cumulative authorized amount
    /// @dev Can only be called by the operator
    /// @param paymentInfo PaymentInfo struct
    /// @param amount Amount to capture
    /// @param feeBps Fee percentage to apply (must be within min/max range)
    /// @param feeReceiver Address to receive fees (should match the paymentInfo.feeReceiver unless that is 0 in which case it can be any address)
    function capture(
        AuthCaptureEscrow.PaymentInfo calldata paymentInfo,
        uint256 amount,
        uint16 feeBps,
        address feeReceiver
    ) external {
        escrow.capture(paymentInfo, amount, feeBps, feeReceiver);
        _distributeCashback(paymentInfo, amount);
    }

    /// @notice Permanently voids a payment authorization
    /// @dev Returns any escrowed funds to payer
    /// @dev Can only be called by the operator
    /// @param paymentInfo PaymentInfo struct
    function void(AuthCaptureEscrow.PaymentInfo calldata paymentInfo) external {
        (bytes32 paymentHash, AuthCaptureEscrow.PaymentState memory paymentState) = _getPaymentState(paymentInfo);
        escrow.void(paymentInfo);
        // deallocate whatever had been allocated
        _deallocateCashback(paymentInfo, paymentState.capturableAmount);
    }

    /// @notice Cleans up orphaned allocation after a payment was reclaimed directly from AuthCaptureEscrow
    /// @dev Can be called by anyone to clean up orphaned allocations
    /// @param paymentInfo PaymentInfo struct for the reclaimed payment
    function cleanupOrphanedAllocation(AuthCaptureEscrow.PaymentInfo calldata paymentInfo) external {
        (bytes32 paymentHash, AuthCaptureEscrow.PaymentState memory paymentState) = _getPaymentState(paymentInfo);

        // Verify payment was actually reclaimed (capturable amount is 0)
        if (paymentState.capturableAmount > 0) {
            revert PaymentNotReclaimed();
        }

        // Get the amount that was originally allocated for this payment
        uint256 allocatedAmount = paymentAllocations[paymentHash];

        // Voided and captured payments should have no allocation if there is no capturable amount, so only proceed if there's an allocated amount
        if (allocatedAmount > 0) {
            // Deallocate the exact amount that was allocated for this payment
            Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
            payouts[0] = Flywheel.Payout({recipient: paymentInfo.payer, amount: allocatedAmount});

            bytes memory hookData = abi.encode(payouts);
            flywheel.deallocate(cashbackCampaign, paymentInfo.token, hookData);

            // Clear the allocation tracking
            delete paymentAllocations[paymentHash];
        }
    }

    /// @notice Return previously-captured tokens to payer, minus the original cashback amount
    /// @dev Can be called by operator
    /// @dev Funds are transferred from the caller or from the escrow if token collector retrieves external liquidity
    /// @param paymentInfo PaymentInfo struct
    /// @param amount Amount to refund
    /// @param tokenCollector Address of the token collector
    /// @param collectorData Data to pass to the token collector
    function refund(
        AuthCaptureEscrow.PaymentInfo calldata paymentInfo,
        uint256 amount,
        address tokenCollector,
        bytes calldata collectorData
    ) external {
        // compute the amount of the refund that was cashback in the first place
        uint256 originalCashbackAmount = (amount * cashbackBps) / MAX_CASHBACK_BPS;
        // deduct the cashback amount from the amount refunded
        amount -= originalCashbackAmount;
        escrow.refund(paymentInfo, amount, tokenCollector, collectorData);
        // Shouldn't be anything to allocate or distribute here
        // TODO: EVENTS
    }

    /// @notice Gets the payment state for a payment
    /// @param paymentInfo Payment info
    /// @return paymentInfoHash Hash of the payment info
    /// @return paymentState Payment state
    function _getPaymentState(AuthCaptureEscrow.PaymentInfo calldata paymentInfo)
        internal
        view
        returns (bytes32 paymentInfoHash, AuthCaptureEscrow.PaymentState memory paymentState)
    {
        paymentInfoHash = escrow.getHash(paymentInfo);
        (bool hasCollectedPayment, uint120 capturableAmount, uint120 refundableAmount) =
            escrow.paymentState(paymentInfoHash);
        paymentState = AuthCaptureEscrow.PaymentState(hasCollectedPayment, capturableAmount, refundableAmount);
    }

    /// @notice Rewards corresponding amount of cashback to payer immediately
    /// @param paymentInfo PaymentInfo struct
    /// @param amount Amount to reward
    function _rewardCashback(AuthCaptureEscrow.PaymentInfo calldata paymentInfo, uint256 amount) internal {
        uint256 cashbackAmount = (amount * cashbackBps) / MAX_CASHBACK_BPS;

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: paymentInfo.payer, amount: cashbackAmount});

        bytes memory hookData = abi.encode(payouts);
        flywheel.reward(cashbackCampaign, paymentInfo.token, hookData);
    }

    /// @notice Allocates corresponding amount of cashback to payer for later distribution
    /// @param paymentInfo PaymentInfo struct
    /// @param amount Amount to allocate
    function _allocateCashback(AuthCaptureEscrow.PaymentInfo calldata paymentInfo, uint256 amount) internal {
        uint256 cashbackAmount = (amount * cashbackBps) / MAX_CASHBACK_BPS;
        bytes32 paymentHash = escrow.getHash(paymentInfo);

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: paymentInfo.payer, amount: cashbackAmount});

        bytes memory hookData = abi.encode(payouts);
        flywheel.allocate(cashbackCampaign, paymentInfo.token, hookData);

        // Track allocation per payment
        paymentAllocations[paymentHash] = cashbackAmount;
    }

    /// @notice Distributes corresponding amount of allocated cashback to payer
    /// @param paymentInfo PaymentInfo struct
    /// @param amount Amount to distribute
    function _distributeCashback(AuthCaptureEscrow.PaymentInfo calldata paymentInfo, uint256 amount) internal {
        uint256 cashbackAmount = (amount * cashbackBps) / MAX_CASHBACK_BPS;
        bytes32 paymentHash = escrow.getHash(paymentInfo);

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: paymentInfo.payer, amount: cashbackAmount});

        bytes memory hookData = abi.encode(payouts);
        flywheel.distribute(cashbackCampaign, paymentInfo.token, hookData);
        paymentAllocations[paymentHash] -= cashbackAmount;
    }

    /// @notice Deallocates corresponding amount of allocated cashback from payer
    /// @param paymentInfo PaymentInfo struct
    /// @param amount Amount to deallocate
    function _deallocateCashback(AuthCaptureEscrow.PaymentInfo calldata paymentInfo, uint256 amount) internal {
        uint256 cashbackAmount = (amount * cashbackBps) / MAX_CASHBACK_BPS;
        bytes32 paymentHash = escrow.getHash(paymentInfo);

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: paymentInfo.payer, amount: cashbackAmount});

        bytes memory hookData = abi.encode(payouts);
        flywheel.deallocate(cashbackCampaign, paymentInfo.token, hookData);

        // Clear allocation tracking since it's now deallocated
        // TODO: should this just be deleted? (does it always go to zero in the only case where it's called?)
        paymentAllocations[paymentHash] -= cashbackAmount;
    }
}

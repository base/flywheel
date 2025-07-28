// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

/**
 * Questions:
 * - Do we enforce that rewards for a given payment can never total to more than the payment's captured amount?
 * The tradeoff here is between whether other rewarders can preclude a desired rewarder to reward by taking up 100% of the payment's captured amount.
 * v.s. we let anyone award any amount, but means there may not be enough refund liquidity to properly refund everyone proportionally.
 * (this is the current behavior as written)
 */

/// @title CashbackRewards
///
/// @notice Campaign Hooks for cashback rewards controlled by a campaign manager
///
/// @author Coinbase
contract CashbackRewards is CampaignHooks {
    /// @notice Tracks rewards info per payment per campaign
    struct RewardsInfo {
        uint128 allocated;
        uint128 distributed;
    }

    /// @notice Thrown when the sender is not the manager of the campaign
    error Unauthorized();

    /// @notice Thrown when the allocated amount is less than the amount being deallocated or distributed
    error InsufficientAllocatedAmount(uint256 amount, uint256 allocated);

    /// @notice Emitted when cashback is allocated for a payment
    event CashbackAllocated(bytes32 paymentHash, address campaign, address token, uint256 amount);

    /// @notice Emitted when cashback is deallocated for a payment
    event CashbackDeallocated(bytes32 paymentHash, address campaign, address token, uint256 amount);

    /// @notice Emitted when cashback is distributed for a payment
    event CashbackDistributed(bytes32 paymentHash, address campaign, address token, uint256 amount);

    /// @notice Emitted when cashback is rewarded for a payment
    event CashbackRewarded(bytes32 paymentHash, address campaign, address token, uint256 amount);

    /// @notice The escrow contract to track payment states and calculate payment hash
    AuthCaptureEscrow public immutable escrow;

    /// @notice Managers of the campaigns
    mapping(address campaign => address manager) public managers;

    /// @notice Tracks rewards info per payment per campaign
    mapping(bytes32 paymentHash => mapping(address campaign => RewardsInfo info)) public rewardsInfo;

    /// @notice Tracks which campaigns have contributed to each payment (for refund accounting)
    mapping(bytes32 paymentHash => address[] campaigns) public paymentContributors;

    /// @notice Constructor
    /// @param flywheel_ The Flywheel core protocol contract address
    /// @param escrow_ The AuthCaptureEscrow contract address
    constructor(address flywheel_, address escrow_) CampaignHooks(flywheel_) {
        escrow = escrow_;
    }

    /// @inheritdoc CampaignHooks
    function onCreateCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {
        managers[campaign] = abi.decode(hookData, (address));
    }

    /// @inheritdoc CampaignHooks
    function onUpdateStatus(
        address sender,
        address campaign,
        Flywheel.CampaignStatus oldStatus,
        Flywheel.CampaignStatus newStatus,
        bytes calldata hookData
    ) external override onlyFlywheel {
        _validateSender(sender, campaign);
    }

    /// @inheritdoc CampaignHooks
    /// @dev Tracks per-payment allocation of cashback rewards
    function onAllocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        _validateSender(sender, campaign);

        uint256 amount;
        AuthCaptureEscrow.PaymentInfo memory paymentInfo;
        (paymentInfo, amount) = abi.decode(hookData, (AuthCaptureEscrow.PaymentInfo, uint256));

        bytes32 paymentInfoHash = escrow.getHash(paymentInfo);

        rewardsInfo[paymentInfoHash][campaign].allocated += amount;

        Flywheel.Payout[] memory payouts = _createPayouts(paymentInfo, amount);
        emit CashbackAllocated(paymentInfoHash, campaign, token, amount);

        return (payouts, 0);
    }

    /// @inheritdoc CampaignHooks
    /// @dev Deallocates cashback rewards for a payment, enforcing per-payment liquidity constraints
    function onDeallocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts)
    {
        _validateSender(sender, campaign);

        uint256 amount;
        AuthCaptureEscrow.PaymentInfo memory paymentInfo;
        (paymentInfo, amount) = abi.decode(hookData, (AuthCaptureEscrow.PaymentInfo, uint256));

        bytes32 paymentInfoHash = escrow.getHash(paymentInfo);

        // Hook must enforce per-payment liquidity constraints
        if (rewardsInfo[paymentInfoHash][campaign].allocated < amount) {
            revert InsufficientAllocatedAmount(amount, rewardsInfo[paymentInfoHash][campaign].allocated);
        }
        rewardsInfo[paymentInfoHash][campaign].allocated -= amount;

        Flywheel.Payout[] memory payouts = _createPayouts(paymentInfo, amount);
        emit CashbackDeallocated(paymentInfoHash, campaign, token, amount);

        return (payouts, 0);
    }

    /// @inheritdoc CampaignHooks
    /// @dev Distributes cashback rewards for a payment, enforcing per-payment liquidity constraints
    function onDistribute(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        _validateSender(sender, campaign);

        uint256 amount;
        AuthCaptureEscrow.PaymentInfo memory paymentInfo;
        (paymentInfo, amount) = abi.decode(hookData, (AuthCaptureEscrow.PaymentInfo, uint256));

        bytes32 paymentInfoHash = escrow.getHash(paymentInfo);

        // Hook must enforce per-payment liquidity constraints
        if (rewardsInfo[paymentInfoHash][campaign].allocated < amount) {
            revert InsufficientAllocatedAmount(amount, rewardsInfo[paymentInfoHash][campaign].allocated);
        }

        _registerRewardContribution(paymentInfoHash, campaign, amount);

        Flywheel.Payout[] memory payouts = _createPayouts(paymentInfo, amount);
        emit CashbackDistributed(paymentInfoHash, campaign, token, amount);

        return (payouts, 0);
    }

    /// @inheritdoc CampaignHooks
    /// @dev Distributes cashback rewards for a payment without prior allocation (useful for one-shot rewards)
    function onReward(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        _validateSender(sender, campaign);

        uint256 amount;
        AuthCaptureEscrow.PaymentInfo memory paymentInfo;
        (paymentInfo, amount) = abi.decode(hookData, (AuthCaptureEscrow.PaymentInfo, uint256));

        bytes32 paymentInfoHash = escrow.getHash(paymentInfo);

        _registerRewardContribution(paymentInfoHash, campaign, amount);

        // Also track the amount as allocated? (useful if we want this counter to always reflect the total amount processed through this hook)
        rewardsInfo[paymentInfoHash][campaign].allocated += amount;

        Flywheel.Payout[] memory payouts = _createPayouts(paymentInfo, amount);

        emit CashbackRewarded(paymentInfoHash, campaign, amount);

        return (payouts, 0); // No fee charged
    }

    /// @inheritdoc CampaignHooks
    function onWithdrawFunds(address sender, address campaign, address token, uint256 amount, bytes calldata hookData)
        external
        override
        onlyFlywheel
    {
        _validateSender(sender, campaign);
    }

    /// @notice Get contribution details for a payment (useful for refund calculations)
    /// @param paymentInfoHash The hash of the payment info
    /// @return contributors Array of campaign addresses
    /// @return amounts Array of amounts contributed by each campaign (same index as contributors)
    function getPaymentContributionDetails(bytes32 paymentInfoHash)
        external
        view
        returns (address[] memory contributors, uint256[] memory amounts)
    {
        contributors = paymentContributors[paymentInfoHash];
        amounts = new uint256[](contributors.length);

        for (uint256 i = 0; i < contributors.length; i++) {
            amounts[i] = rewardsDistributed[paymentInfoHash][contributors[i]];
        }
    }

    /// @dev Tracks reward contribution for a payment
    /// @param paymentInfoHash Hash of the payment info
    /// @param campaign Campaign address
    /// @param amount Amount of cashback to reward
    function _registerRewardContribution(bytes32 paymentInfoHash, address campaign, uint256 amount) internal {
        // Track this campaign as a contributor if it's the first time
        if (rewardsInfo[paymentInfoHash][campaign].distributed == 0) {
            paymentContributors[paymentInfoHash].push(campaign);
        }

        AuthCaptureEscrow.PaymentState memory paymentState = escrow.paymentState(paymentInfoHash);
        uint256 netCaptured = paymentState.refundableAmount;
        uint256 alreadyRewarded = rewardsInfo[paymentInfoHash][campaign].distributed;

        // Enforce that the total amount rewarded will not exceed the net captured amount
        if (alreadyRewarded + amount > netCaptured) {
            revert ExceedsNetCaptured(amount, netCaptured - alreadyRewarded);
        }

        rewardsInfo[paymentInfoHash][campaign].distributed += amount;
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

    /// @notice Creates a Flywheel.Payout array for a given payment and amount
    /// @param paymentInfo Payment info
    /// @param amount Amount of cashback to reward
    /// @return payouts Payout
    function _createPayouts(AuthCaptureEscrow.PaymentInfo memory paymentInfo, uint256 amount)
        internal
        returns (Flywheel.Payout[] memory payouts)
    {
        Flywheel.Payout memory payout;
        payout.recipient = paymentInfo.payer;
        payout.amount = amount;
        payouts = new Flywheel.Payout[](1);
        payouts[0] = payout;
    }

    /// @notice Validates that the sender is the manager of the campaign
    /// @param sender Sender address
    /// @param campaign Campaign address
    function _validateSender(address sender, address campaign) internal {
        if (sender != managers[campaign]) revert Unauthorized();
    }
}

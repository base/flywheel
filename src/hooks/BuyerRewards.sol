// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";

/// @title BuyerRewards
///
/// @notice Reward buyers for their purchases made with the Commerce Payments Protocol (https://github.com/base/commerce-payments)
///
/// @dev Rewards can be made in any token (supports cashback, loyalty, etc.)
/// @dev Rewards can be made in any amount (supports %, fixed, etc.)
/// @dev Rewards can be made on any payment (supports custom filtering for platforms, wallets, merchants, etc.)
///
/// @author Coinbase
contract BuyerRewards is CampaignHooks {
    /// @notice Tracks rewards info per payment per campaign
    struct RewardsInfo {
        /// @dev Amount of reward allocated for this payment
        uint120 allocated;
        /// @dev Amount of reward distributed for this payment
        uint120 distributed;
    }

    /// @notice The escrow contract to track payment states and calculate payment hash
    AuthCaptureEscrow public immutable escrow;

    /// @notice Owners of the campaigns
    mapping(address campaign => address owner) public owners;

    /// @notice Managers of the campaigns
    mapping(address campaign => address manager) public managers;

    /// @notice Mapping of campaign addresses to their URI
    mapping(address campaign => string uri) public override campaignURI;

    /// @notice Tracks rewards info per payment per campaign
    mapping(bytes32 paymentHash => mapping(address campaign => RewardsInfo info)) public rewardsInfo;

    /// @notice Emitted when a campaign is created
    ///
    /// @param campaign Address of the campaign
    /// @param owner Address of the owner of the campaign
    /// @param manager Address of the manager of the campaign
    /// @param uri URI of the campaign
    event CampaignCreated(address indexed campaign, address owner, address manager, string uri);

    /// @notice Thrown when the sender is not the manager of the campaign
    error Unauthorized();

    /// @notice Thrown when the allocated amount is less than the amount being deallocated or distributed
    error InsufficientAllocation(uint120 amount, uint120 allocated);

    /// @notice Thrown when the payment amount is invalid
    error ZeroPayoutAmount();

    /// @notice Thrown when the token is invalid
    error InvalidToken();

    /// @notice Thrown when the payment has not been collected
    error PaymentNotCollected();

    /// @dev Modifier to check if the sender is the manager of the campaign
    ///
    /// @param sender Sender address
    /// @param campaign Campaign address
    modifier onlyManager(address sender, address campaign) {
        if (sender != managers[campaign]) revert Unauthorized();
        _;
    }

    /// @notice Constructor
    ///
    /// @param flywheel_ The Flywheel core protocol contract address
    /// @param escrow_ The AuthCaptureEscrow contract address
    constructor(address flywheel_, address escrow_) CampaignHooks(flywheel_) {
        escrow = AuthCaptureEscrow(escrow_);
    }

    /// @inheritdoc CampaignHooks
    function onCreateCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {
        (address owner, address manager, string memory uri) = abi.decode(hookData, (address, address, string));
        owners[campaign] = owner;
        managers[campaign] = manager;
        campaignURI[campaign] = uri;
        emit CampaignCreated(campaign, owner, manager, uri);
    }

    /// @inheritdoc CampaignHooks
    function onUpdateMetadata(address sender, address campaign, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
    {}

    /// @inheritdoc CampaignHooks
    function onUpdateStatus(
        address sender,
        address campaign,
        Flywheel.CampaignStatus oldStatus,
        Flywheel.CampaignStatus newStatus,
        bytes calldata hookData
    ) external override onlyFlywheel onlyManager(sender, campaign) {}

    /// @inheritdoc CampaignHooks
    function onReward(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        (AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 payoutAmount) =
            _parseHookData(token, hookData);

        rewardsInfo[paymentInfoHash][campaign].distributed += payoutAmount;

        return (_createPayouts(paymentInfo, paymentInfoHash, payoutAmount), 0);
    }

    /// @inheritdoc CampaignHooks
    function onAllocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        (AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 payoutAmount) =
            _parseHookData(token, hookData);

        rewardsInfo[paymentInfoHash][campaign].allocated += payoutAmount;

        return (_createPayouts(paymentInfo, paymentInfoHash, payoutAmount), 0);
    }

    /// @inheritdoc CampaignHooks
    function onDeallocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts)
    {
        (AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 payoutAmount) =
            _parseHookData(token, hookData);

        uint120 allocated = rewardsInfo[paymentInfoHash][campaign].allocated;
        if (allocated < payoutAmount) revert InsufficientAllocation(payoutAmount, allocated);
        rewardsInfo[paymentInfoHash][campaign].allocated = allocated - payoutAmount;

        return (_createPayouts(paymentInfo, paymentInfoHash, payoutAmount));
    }

    /// @inheritdoc CampaignHooks
    function onDistribute(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        (AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 payoutAmount) =
            _parseHookData(token, hookData);

        uint120 allocated = rewardsInfo[paymentInfoHash][campaign].allocated;
        if (allocated < payoutAmount) revert InsufficientAllocation(payoutAmount, allocated);
        rewardsInfo[paymentInfoHash][campaign].allocated = allocated - payoutAmount;

        rewardsInfo[paymentInfoHash][campaign].distributed += payoutAmount;

        return (_createPayouts(paymentInfo, paymentInfoHash, payoutAmount), 0);
    }

    /// @inheritdoc CampaignHooks
    function onWithdrawFunds(address sender, address campaign, address token, uint256 amount, bytes calldata hookData)
        external
        override
        onlyFlywheel
    {
        if (sender != owners[campaign]) revert Unauthorized();
    }

    /// @dev Parses the hook data and returns the payment info, payment info hash, and payout amount
    ///
    /// @param token Expected token address for validation
    /// @param hookData The hook data
    ///
    /// @return paymentInfo The payment info
    /// @return paymentInfoHash The payment info hash
    /// @return payoutAmount The payout amount
    function _parseHookData(address token, bytes calldata hookData)
        internal
        view
        returns (AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 payoutAmount)
    {
        // Check payout amount non-zero
        (paymentInfo, payoutAmount) = abi.decode(hookData, (AuthCaptureEscrow.PaymentInfo, uint120));
        if (payoutAmount == 0) revert ZeroPayoutAmount();

        // Check payment has been collected
        paymentInfoHash = escrow.getHash(paymentInfo);
        (bool hasCollectedPayment,,) = escrow.paymentState(paymentInfoHash);
        if (!hasCollectedPayment) revert PaymentNotCollected();
    }

    /// @notice Creates a Flywheel.Payout array for a given payment and amount
    ///
    /// @param paymentInfo Payment info
    /// @param paymentInfoHash Hash of payment info
    /// @param amount Amount of cashback to reward
    ///
    /// @return payouts Payout array
    function _createPayouts(AuthCaptureEscrow.PaymentInfo memory paymentInfo, bytes32 paymentInfoHash, uint120 amount)
        internal
        pure
        returns (Flywheel.Payout[] memory payouts)
    {
        payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: paymentInfo.payer,
            amount: amount,
            extraData: abi.encodePacked(paymentInfoHash)
        });
    }
}

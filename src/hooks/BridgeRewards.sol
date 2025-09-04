// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BuilderCodes} from "../BuilderCodes.sol";
import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";

/// @title BridgeRewards
///
/// @notice This contract is used to configure bridge rewards for Base builder codes. It is expected to be used in
///         conjunction with the BuilderCodes contract that manages codes registration. Once registered, this contract
///         allows the builder to start receiving rewards for each usage of the code during a bridge operation that
///         involves a transfer of tokens.
contract BridgeRewards is CampaignHooks {
    /// @notice The ERC-7528 pseudo-address representing native ETH in token operations
    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Maximum fee basis points (2.00%)
    uint256 public constant MAX_FEE_BASIS_POINTS = 2_00;

    /// @notice Address of the BuilderCodes contract
    BuilderCodes public immutable builderCodes;

    /// @notice Metadata URI for the campaign
    string public metadataURI;

    /// @notice Mapping of builder codes to fee percents
    mapping(bytes32 code => uint256 bps) public feeBasisPoints;

    /// @notice Emitted when the fee basis points is set
    ///
    /// @param code The builder code configured
    /// @param feeBps The fee basis points for the builder code
    event FeeBasisPointsSet(bytes32 indexed code, uint256 feeBps);

    /// @notice Error thrown when the sender is not the owner of the builder code
    error SenderIsNotBuilderCodeOwner();

    /// @notice Error thrown when the fee basis points is too high
    error FeeBasisPointsTooHigh();

    /// @notice Error thrown when the balance is zero
    error ZeroAmount();

    /// @notice Error thrown when the builder code is not registered
    error BuilderCodeNotRegistered();

    /// @notice Hooks constructor
    ///
    /// @param flywheel_ Address of the flywheel contract
    constructor(address flywheel_, address builderCodes_, string memory metadataURI_) CampaignHooks(flywheel_) {
        builderCodes = BuilderCodes(builderCodes_);
        metadataURI = metadataURI_;
    }

    /// @notice Sets the fee basis points for a builder code
    ///
    /// @param code The builder code to configure
    /// @param feeBps The fee basis points for the builder code
    function setFeeBasisPoints(bytes32 code, uint256 feeBps) external {
        address owner = builderCodes.ownerOf(uint256(code));
        require(msg.sender == owner, SenderIsNotBuilderCodeOwner());
        require(feeBps <= MAX_FEE_BASIS_POINTS, FeeBasisPointsTooHigh());

        feeBasisPoints[code] = feeBps;
        emit FeeBasisPointsSet(code, feeBps);
    }

    /// @inheritdoc CampaignHooks
    function onCreateCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {}

    /// @inheritdoc CampaignHooks
    function onReward(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, Flywheel.Allocation[] memory fees)
    {
        (address user, bytes32 code) = abi.decode(hookData, (address, bytes32));

        // Check balance is greater than total reserved for the campaign
        uint256 balance = token == ETH_ADDRESS ? campaign.balance : IERC20(token).balanceOf(campaign);
        uint256 unreservedAmount = balance - flywheel.totalReserved(campaign, token);
        require(unreservedAmount > 0, ZeroAmount());

        // Check builder code is registered
        require(builderCodes.ownerOf(uint256(code)) != address(0), BuilderCodeNotRegistered());

        // Compute fee amount
        uint256 feeAmount = (unreservedAmount * feeBasisPoints[code]) / 1e4;

        // Prepare payout
        payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: user,
            amount: unreservedAmount - feeAmount,
            extraData: abi.encode(code, feeAmount)
        });

        // Prepare fee if applicable
        if (feeAmount > 0) {
            fees = new Flywheel.Allocation[](1);
            fees[0] = Flywheel.Allocation({key: code, amount: feeAmount, extraData: ""});
        }
    }

    /// @inheritdoc CampaignHooks
    function onDistributeFees(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Distribution[] memory distributions)
    {
        bytes32 code = bytes32(hookData);

        // Early return if no fees are pending
        uint256 amount = flywheel.pendingFees(campaign, token, code);
        if (amount == 0) return distributions;

        distributions = new Flywheel.Distribution[](1);
        distributions[0] = Flywheel.Distribution({
            key: code,
            recipient: builderCodes.payoutAddress(uint256(code)),
            amount: amount,
            extraData: ""
        });
    }

    /// @inheritdoc CampaignHooks
    function onWithdrawFunds(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout memory payout)
    {
        // Anyone can withdraw, emphasizing that funds are meant to be atomically distributed after sending to campaign
        payout = abi.decode(hookData, (Flywheel.Payout));
    }

    /// @inheritdoc CampaignHooks
    function onUpdateStatus(
        address sender,
        address campaign,
        Flywheel.CampaignStatus oldStatus,
        Flywheel.CampaignStatus newStatus,
        bytes calldata hookData
    ) external override onlyFlywheel {
        // Anyone can set to ACTIVE to turn on the campaign
        if (newStatus != Flywheel.CampaignStatus.ACTIVE) revert Flywheel.InvalidCampaignStatus();
    }

    /// @inheritdoc CampaignHooks
    function onUpdateMetadata(address sender, address campaign, bytes calldata hookData)
        external
        override
        onlyFlywheel
    {
        // Anyone can prompt metadata cache updates
    }

    /// @inheritdoc CampaignHooks
    function campaignURI(address campaign) external view override returns (string memory uri) {
        return metadataURI;
    }
}

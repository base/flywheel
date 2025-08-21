// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";

/// @title SimpleRewards
///
/// @notice Campaign Hooks for simple rewards controlled by a campaign manager
contract SimpleRewards is CampaignHooks {
    /// @notice Owners of the campaigns
    mapping(address campaign => address owner) public owners;

    /// @notice Managers of the campaigns
    mapping(address campaign => address manager) public managers;

    /// @notice Mapping of campaign addresses to their URI
    mapping(address campaign => string uri) public override campaignURI;

    /// @notice Emitted when a campaign is created
    ///
    /// @param campaign Address of the campaign
    /// @param owner Address of the owner of the campaign
    /// @param manager Address of the manager of the campaign
    /// @param uri URI of the campaign
    event CampaignCreated(address indexed campaign, address owner, address manager, string uri);

    /// @notice Thrown when the sender is not the manager of the campaign
    error Unauthorized();

    /// @notice Modifier to check if the sender is the manager of the campaign
    ///
    /// @param sender Address of the sender
    /// @param campaign Address of the campaign
    ///
    /// @dev Reverts if the sender is not the manager of the campaign
    modifier onlyManager(address sender, address campaign) {
        if (sender != managers[campaign]) revert Unauthorized();
        _;
    }

    /// @notice Hooks constructor
    ///
    /// @param flywheel_ Address of the flywheel contract
    constructor(address flywheel_) CampaignHooks(flywheel_) {}

    /// @notice Creates a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param hookData Data for the campaign hook
    ///
    /// @dev Only callable by the flywheel contract
    /// @inheritdoc CampaignHooks
    function onCreateCampaign(address campaign, bytes calldata hookData) external virtual override onlyFlywheel {
        (address owner, address manager, string memory uri) = abi.decode(hookData, (address, address, string));
        owners[campaign] = owner;
        managers[campaign] = manager;
        campaignURI[campaign] = uri;
        emit CampaignCreated(campaign, owner, manager, uri);
    }

    /// @inheritdoc CampaignHooks
    function onReward(address sender, address campaign, address token, bytes calldata hookData)
        external
        virtual
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        payouts = abi.decode(hookData, (Flywheel.Payout[]));
        return (payouts, 0);
    }

    /// @inheritdoc CampaignHooks
    function onAllocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        virtual
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        payouts = abi.decode(hookData, (Flywheel.Payout[]));
        return (payouts, 0);
    }

    /// @inheritdoc CampaignHooks
    function onDeallocate(address sender, address campaign, address token, bytes calldata hookData)
        external
        virtual
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts)
    {
        payouts = abi.decode(hookData, (Flywheel.Payout[]));
        return (payouts);
    }

    /// @inheritdoc CampaignHooks
    function onDistribute(address sender, address campaign, address token, bytes calldata hookData)
        external
        virtual
        override
        onlyFlywheel
        onlyManager(sender, campaign)
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        payouts = abi.decode(hookData, (Flywheel.Payout[]));
        return (payouts, 0);
    }

    /// @inheritdoc CampaignHooks
    function onWithdrawFunds(address sender, address campaign, address token, uint256 amount, bytes calldata hookData)
        external
        virtual
        override
        onlyFlywheel
    {
        if (sender != owners[campaign]) revert Unauthorized();
    }

    /// @inheritdoc CampaignHooks
    function onUpdateStatus(
        address sender,
        address campaign,
        Flywheel.CampaignStatus oldStatus,
        Flywheel.CampaignStatus newStatus,
        bytes calldata hookData
    ) external virtual override onlyFlywheel onlyManager(sender, campaign) {}

    /// @inheritdoc CampaignHooks
    function onUpdateMetadata(address sender, address campaign, bytes calldata hookData)
        external
        virtual
        override
        onlyFlywheel
        onlyManager(sender, campaign)
    {}
}

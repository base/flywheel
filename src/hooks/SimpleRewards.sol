// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";

/// @title SimpleRewards
///
/// @notice Campaign Hooks for simple rewards controlled by a campaign manager
contract SimpleRewards is CampaignHooks {
    /// @notice Managers of the campaigns
    mapping(address campaign => address manager) public managers;

    /// @notice Thrown when the sender is not the manager of the campaign
    error Unauthorized();

    constructor(address flywheel_) CampaignHooks(flywheel_) {}

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
        if (sender != managers[campaign]) revert Unauthorized();
    }

    /// @inheritdoc CampaignHooks
    function onReward(address sender, address campaign, address token, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        if (sender != managers[campaign]) revert Unauthorized();
        payouts = abi.decode(hookData, (Flywheel.Payout[]));
        return (payouts, 0);
    }

    /// @inheritdoc CampaignHooks
    function onWithdrawFunds(address sender, address campaign, address token, uint256 amount, bytes calldata hookData)
        external
        override
        onlyFlywheel
    {
        if (sender != managers[campaign]) revert Unauthorized();
    }
}

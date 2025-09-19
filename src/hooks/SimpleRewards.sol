// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";

/// @title SimpleRewards
///
/// @notice Campaign Hooks for simple rewards controlled by a campaign manager
contract SimpleRewards is CampaignHooks {
    /// @notice Simple payout structure
    struct SimplePayout {
        /// @dev recipient Address receiving the payout
        address recipient;
        /// @dev amount Amount of tokens to be paid out
        uint256 amount;
        /// @dev extraData Extra data for the payout to attach in events
        bytes extraData;
    }

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

    /// @inheritdoc CampaignHooks
    function _onCreateCampaign(address campaign, uint256 nonce, bytes calldata hookData) internal virtual override {
        (address owner, address manager, string memory uri) = abi.decode(hookData, (address, address, string));
        owners[campaign] = owner;
        managers[campaign] = manager;
        campaignURI[campaign] = uri;
        emit CampaignCreated(campaign, owner, manager, uri);
    }

    /// @inheritdoc CampaignHooks
    function _onSend(address sender, address campaign, address token, bytes calldata hookData)
        internal
        virtual
        override
        onlyManager(sender, campaign)
        returns (
            Flywheel.Payout[] memory payouts,
            Flywheel.Payout[] memory immediateFees,
            Flywheel.Allocation[] memory delayedFees,
            bool revertOnFailedTransfer
        )
    {
        (SimplePayout[] memory simplePayouts, bool revertOnError) = abi.decode(hookData, (SimplePayout[], bool));
        revertOnFailedTransfer = false;
        payouts = new Flywheel.Payout[](simplePayouts.length);
        uint256 count = simplePayouts.length;
        for (uint256 i = 0; i < count; i++) {
            payouts[i] = Flywheel.Payout({
                recipient: simplePayouts[i].recipient,
                amount: simplePayouts[i].amount,
                extraData: simplePayouts[i].extraData,
                fallbackKey: _toKey(simplePayouts[i].recipient)
            });
        }
    }

    /// @inheritdoc CampaignHooks
    function _onAllocate(address sender, address campaign, address token, bytes calldata hookData)
        internal
        virtual
        override
        onlyManager(sender, campaign)
        returns (Flywheel.Allocation[] memory allocations)
    {
        SimplePayout[] memory simplePayouts = abi.decode(hookData, (SimplePayout[]));
        allocations = new Flywheel.Allocation[](simplePayouts.length);
        uint256 count = simplePayouts.length;
        for (uint256 i = 0; i < count; i++) {
            allocations[i] = Flywheel.Allocation({
                key: _toKey(simplePayouts[i].recipient),
                amount: simplePayouts[i].amount,
                extraData: simplePayouts[i].extraData
            });
        }
    }

    /// @inheritdoc CampaignHooks
    function _onDeallocate(address sender, address campaign, address token, bytes calldata hookData)
        internal
        virtual
        override
        onlyManager(sender, campaign)
        returns (Flywheel.Allocation[] memory allocations)
    {
        SimplePayout[] memory simplePayouts = abi.decode(hookData, (SimplePayout[]));
        allocations = new Flywheel.Allocation[](simplePayouts.length);
        uint256 count = simplePayouts.length;
        for (uint256 i = 0; i < count; i++) {
            allocations[i] = Flywheel.Allocation({
                key: _toKey(simplePayouts[i].recipient),
                amount: simplePayouts[i].amount,
                extraData: simplePayouts[i].extraData
            });
        }
    }

    /// @inheritdoc CampaignHooks
    function _onDistribute(address sender, address campaign, address token, bytes calldata hookData)
        internal
        virtual
        override
        onlyManager(sender, campaign)
        returns (
            Flywheel.Distribution[] memory distributions,
            Flywheel.Payout[] memory immediateFees,
            Flywheel.Allocation[] memory delayedFees,
            bool revertOnFailedTransfer
        )
    {
        (SimplePayout[] memory simplePayouts) = abi.decode(hookData, (SimplePayout[]));
        revertOnFailedTransfer = false;
        distributions = new Flywheel.Distribution[](simplePayouts.length);
        uint256 count = simplePayouts.length;
        for (uint256 i = 0; i < count; i++) {
            distributions[i] = Flywheel.Distribution({
                recipient: simplePayouts[i].recipient,
                key: _toKey(simplePayouts[i].recipient),
                amount: simplePayouts[i].amount,
                extraData: simplePayouts[i].extraData
            });
        }
    }

    /// @inheritdoc CampaignHooks
    function _onWithdrawFunds(address sender, address campaign, address token, bytes calldata hookData)
        internal
        virtual
        override
        returns (Flywheel.Payout memory payout)
    {
        if (sender != owners[campaign]) revert Unauthorized();
        SimplePayout memory simplePayout = abi.decode(hookData, (SimplePayout));
        return (
            Flywheel.Payout({
                recipient: simplePayout.recipient,
                amount: simplePayout.amount,
                extraData: simplePayout.extraData,
                fallbackKey: _toKey(simplePayout.recipient)
            })
        );
    }

    /// @inheritdoc CampaignHooks
    function _onUpdateStatus(
        address sender,
        address campaign,
        Flywheel.CampaignStatus oldStatus,
        Flywheel.CampaignStatus newStatus,
        bytes calldata hookData
    ) internal virtual override onlyManager(sender, campaign) {}

    /// @inheritdoc CampaignHooks
    function _onUpdateMetadata(address sender, address campaign, bytes calldata hookData)
        internal
        virtual
        override
        onlyManager(sender, campaign)
    {
        if (hookData.length > 0) campaignURI[campaign] = string(hookData);
    }

    /// @notice Converts an address to a bytes32 key
    ///
    /// @param recipient Address to convert to a key
    ///
    /// @return key The bytes32 key
    function _toKey(address recipient) internal pure returns (bytes32 key) {
        return bytes32(bytes20(recipient));
    }
}

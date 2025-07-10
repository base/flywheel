// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Flywheel} from "./Flywheel.sol";

/// @title CampaignHooks
///
/// @notice Abstract contract for campaign hooks that process campaign attributions
///
/// @dev This contract provides the interface and base functionality for campaign hooks
abstract contract CampaignHooks {
    /// @notice Address of the flywheel contract
    Flywheel public immutable flywheel;

    /// @notice Thrown when a function is not implemented
    error Unimplemented();

    /// @notice Constructor for CampaignHooks
    ///
    /// @param flywheel_ Address of the flywheel contract
    constructor(address flywheel_) {
        flywheel = Flywheel(flywheel_);
    }

    /// @notice Modifier to restrict function access to flywheel only
    modifier onlyFlywheel() {
        require(msg.sender == address(flywheel));
        _;
    }

    /// @notice Creates a campaign in the hook
    ///
    /// @param campaign Address of the campaign
    /// @param initData Initialization data for the campaign
    ///
    /// @dev Only callable by the flywheel contract
    function createCampaign(address campaign, bytes calldata initData) external virtual onlyFlywheel {}

    /// @notice Updates the metadata for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param data The data for the campaign
    ///
    /// @dev Only callable by the flywheel contract
    function updateMetadata(address sender, address campaign, bytes calldata data) external virtual onlyFlywheel {
        revert Unimplemented();
    }

    /// @notice Updates the campaign status
    ///
    /// @param campaign Address of the campaign
    /// @param oldStatus Old status of the campaign
    /// @param newStatus New status of the campaign
    ///
    /// @dev Only callable by the flywheel contract
    function updateStatus(
        address sender,
        address campaign,
        Flywheel.CampaignStatus oldStatus,
        Flywheel.CampaignStatus newStatus
    ) external virtual onlyFlywheel {
        revert Unimplemented();
    }

    /// @notice Processes attribution for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param payoutToken Address of the token to be distributed
    /// @param attributionData Encoded attribution data
    /// @return payouts Array of payouts to be distributed
    ///
    /// @dev Only callable by the flywheel contract
    function attribute(address sender, address campaign, address payoutToken, bytes calldata attributionData)
        external
        virtual
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 attributorFee)
    {
        revert Unimplemented();
    }

    /// @notice Allows sponsor to withdraw remaining tokens from a finalized campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the token to withdraw
    ///
    /// @dev Only callable by the flywheel contract
    function withdrawFunds(address sender, address campaign, address token) external virtual onlyFlywheel {
        revert Unimplemented();
    }

    /// @notice Returns the URI for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @return uri The URI for the campaign
    function campaignURI(address campaign) external view virtual returns (string memory uri) {
        revert Unimplemented();
    }
}

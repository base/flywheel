// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {CampaignHook} from "./CampaignHook.sol";

/// @title StandardCampaignHook
///
/// @notice Standard implementation of campaign status management
///
/// @dev Implements the original Flywheel campaign lifecycle with 6 states
contract StandardCampaignHook is CampaignHook {
    /// @notice Constructor for StandardCampaignHook
    ///
    /// @param protocol_ Address of the protocol contract
    /// @param finalizationBufferDefault_ Default finalization buffer duration
    constructor(address protocol_, uint256 finalizationBufferDefault_)
        CampaignHook(protocol_, finalizationBufferDefault_)
    {}

    /// @notice Internal function to validate status transitions
    ///
    /// @param campaign Address of the campaign
    /// @param currentStatus Current status of the campaign
    /// @param newStatus New status to transition to
    /// @param caller Address attempting the transition
    /// @param sponsor Address of the campaign sponsor
    /// @param attributor Address of the campaign attributor
    function _validateStatusTransition(
        address campaign,
        CampaignStatus currentStatus,
        CampaignStatus newStatus,
        address caller,
        address sponsor,
        address attributor
    ) internal override {
        bool isSponsor = (caller == sponsor);
        bool isAttributor = (caller == attributor);

        if (!isSponsor && !isAttributor) revert Unauthorized();

        // Prevent invalid transitions
        if (currentStatus == CampaignStatus.NONE || newStatus == CampaignStatus.NONE || currentStatus == newStatus) {
            revert InvalidCampaignStatus();
        }

        // Validate specific transitions based on roles and current status
        if (newStatus == CampaignStatus.CREATED) {
            // Cannot transition back to CREATED
            revert InvalidCampaignStatus();
        } else if (newStatus == CampaignStatus.OPEN) {
            if (currentStatus == CampaignStatus.CREATED) {
                // Only attributor can open a created campaign
                if (!isAttributor) revert Unauthorized();
            } else if (currentStatus == CampaignStatus.PAUSED) {
                // Both sponsor and attributor can unpause
                // No additional checks needed
            } else {
                revert InvalidCampaignStatus();
            }
        } else if (newStatus == CampaignStatus.PAUSED) {
            // Both sponsor and attributor can pause, only from OPEN
            if (currentStatus != CampaignStatus.OPEN) revert InvalidCampaignStatus();
        } else if (newStatus == CampaignStatus.CLOSED) {
            // Only sponsor can close, from OPEN or PAUSED
            if (!isSponsor) revert Unauthorized();
            if (currentStatus != CampaignStatus.OPEN && currentStatus != CampaignStatus.PAUSED) {
                revert InvalidCampaignStatus();
            }
            // Set attribution deadline when closing
            attributionDeadlines[campaign] = uint48(block.timestamp + finalizationBufferDefault);
        } else if (newStatus == CampaignStatus.FINALIZED) {
            if (isSponsor) {
                // Sponsor can finalize CREATED or CLOSED campaigns (after deadline)
                if (currentStatus == CampaignStatus.CREATED) {
                    // Allow sponsor to finalize created campaigns
                } else if (currentStatus == CampaignStatus.CLOSED) {
                    // Check if attribution deadline has passed
                    if (block.timestamp <= attributionDeadlines[campaign]) {
                        revert InvalidCampaignStatus();
                    }
                } else {
                    revert InvalidCampaignStatus();
                }
            } else if (isAttributor) {
                // Attributor can finalize any campaign except already finalized
                if (currentStatus == CampaignStatus.FINALIZED) {
                    revert InvalidCampaignStatus();
                }
            }
        }
    }

    /// @notice Internal function to check if campaign can accept attribution
    ///
    /// @param campaign Address of the campaign
    /// @return True if campaign can accept attribution
    function _canAttribute(address campaign) internal view override returns (bool) {
        CampaignStatus status = campaignStatus[campaign];
        return status == CampaignStatus.OPEN || status == CampaignStatus.PAUSED || status == CampaignStatus.CLOSED;
    }
}

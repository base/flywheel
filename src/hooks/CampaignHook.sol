// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

/// @title CampaignHook
///
/// @notice Abstract contract for campaign status management hooks
///
/// @dev This contract provides the interface and base functionality for campaign status management
abstract contract CampaignHook {
    /// @notice Possible states a campaign can be in
    enum CampaignStatus {
        NONE, // Campaign does not exist
        CREATED, // Initial state when campaign is first created
        OPEN, // Campaign is live and can accept attribution
        PAUSED, // Campaign is temporarily paused
        CLOSED, // Campaign is no longer live but can still accept lagging attribution
        FINALIZED // Campaign attribution is complete

    }

    /// @notice Address of the protocol contract
    address public immutable protocol;

    /// @notice Default buffer time before campaign can be finalized after closing
    uint256 public immutable finalizationBufferDefault;

    /// @notice Minimum finalization buffer (0 days)
    uint256 public constant FINALIZATION_BUFFER_MIN = 0 days;

    /// @notice Maximum finalization buffer (30 days)
    uint256 public constant FINALIZATION_BUFFER_MAX = 30 days;

    /// @notice Mapping from campaign address to its current status
    mapping(address campaign => CampaignStatus status) public campaignStatus;

    /// @notice Mapping from campaign address to its attribution deadline
    mapping(address campaign => uint48 deadline) public attributionDeadlines;

    /// @notice Emitted when a campaign status is updated
    ///
    /// @param campaign Address of the campaign
    /// @param sender Address that triggered the status change
    /// @param oldStatus Previous status of the campaign
    /// @param newStatus New status of the campaign
    event CampaignStatusUpdated(
        address indexed campaign, address sender, CampaignStatus oldStatus, CampaignStatus newStatus
    );

    /// @notice Thrown when campaign is in invalid status for operation
    error InvalidCampaignStatus();

    /// @notice Thrown when caller doesn't have required permissions
    error Unauthorized();

    /// @notice Thrown when finalization buffer is invalid
    error InvalidFinalizationBuffer();

    /// @notice Constructor for CampaignHook
    ///
    /// @param protocol_ Address of the protocol contract
    /// @param finalizationBufferDefault_ Default finalization buffer duration
    constructor(address protocol_, uint256 finalizationBufferDefault_) {
        protocol = protocol_;

        if (
            finalizationBufferDefault_ < FINALIZATION_BUFFER_MIN || finalizationBufferDefault_ > FINALIZATION_BUFFER_MAX
        ) {
            revert InvalidFinalizationBuffer();
        }

        finalizationBufferDefault = finalizationBufferDefault_;
    }

    /// @notice Modifier to restrict function access to protocol only
    modifier onlyProtocol() {
        require(msg.sender == protocol);
        _;
    }

    /// @notice Creates a campaign in the hook
    ///
    /// @param campaign Address of the campaign
    /// @param initData Initialization data for the campaign
    ///
    /// @dev Only callable by the protocol contract
    function createCampaign(address campaign, bytes calldata initData) external onlyProtocol {
        campaignStatus[campaign] = CampaignStatus.CREATED;
        _createCampaign(campaign, initData);
    }

    /// @notice Updates the status of a campaign
    ///
    /// @param campaign Address of the campaign to update
    /// @param newStatus New status to set for the campaign
    /// @param caller Address attempting to update the status
    /// @param sponsor Address of the campaign sponsor
    /// @param attributor Address of the campaign attributor
    ///
    /// @dev Only callable by the protocol contract
    function updateStatus(
        address campaign,
        CampaignStatus newStatus,
        address caller,
        address sponsor,
        address attributor
    ) external onlyProtocol {
        CampaignStatus currentStatus = campaignStatus[campaign];

        _validateStatusTransition(campaign, currentStatus, newStatus, caller, sponsor, attributor);

        campaignStatus[campaign] = newStatus;
        emit CampaignStatusUpdated(campaign, caller, currentStatus, newStatus);
    }

    /// @notice Checks if a campaign can accept attribution
    ///
    /// @param campaign Address of the campaign
    /// @return True if campaign can accept attribution
    function canAttribute(address campaign) external view returns (bool) {
        return _canAttribute(campaign);
    }

    /// @notice Gets the current status of a campaign
    ///
    /// @param campaign Address of the campaign
    /// @return Current status of the campaign
    function getStatus(address campaign) external view returns (CampaignStatus) {
        return campaignStatus[campaign];
    }

    /// @notice Gets the attribution deadline for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @return Attribution deadline timestamp
    function getAttributionDeadline(address campaign) external view returns (uint48) {
        return attributionDeadlines[campaign];
    }

    /// @notice Internal function to create a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param initData Initialization data for the campaign
    ///
    /// @dev Override this function in derived contracts
    function _createCampaign(address campaign, bytes calldata initData) internal virtual {}

    /// @notice Internal function to validate status transitions
    ///
    /// @param campaign Address of the campaign
    /// @param currentStatus Current status of the campaign
    /// @param newStatus New status to transition to
    /// @param caller Address attempting the transition
    /// @param sponsor Address of the campaign sponsor
    /// @param attributor Address of the campaign attributor
    ///
    /// @dev Override this function in derived contracts
    function _validateStatusTransition(
        address campaign,
        CampaignStatus currentStatus,
        CampaignStatus newStatus,
        address caller,
        address sponsor,
        address attributor
    ) internal virtual;

    /// @notice Internal function to check if campaign can accept attribution
    ///
    /// @param campaign Address of the campaign
    /// @return True if campaign can accept attribution
    ///
    /// @dev Override this function in derived contracts
    function _canAttribute(address campaign) internal view virtual returns (bool);
}

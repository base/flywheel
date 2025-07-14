// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title AdvertisementConversion
///
/// @notice Attribution hook for processing advertisement conversions
///
/// @dev Handles both onchain and offchain conversion events
contract AdvertisementConversion is CampaignHooks, Ownable {
    /// @notice Attribution structure containing payout and conversion data
    struct Attribution {
        /// @dev The payout to be distributed
        Flywheel.Payout payout;
        /// @dev The conversion data
        Conversion conversion;
        /// @dev Empty bytes if offchain conversion, encoded log data if onchain
        bytes logBytes;
    }

    /// @notice Conversion data structure
    struct Conversion {
        /// @dev Unique identifier for the conversion event
        bytes16 eventId;
        /// @dev Click identifier
        string clickId;
        /// @dev Configuration ID for the conversion
        uint8 conversionConfigId;
        /// @dev Publisher reference code
        string publisherRefCode;
        /// @dev Timestamp of the conversion
        uint32 timestamp;
        /// @dev Type of recipient for the conversion
        uint8 recipientType;
    }

    /// @notice Structure for recording onchain attribution events
    struct Log {
        /// @dev Chain ID where the transaction occurred
        uint256 chainId;
        /// @dev Transaction hash where the conversion occurred
        bytes32 transactionHash;
        /// @dev Index of the event log in the transaction
        uint256 index;
    }

    /// @notice Structure for recording finalization information
    struct CampaignState {
        /// @dev Address of the provider
        address provider;
        /// @dev Address of the advertiser
        address advertiser;
        /// @dev Timestamp when finalization can occur
        uint48 attributionDeadline;
    }

    /// @notice Maximum basis points
    uint16 public constant MAX_BPS = 10_000;

    /// @notice Maximum attribution deadline duration (30 days)
    uint48 public constant MAX_ATTRIBUTION_DEADLINE_DURATION = 30 days;

    /// @notice Attribution deadline duration (configurable by owner)
    uint48 public attributionDeadlineDuration;

    /// @notice Mapping of campaign addresses to their URI
    mapping(address campaign => string uri) public override campaignURI;

    /// @notice Mapping of campaign addresses to finalization information
    mapping(address campaign => CampaignState) public state;

    /// @notice Emitted when an offchain attribution event occurs
    ///
    /// @param campaign Address of the campaign
    /// @param conversion The conversion data
    event OffchainConversion(address indexed campaign, Conversion conversion);

    /// @notice Emitted when an onchain attribution event occurs
    ///
    /// @param campaign Address of the campaign
    /// @param conversion The conversion data
    /// @param log The onchain log data
    event OnchainConversion(address indexed campaign, Conversion conversion, Log log);

    /// @notice Error thrown when an unauthorized action is attempted
    error Unauthorized();

    /// @notice Emitted when an invalid fee BPS is provided
    ///
    /// @param feeBps The invalid fee BPS
    error InvalidFeeBps(uint16 feeBps);

    /// @notice Emitted when attribution deadline duration is updated
    ///
    /// @param oldDuration The previous duration
    /// @param newDuration The new duration
    event AttributionDeadlineDurationUpdated(uint48 oldDuration, uint48 newDuration);

    /// @notice Error thrown when attribution deadline duration is invalid
    ///
    /// @param duration The invalid duration
    error InvalidAttributionDeadlineDuration(uint48 duration);

    /// @notice Constructor for ConversionAttestation
    ///
    /// @param protocol_ Address of the protocol contract
    /// @param owner_ Address of the contract owner
    constructor(address protocol_, address owner_) CampaignHooks(protocol_) Ownable(owner_) {
        attributionDeadlineDuration = 7 days; // Set default to 7 days
    }

    /// @notice Updates the attribution deadline duration
    ///
    /// @param newDuration The new attribution deadline duration (0 to 30 days)
    ///
    /// @dev Only the contract owner can call this function
    function updateAttributionDeadlineDuration(uint48 newDuration) external onlyOwner {
        if (newDuration > MAX_ATTRIBUTION_DEADLINE_DURATION) {
            revert InvalidAttributionDeadlineDuration(newDuration);
        }

        uint48 oldDuration = attributionDeadlineDuration;
        attributionDeadlineDuration = newDuration;

        emit AttributionDeadlineDurationUpdated(oldDuration, newDuration);
    }

    /// @inheritdoc CampaignHooks
    function createCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {
        (address provider, address advertiser, string memory uri) = abi.decode(hookData, (address, address, string));
        state[campaign] = CampaignState({provider: provider, advertiser: advertiser, attributionDeadline: 0});
        campaignURI[campaign] = uri;
    }

    /// @inheritdoc CampaignHooks
    function updateMetadata(address sender, address campaign, bytes calldata hookData) external override onlyFlywheel {
        if (sender != state[campaign].provider && sender != state[campaign].advertiser) revert Unauthorized();
    }

    /// @inheritdoc CampaignHooks
    function updateStatus(
        address sender,
        address campaign,
        Flywheel.CampaignStatus oldStatus,
        Flywheel.CampaignStatus newStatus,
        bytes calldata hookData
    ) external override onlyFlywheel {
        // Provider always allowed, early return
        if (sender == state[campaign].provider) return;

        // Otherwise only advertiser allowed to update status
        if (sender != state[campaign].advertiser) revert Unauthorized();

        // Advertiser always allowed to close and start finalization delay
        if (newStatus == Flywheel.CampaignStatus.CLOSED) {
            state[campaign].attributionDeadline = uint48(block.timestamp) + attributionDeadlineDuration;
            return;
        }

        // Advertiser only allowed to finalize, but only if delay has passed
        if (newStatus != Flywheel.CampaignStatus.FINALIZED) revert Unauthorized();
        if (state[campaign].attributionDeadline > block.timestamp) revert Unauthorized();
    }

    /// @inheritdoc CampaignHooks
    function attribute(address sender, address campaign, address payoutToken, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        (Attribution[] memory attributions, uint16 feeBps) = abi.decode(hookData, (Attribution[], uint16));
        if (feeBps > MAX_BPS) revert InvalidFeeBps(feeBps);

        // Loop over attributions, deducting attribution fee from payout amount and emitting appropriate events
        payouts = new Flywheel.Payout[](attributions.length);
        for (uint256 i = 0; i < attributions.length; i++) {
            // Deduct attribution fee from payout amount
            Flywheel.Payout memory payout = attributions[i].payout;
            uint256 attributionFee = (payout.amount * feeBps) / MAX_BPS;
            fee += attributionFee;
            payouts[i] = Flywheel.Payout({recipient: payout.recipient, amount: payout.amount - attributionFee});

            // Emit onchain conversion if logBytes is present, else emit offchain conversion
            bytes memory logBytes = attributions[i].logBytes;
            Conversion memory conversion = attributions[i].conversion;
            if (logBytes.length > 0) {
                emit OnchainConversion(campaign, conversion, abi.decode(logBytes, (Log)));
            } else {
                emit OffchainConversion(campaign, conversion);
            }
        }
        return (payouts, fee);
    }

    /// @inheritdoc CampaignHooks
    /// @dev Only advertiser allowed to withdraw funds on finalized campaigns
    function withdrawFunds(address sender, address campaign, address token, uint256 amount, bytes calldata hookData)
        external
        view
        override
        onlyFlywheel
    {
        if (sender != state[campaign].advertiser) revert Unauthorized();
        if (flywheel.campaignStatus(campaign) != Flywheel.CampaignStatus.FINALIZED) revert Unauthorized();
    }
}

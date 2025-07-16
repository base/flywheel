// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FlywheelPublisherRegistry} from "../FlywheelPublisherRegistry.sol";

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
        /// @dev Amount of the payout for this conversion
        uint256 payoutAmount;
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
        /// @dev Address of the attribution provider
        address attributionProvider;
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

    /// @notice Address of the publisher registry contract
    FlywheelPublisherRegistry public immutable publisherRegistry;

    /// @notice Mapping of campaign addresses to their URI
    mapping(address campaign => string uri) public override campaignURI;

    /// @notice Mapping of campaign addresses to finalization information
    mapping(address campaign => CampaignState) public state;

    /// @notice Mapping of attribution provider addresses to their fee in basis points
    mapping(address attributionProvider => uint16 feeBps) public attributionProviderFees;

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

    /// @notice Error thrown when publisher ref code is invalid
    error InvalidPublisherRefCode();

    /// @notice Emitted when attribution deadline duration is updated
    ///
    /// @param oldDuration The previous duration
    /// @param newDuration The new duration
    event AttributionDeadlineDurationUpdated(uint48 oldDuration, uint48 newDuration);

    /// @notice Emitted when an attribution provider updates their fee
    ///
    /// @param attributionProvider The attribution provider address
    /// @param oldFeeBps The previous fee in basis points
    /// @param newFeeBps The new fee in basis points
    event AttributionProviderFeeUpdated(address indexed attributionProvider, uint16 oldFeeBps, uint16 newFeeBps);

    /// @notice Error thrown when attribution deadline duration is invalid
    ///
    /// @param duration The invalid duration
    error InvalidAttributionDeadlineDuration(uint48 duration);

    /// @notice Error thrown when an invalid address is provided
    error InvalidAddress();

    /// @notice Constructor for ConversionAttestation
    ///
    /// @param protocol_ Address of the protocol contract
    /// @param owner_ Address of the contract owner
    /// @param publisherRegistry_ Address of the publisher registry contract
    constructor(address protocol_, address owner_, address publisherRegistry_)
        CampaignHooks(protocol_)
        Ownable(owner_)
    {
        if (publisherRegistry_ == address(0)) revert InvalidAddress();
        attributionDeadlineDuration = 7 days; // Set default to 7 days
        publisherRegistry = FlywheelPublisherRegistry(publisherRegistry_);
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

    /// @notice Sets the fee for an attribution provider
    ///
    /// @param feeBps The fee in basis points (0 to 10000, where 10000 = 100%)
    ///
    /// @dev Only the attribution provider themselves can set their fee
    function setAttributionProviderFee(uint16 feeBps) external {
        if (feeBps > MAX_BPS) revert InvalidFeeBps(feeBps);

        uint16 oldFeeBps = attributionProviderFees[msg.sender];
        attributionProviderFees[msg.sender] = feeBps;

        emit AttributionProviderFeeUpdated(msg.sender, oldFeeBps, feeBps);
    }

    /// @inheritdoc CampaignHooks
    function createCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {
        (address attributionProvider, address advertiser, string memory uri) =
            abi.decode(hookData, (address, address, string));
        state[campaign] =
            CampaignState({attributionProvider: attributionProvider, advertiser: advertiser, attributionDeadline: 0});
        campaignURI[campaign] = uri;
    }

    /// @inheritdoc CampaignHooks
    function updateMetadata(address sender, address campaign, bytes calldata hookData) external override onlyFlywheel {
        if (sender != state[campaign].attributionProvider && sender != state[campaign].advertiser) {
            revert Unauthorized();
        }
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
        if (sender == state[campaign].attributionProvider) return;

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
    function attribute(address attributionProvider, address campaign, address payoutToken, bytes calldata hookData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        // Validate that the caller is the authorized attribution provider for this campaign
        if (attributionProvider != state[campaign].attributionProvider) revert Unauthorized();

        // Get the fee from the stored attribution provider fees
        uint16 feeBps = attributionProviderFees[attributionProvider];

        // Decode only the attributions from hookData
        Attribution[] memory attributions = abi.decode(hookData, (Attribution[]));

        // Loop over attributions, deducting attribution fee from payout amount and emitting appropriate events
        payouts = new Flywheel.Payout[](attributions.length);
        for (uint256 i = 0; i < attributions.length; i++) {
            // Validate publisher ref code exists in the registry
            string memory publisherRefCode = attributions[i].conversion.publisherRefCode;
            if (bytes(publisherRefCode).length > 0 && !publisherRegistry.publisherExists(publisherRefCode)) {
                revert InvalidPublisherRefCode();
            }

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

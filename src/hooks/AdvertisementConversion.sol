// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CampaignHooks} from "../CampaignHooks.sol";
import {Flywheel} from "../Flywheel.sol";
import {FlywheelPublisherRegistry} from "../FlywheelPublisherRegistry.sol";

// Enum for conversion config status
enum ConversionConfigStatus {
    ACTIVE,
    DISABLED
}

// Enum for event type
enum EventType {
    ONCHAIN,
    OFFCHAIN
}

// Conversion configuration structure
struct ConversionConfig {
    ConversionConfigStatus status; // ACTIVE or DISABLED
    EventType eventType; // onchain or offchain
    string conversionMetadataUrl; // url to extra metadata for offchain events
}

//

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
        /// @dev Whether this campaign has a publisher allowlist
        bool hasAllowlist;
    }

    /// @notice Maximum basis points
    uint16 public constant MAX_BPS = 10_000;

    /// @notice Maximum number of conversion configs per campaign (255 since we use uint8)
    uint8 public constant MAX_CONVERSION_CONFIGS = type(uint8).max;

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

    /// @notice Mapping from campaign to allowed publisher ref codes
    mapping(address campaign => mapping(string refCode => bool allowed)) public allowedPublishers;

    /// @notice Mapping from campaign to conversion configs by config ID
    mapping(address campaign => mapping(uint8 configId => ConversionConfig)) public conversionConfigs;

    /// @notice Mapping from campaign to number of conversion configs
    mapping(address campaign => uint8) public conversionConfigCount;

    /// @notice Emitted when an offchain attribution event occurred
    ///
    /// @param campaign Address of the campaign
    /// @param conversion The conversion data
    event OffchainConversionProcessed(address indexed campaign, Conversion conversion);

    /// @notice Emitted when an onchain attribution event occurred
    ///
    /// @param campaign Address of the campaign
    /// @param conversion The conversion data
    /// @param log The onchain log data
    event OnchainConversionProcessed(address indexed campaign, Conversion conversion, Log log);

    /// @notice Error thrown when an unauthorized action is attempted
    error Unauthorized();

    /// @notice Emitted when an invalid fee BPS is provided
    ///
    /// @param feeBps The invalid fee BPS
    error InvalidFeeBps(uint16 feeBps);

    /// @notice Error thrown when publisher ref code is invalid
    error InvalidPublisherRefCode();

    /// @notice Error thrown when publisher ref code is not in allowlist
    error PublisherNotAllowed();

    /// @notice Error thrown when conversion config ID is invalid
    error InvalidConversionConfigId();

    /// @notice Error thrown when conversion config is disabled
    error ConversionConfigDisabled();

    /// @notice Error thrown when trying to add too many conversion configs
    error TooManyConversionConfigs();

    /// @notice Emitted when a new conversion config is added to a campaign
    event ConversionConfigAdded(address indexed campaign, uint8 indexed configId, ConversionConfig config);

    /// @notice Emitted when a conversion config is disabled
    event ConversionConfigStatusChanged(
        address indexed campaign, uint8 indexed configId, ConversionConfigStatus status
    );

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
    function onCreateCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {
        (
            address attributionProvider,
            address advertiser,
            string memory uri,
            string[] memory allowedRefCodes,
            ConversionConfig[] memory configs
        ) = abi.decode(hookData, (address, address, string, string[], ConversionConfig[]));

        bool hasAllowlist = allowedRefCodes.length > 0;

        // Store campaign state
        state[campaign] = CampaignState({
            attributionProvider: attributionProvider,
            advertiser: advertiser,
            attributionDeadline: 0,
            hasAllowlist: hasAllowlist
        });
        campaignURI[campaign] = uri;

        // Set up allowed publishers mapping if allowlist exists
        if (hasAllowlist) {
            for (uint256 i = 0; i < allowedRefCodes.length; i++) {
                allowedPublishers[campaign][allowedRefCodes[i]] = true;
            }
        }

        // Store conversion configs
        conversionConfigCount[campaign] = uint8(configs.length);
        for (uint8 i = 0; i < configs.length; i++) {
            conversionConfigs[campaign][i] = configs[i];
        }
    }

    /// @inheritdoc CampaignHooks
    function onUpdateMetadata(address sender, address campaign, bytes calldata hookData)
        external
        view
        override
        onlyFlywheel
    {
        if (sender != state[campaign].attributionProvider && sender != state[campaign].advertiser) {
            revert Unauthorized();
        }
    }

    /// @inheritdoc CampaignHooks
    function onUpdateStatus(
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
    function onReward(address attributionProvider, address campaign, address payoutToken, bytes calldata hookData)
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

            // Check if publisher is in allowlist (if allowlist exists)
            if (state[campaign].hasAllowlist) {
                if (bytes(publisherRefCode).length > 0 && !allowedPublishers[campaign][publisherRefCode]) {
                    revert PublisherNotAllowed();
                }
            }

            // Validate conversion config
            uint8 configId = attributions[i].conversion.conversionConfigId;
            if (configId >= conversionConfigCount[campaign]) {
                revert InvalidConversionConfigId();
            }

            ConversionConfig memory config = conversionConfigs[campaign][configId];
            if (config.status == ConversionConfigStatus.DISABLED) {
                revert ConversionConfigDisabled();
            }

            // Determine the correct payout address
            address payoutAddress;
            uint8 recipientType = attributions[i].conversion.recipientType;

            // @notice: recipientType = 1 => publisher and we should use the publisher registry to get the payout address
            if (recipientType == 1 && bytes(publisherRefCode).length > 0) {
                // Publisher: fetch payout address from registry
                payoutAddress = publisherRegistry.getPublisherPayoutAddress(publisherRefCode, block.chainid);
                // @notice: for all other recipient types, we use the provided address
            } else {
                // User or other recipient type: use provided address
                payoutAddress = attributions[i].payout.recipient;
            }

            // Deduct attribution fee from payout amount
            Flywheel.Payout memory payout = attributions[i].payout;
            uint256 attributionFee = (payout.amount * feeBps) / MAX_BPS;
            fee += attributionFee;
            payouts[i] = Flywheel.Payout({recipient: payoutAddress, amount: payout.amount - attributionFee});

            // Emit onchain conversion if logBytes is present, else emit offchain conversion
            bytes memory logBytes = attributions[i].logBytes;
            Conversion memory conversion = attributions[i].conversion;

            if (logBytes.length > 0) {
                emit OnchainConversionProcessed(campaign, conversion, abi.decode(logBytes, (Log)));
            } else {
                emit OffchainConversionProcessed(campaign, conversion);
            }
        }

        return (payouts, fee);
    }

    /// @inheritdoc CampaignHooks
    /// @dev Only advertiser allowed to withdraw funds on finalized campaigns
    function onWithdrawFunds(address sender, address campaign, address token, uint256 amount, bytes calldata hookData)
        external
        view
        override
        onlyFlywheel
    {
        if (sender != state[campaign].advertiser) revert Unauthorized();
        if (flywheel.campaignStatus(campaign) != Flywheel.CampaignStatus.FINALIZED) revert Unauthorized();
    }

    /// @notice Checks if a campaign has a publisher allowlist
    /// @param campaign Address of the campaign
    /// @return True if the campaign has an allowlist
    function hasPublisherAllowlist(address campaign) external view returns (bool) {
        return state[campaign].hasAllowlist;
    }

    /// @notice Checks if a publisher ref code is allowed for a campaign
    /// @param campaign Address of the campaign
    /// @param refCode Publisher ref code to check
    /// @return True if the publisher is allowed (or if no allowlist exists)
    function isPublisherAllowed(address campaign, string memory refCode) external view returns (bool) {
        // If no allowlist exists, all publishers are allowed
        if (!state[campaign].hasAllowlist) {
            return true;
        }
        return allowedPublishers[campaign][refCode];
    }

    /// @notice Adds a publisher ref code to the campaign allowlist
    /// @param campaign Address of the campaign
    /// @param refCode Publisher ref code to add
    /// @dev Only advertiser can add publishers to allowlist
    function addAllowedPublisherRefCode(address campaign, string memory refCode) external {
        if (msg.sender != state[campaign].advertiser) revert Unauthorized();

        if (bytes(refCode).length == 0) revert InvalidPublisherRefCode();

        // Validate publisher exists in registry
        if (!publisherRegistry.publisherExists(refCode)) {
            revert InvalidPublisherRefCode();
        }

        // @notice: if the allowlist is not enabled during campaign creation, we revert
        if (!state[campaign].hasAllowlist) {
            revert Unauthorized();
        }

        // Add to mapping
        allowedPublishers[campaign][refCode] = true;
    }

    /// @notice Adds a new conversion config to an existing campaign
    /// @param campaign Address of the campaign
    /// @param config The conversion config to add
    /// @dev Only advertiser can add conversion configs
    function addConversionConfig(address campaign, ConversionConfig memory config) external {
        if (msg.sender != state[campaign].advertiser) revert Unauthorized();

        uint8 currentCount = conversionConfigCount[campaign];
        if (currentCount >= type(uint8).max) revert TooManyConversionConfigs();

        // Add the new config
        conversionConfigs[campaign][currentCount] = config;
        conversionConfigCount[campaign] = currentCount + 1;

        emit ConversionConfigAdded(campaign, currentCount, config);
    }

    /// @notice Disables a conversion config for a campaign
    /// @param campaign Address of the campaign
    /// @param configId The ID of the conversion config to disable
    /// @dev Only advertiser can disable conversion configs
    function disableConversionConfig(address campaign, uint8 configId) external {
        if (msg.sender != state[campaign].advertiser) revert Unauthorized();

        if (configId >= conversionConfigCount[campaign]) {
            revert InvalidConversionConfigId();
        }

        // Disable the config
        conversionConfigs[campaign][configId].status = ConversionConfigStatus.DISABLED;

        emit ConversionConfigStatusChanged(campaign, configId, ConversionConfigStatus.DISABLED);
    }

    /// @notice Gets a conversion config for a campaign
    /// @param campaign Address of the campaign
    /// @param configId The ID of the conversion config
    /// @return The conversion config
    function getConversionConfig(address campaign, uint8 configId) external view returns (ConversionConfig memory) {
        if (configId >= conversionConfigCount[campaign]) {
            revert InvalidConversionConfigId();
        }
        return conversionConfigs[campaign][configId];
    }
}

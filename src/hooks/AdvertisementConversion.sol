// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Flywheel} from "../Flywheel.sol";
import {CampaignHooks} from "../CampaignHooks.sol";

/// @title AdvertisementConversion
///
/// @notice Attribution hook for processing advertisement conversions
///
/// @dev Handles both onchain and offchain conversion events
contract AdvertisementConversion is CampaignHooks {
    /// @notice Attribution structure containing payout and conversion data
    ///
    /// @param payout The payout to be distributed
    /// @param conversion The conversion data
    /// @param logBytes Empty bytes if offchain conversion, encoded log data if onchain
    struct Attribution {
        Flywheel.Payout payout;
        Conversion conversion;
        bytes logBytes; // empty bytes if offchain conversion
    }

    /// @notice Conversion data structure
    ///
    /// @param eventId Unique identifier for the conversion event
    /// @param clickId Click identifier
    /// @param conversionConfigId Configuration ID for the conversion
    /// @param publisherRefCode Publisher reference code
    /// @param timestamp Timestamp of the conversion
    /// @param recipientType Type of recipient for the conversion
    struct Conversion {
        bytes16 eventId;
        string clickId;
        uint8 conversionConfigId;
        string publisherRefCode;
        uint32 timestamp;
        uint8 recipientType;
    }

    /// @notice Structure for recording onchain attribution events
    ///
    /// @param chainId Chain ID where the transaction occurred
    /// @param transactionHash Transaction hash where the conversion occurred
    /// @param index Index of the event log in the transaction
    struct Log {
        uint256 chainId;
        bytes32 transactionHash;
        uint256 index;
    }

    /// @notice Structure for recording finalization information
    ///
    /// @param provider Address of the provider
    /// @param advertiser Address of the advertiser
    /// @param finalizationDelay Delay before finalization can occur
    /// @param attributionDeadline Timestamp when finalization can occur
    struct CampaignState {
        address provider;
        address advertiser;
        uint48 finalizationDelay;
        uint48 attributionDeadline;
    }

    /// @notice Maximum basis points
    uint16 public constant MAX_BPS = 10_000;

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

    /// @notice Constructor for ConversionAttestation
    ///
    /// @param protocol_ Address of the protocol contract
    constructor(address protocol_) CampaignHooks(protocol_) {}

    /// @inheritdoc CampaignHooks
    function createCampaign(address campaign, bytes calldata initData) external override onlyFlywheel {
        (address provider, address advertiser, uint48 finalizationDelay, string memory uri) =
            abi.decode(initData, (address, address, uint48, string));
        state[campaign] = CampaignState({
            provider: provider,
            advertiser: advertiser,
            finalizationDelay: finalizationDelay,
            attributionDeadline: 0
        });
        campaignURI[campaign] = uri;
    }

    /// @inheritdoc CampaignHooks
    function updateMetadata(address sender, address campaign, bytes calldata data) external override onlyFlywheel {
        if (sender != state[campaign].provider) revert Unauthorized();
    }

    /// @inheritdoc CampaignHooks
    function updateStatus(
        address sender,
        address campaign,
        Flywheel.CampaignStatus oldStatus,
        Flywheel.CampaignStatus newStatus
    ) external override onlyFlywheel {
        // Provider always allowed, early return
        if (sender == state[campaign].provider) return;

        // Otherwise only advertiser allowed to update status
        if (sender != state[campaign].advertiser) revert Unauthorized();

        // Advertiser always allowed to close and start finalization delay
        if (newStatus == Flywheel.CampaignStatus.CLOSED) {
            state[campaign].attributionDeadline = uint48(block.timestamp) + state[campaign].finalizationDelay;
            return;
        }

        // Advertiser only allowed to finalize, but only if delay has passed
        if (newStatus != Flywheel.CampaignStatus.FINALIZED) revert Unauthorized();
        if (state[campaign].attributionDeadline > block.timestamp) revert Unauthorized();
    }

    /// @inheritdoc CampaignHooks
    function attribute(address sender, address campaign, address payoutToken, bytes calldata attributionData)
        external
        override
        onlyFlywheel
        returns (Flywheel.Payout[] memory payouts, uint256 providerFee)
    {
        (Attribution[] memory attributions, uint16 feeBps) = abi.decode(attributionData, (Attribution[], uint16));
        if (feeBps > MAX_BPS) revert InvalidFeeBps(feeBps);

        // Loop over attributions, deducting attribution fee from payout amount and emitting appropriate events
        payouts = new Flywheel.Payout[](attributions.length);
        for (uint256 i = 0; i < attributions.length; i++) {
            // Deduct attribution fee from payout amount
            Flywheel.Payout memory payout = attributions[i].payout;
            uint256 attributionFee = (payout.amount * feeBps) / MAX_BPS;
            providerFee += attributionFee;
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
        return (payouts, providerFee);
    }

    /// @inheritdoc CampaignHooks
    /// @dev Only advertiser allowed to withdraw funds on finalized campaigns
    function withdrawFunds(address sender, address campaign, address token) external view override onlyFlywheel {
        if (sender != state[campaign].advertiser) revert Unauthorized();
        if (flywheel.campaignStatus(campaign) != Flywheel.CampaignStatus.FINALIZED) revert Unauthorized();
    }
}

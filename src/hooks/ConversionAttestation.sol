// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {AttributionHook} from "./AttributionHook.sol";
import {Flywheel} from "../Flywheel.sol";

/// @title ConversionAttestation
///
/// @notice Attribution hook for processing conversion attestations
///
/// @dev Handles both onchain and offchain conversion events
contract ConversionAttestation is AttributionHook, Ownable2Step {
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
    /// @param userAddress Address of the user who performed the conversion
    /// @param txHash Transaction hash where the conversion occurred
    /// @param txChainId Chain ID where the transaction occurred
    /// @param txEventLogIndex Index of the event log in the transaction
    struct Log {
        address userAddress;
        bytes32 txHash;
        uint256 txChainId;
        uint256 txEventLogIndex;
    }

    /// @notice Base URI for campaign metadata
    string public baseURI;

    /// @notice Emitted when the base URI is updated
    ///
    /// @param baseURI The new base URI
    event BaseURIUpdated(string baseURI);

    /// @notice Emitted when a campaign is updated
    //.
    /// @param campaign Address of the campaign
    /// @param uri The URI for the campaign
    event CampaignUpdated(address indexed campaign, string uri);

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

    /// @notice Thrown when attribution data is invalid
    ///
    error InvalidAttributionData();

    /// @notice Constructor for ConversionAttestation
    ///
    /// @param protocol_ Address of the protocol contract
    /// @param owner_ Address of the contract owner
    constructor(address protocol_, address owner_) AttributionHook(protocol_) Ownable(owner_) {}

    /// @notice Sets the base URI for campaign metadata
    ///
    /// @param baseURI_ The new base URI
    ///
    /// @dev Only callable by the owner
    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseURI = baseURI_;
        emit BaseURIUpdated(baseURI_);
    }

    /// @notice Broadcasts a campaign update event
    ///
    /// @param campaign Address of the campaign
    ///
    /// @dev Only callable by the owner
    function broadcastCampaignUpdate(address campaign) external onlyOwner {
        emit CampaignUpdated(campaign, campaignURI(campaign));
    }

    /// @notice Returns the URI for a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return uri The URI for the campaign
    function campaignURI(address campaign) public view override returns (string memory uri) {
        return string.concat(baseURI, Strings.toHexString(campaign));
    }

    /// @notice Processes attribution for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param payoutToken Address of the token to be distributed (unused in this implementation)
    /// @param attributionData Encoded attribution data containing Attribution array
    ///
    /// @return payouts Array of payouts to be distributed
    ///
    /// @dev Decodes attribution data and emits appropriate conversion events
    function _attribute(address campaign, address payoutToken, bytes calldata attributionData)
        internal
        override
        returns (Flywheel.Payout[] memory payouts)
    {
        Attribution[] memory attributions = abi.decode(attributionData, (Attribution[]));

        // Initialize payouts array with correct length
        payouts = new Flywheel.Payout[](attributions.length);

        for (uint256 i = 0; i < attributions.length; i++) {
            payouts[i] = attributions[i].payout;
            bytes memory logBytes = attributions[i].logBytes;
            Conversion memory conversion = attributions[i].conversion;

            // Emit onchain conversion if logBytes is present, else emit offchain conversion
            if (logBytes.length > 0) {
                emit OnchainConversion(campaign, conversion, abi.decode(logBytes, (Log)));
            } else {
                emit OffchainConversion(campaign, conversion);
            }
        }
        return payouts;
    }
}

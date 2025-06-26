// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Flywheel} from "../Flywheel.sol";
import {AttributionHook} from "./AttributionHook.sol";
import {MetadataMixin} from "./MetadataMixin.sol";

/// @title ConversionAttestation
///
/// @notice Attribution hook for processing conversion attestations
///
/// @dev Handles both onchain and offchain conversion events
contract ConversionAttestation is AttributionHook, MetadataMixin {
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

    /// @notice Address of the entity trusted to attest conversions
    address public immutable attester;

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

    /// @notice Constructor for ConversionAttestation
    ///
    /// @param protocol_ Address of the protocol contract
    /// @param owner_ Address of the contract owner
    constructor(address protocol_, address owner_, address attester_)
        AttributionHook(protocol_)
        MetadataMixin(owner_)
    {
        attester = attester_;
    }

    /// @notice Returns the URI for a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return uri The URI for the campaign
    function campaignURI(address campaign) public view override returns (string memory uri) {
        return _campaignURI(campaign);
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
    function _attribute(address campaign, address attributor, address payoutToken, bytes calldata attributionData)
        internal
        override
        returns (Flywheel.Payout[] memory payouts)
    {
        // Check sender is attributor
        if (attributor != attester) revert Flywheel.Unauthorized();

        Attribution[] memory attributions = abi.decode(attributionData, (Attribution[]));
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

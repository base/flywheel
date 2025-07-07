// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import { Flywheel } from "../Flywheel.sol";
import { AttributionHook } from "./AttributionHook.sol";
import { MetadataMixin } from "./MetadataMixin.sol";
import { FlywheelPublisherRegistry } from "../FlywheelPublisherRegistry.sol";

error AllowlistPublisherAlreadyExists(address campaign, string refCode);
error ConversionConfigNotActive();
error MaxConversionConfigsReached();
error ConversionConfigDoesNotExist();
error Unauthorized();
error InvalidPublisherRefCode();
error InvalidAddress();

/// @title AdvertisementConversion
///
/// @notice Attribution hook for processing advertisement conversions
///
/// @dev Handles both onchain and offchain conversion events
contract AdvertisementConversion is AttributionHook, MetadataMixin {
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

  /// @notice Status of a conversion config
  enum ConversionConfigStatus {
    NONE,
    ACTIVE,
    DEACTIVATED
  }

  uint16 public constant MAX_BPS = 10_000;

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

  /// @notice Emitted when an invalid fee BPS is provided
  ///
  /// @param feeBps The invalid fee BPS
  error InvalidFeeBps(uint16 feeBps);

  /// @notice Emitted when an invalid conversion config ID is provided
  ///
  /// @param id The invalid conversion config ID
  error InvalidConversionConfigId(uint8 id);

  // --- Conversion Config Storage ---
  struct ConversionConfig {
    uint8 id;
    string eventName;
    uint256 publisherBidValue;
    uint256 userBidValue;
    uint8 rewardType;
    uint8 cadenceType;
    ConversionConfigStatus status;
  }
  mapping(address => mapping(uint8 => ConversionConfig)) public campaignConfigs;
  mapping(address => mapping(string => bool)) public campaignAllowlist;
  mapping(address => uint8) public campaignConversionConfigCount;

  event ConversionConfigAdded(
    address indexed campaign,
    uint8 id,
    string eventName,
    uint256 publisherBidValue,
    uint256 userBidValue,
    uint8 rewardType,
    uint8 cadenceType
  );
  event ConversionConfigDeactivated(address indexed campaign, uint8 id);
  event AllowlistPublisherAdded(address indexed campaign, string refCode);

  address public immutable publisherRegistry;
  mapping(address => address) public campaignAdvertiser;

  /// @notice Constructor for ConversionAttestation
  ///
  /// @param protocol_ Address of the protocol contract
  /// @param owner_ Address of the contract owner
  /// @param publisherRegistry_ Address of the publisher registry
  constructor(
    address protocol_,
    address owner_,
    address publisherRegistry_
  ) AttributionHook(protocol_) MetadataMixin(owner_) {
    if (publisherRegistry_ == address(0)) {
      revert InvalidAddress();
    }
    publisherRegistry = publisherRegistry_;
  }

  /// @notice Ensures caller is the advertiser for the campaign
  /// @param campaign Address of the campaign to validate
  modifier onlyAdvertiser(address campaign) {
    if (campaignAdvertiser[campaign] != msg.sender) {
      revert Unauthorized();
    }
    _;
  }

  /// @notice Checks if a publisher ref code is invalid
  /// @param publisherRefCode Publisher ref code to validate
  /// @return Whether the publisher ref code is invalid
  function isInvalidPublisherRefCode(string memory publisherRefCode) internal view returns (bool) {
    FlywheelPublisherRegistry registry = FlywheelPublisherRegistry(publisherRegistry);
    return !registry.publisherExists(publisherRefCode);
  }

  /// @notice Returns the URI for a campaign
  ///
  /// @param campaign Address of the campaign
  ///
  /// @return uri The URI for the campaign
  function campaignURI(address campaign) public view override returns (string memory uri) {
    return _campaignURI(campaign);
  }

  /// @notice Adds a new conversion config to an existing campaign
  /// @param campaign Address of the campaign
  /// @param config Configuration for the new conversion
  function addConversionConfig(address campaign, ConversionConfig memory config) external onlyAdvertiser(campaign) {
    if (campaignConversionConfigCount[campaign] + 1 > type(uint8).max) {
      // we don't want to overflow or store more than 255 conversion configs per campaign
      revert MaxConversionConfigsReached();
    }

    uint8 conversionConfigId = campaignConversionConfigCount[campaign] + 1;
    config.id = conversionConfigId;
    config.status = ConversionConfigStatus.ACTIVE;

    campaignConfigs[campaign][conversionConfigId] = config;
    campaignConversionConfigCount[campaign]++;

    emit ConversionConfigAdded(
      campaign,
      conversionConfigId,
      config.eventName,
      config.publisherBidValue,
      config.userBidValue,
      config.rewardType,
      config.cadenceType
    );
  }

  /// @notice Deactivates an existing conversion config
  /// @param campaign Address of the campaign
  /// @param conversionConfigId ID of the conversion config to deactivate
  function deactivateConversionConfig(address campaign, uint8 conversionConfigId) external onlyAdvertiser(campaign) {
    if (campaignConfigs[campaign][conversionConfigId].status != ConversionConfigStatus.ACTIVE) {
      revert ConversionConfigNotActive();
    }

    campaignConfigs[campaign][conversionConfigId].status = ConversionConfigStatus.DEACTIVATED;

    emit ConversionConfigDeactivated(campaign, conversionConfigId);
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
  function _attribute(
    address campaign,
    address attributor,
    address payoutToken,
    bytes calldata attributionData
  ) internal override returns (Flywheel.Payout[] memory payouts, uint256 attributorFee) {
    (Attribution[] memory attributions, uint16 feeBps) = abi.decode(attributionData, (Attribution[], uint16));
    if (feeBps > MAX_BPS) revert InvalidFeeBps(feeBps);

    // Loop over attributions, deducting attribution fee from payout amount and emitting appropriate events
    payouts = new Flywheel.Payout[](attributions.length);
    for (uint256 i = 0; i < attributions.length; i++) {
      uint8 configId = attributions[i].conversion.conversionConfigId;
      ConversionConfig storage config = campaignConfigs[campaign][configId];
      if (config.id == 0) {
        revert InvalidConversionConfigId(configId);
      }
      if (config.status != ConversionConfigStatus.ACTIVE) {
        revert ConversionConfigNotActive();
      }

      // Validate publisher ref code exists in registry
      if (isInvalidPublisherRefCode(attributions[i].conversion.publisherRefCode)) {
        revert InvalidPublisherRefCode();
      }

      // Deduct attribution fee from payout amount
      Flywheel.Payout memory payout = attributions[i].payout;
      uint256 attributionFee = (payout.amount * feeBps) / MAX_BPS;
      attributorFee += attributionFee;
      payouts[i] = Flywheel.Payout({ recipient: payout.recipient, amount: payout.amount - attributionFee });

      // Emit onchain conversion if logBytes is present, else emit offchain conversion
      bytes memory logBytes = attributions[i].logBytes;
      Conversion memory conversion = attributions[i].conversion;
      if (logBytes.length > 0) {
        emit OnchainConversion(campaign, conversion, abi.decode(logBytes, (Log)));
      } else {
        emit OffchainConversion(campaign, conversion);
      }
    }
    return (payouts, attributorFee);
  }

  function _createCampaign(address campaign, address sponsor, bytes calldata initData) internal override {
    (address advertiser, ConversionConfig[] memory configs, string[] memory allowlist) = abi.decode(
      initData,
      (address, ConversionConfig[], string[])
    );
    campaignAdvertiser[campaign] = advertiser;
    uint8 maxConfigId = 0;
    for (uint256 i = 0; i < configs.length; i++) {
      configs[i].status = ConversionConfigStatus.ACTIVE;
      campaignConfigs[campaign][configs[i].id] = configs[i];
      if (configs[i].id > maxConfigId) {
        maxConfigId = configs[i].id;
      }
      emit ConversionConfigAdded(
        campaign,
        configs[i].id,
        configs[i].eventName,
        configs[i].publisherBidValue,
        configs[i].userBidValue,
        configs[i].rewardType,
        configs[i].cadenceType
      );
    }
    campaignConversionConfigCount[campaign] = maxConfigId;
    for (uint256 i = 0; i < allowlist.length; i++) {
      // Validate publisher ref code exists in registry
      if (isInvalidPublisherRefCode(allowlist[i])) {
        revert InvalidPublisherRefCode();
      }
      campaignAllowlist[campaign][allowlist[i]] = true;
      emit AllowlistPublisherAdded(campaign, allowlist[i]);
    }
  }

  function addAllowlistPublisher(address campaign, string memory refCode) external onlyOwner {
    if (campaignAllowlist[campaign][refCode] == true) revert AllowlistPublisherAlreadyExists(campaign, refCode);

    // Validate publisher ref code exists in registry
    if (isInvalidPublisherRefCode(refCode)) {
      revert InvalidPublisherRefCode();
    }

    campaignAllowlist[campaign][refCode] = true;

    emit AllowlistPublisherAdded(campaign, refCode);
  }
}

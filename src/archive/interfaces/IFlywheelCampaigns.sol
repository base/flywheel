// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

interface IFlywheelCampaigns {
  /// @notice Thrown when attempting to use an unsupported token address
  error TokenAddressNotSupported();
  /// @notice Thrown when caller doesn't have required permissions
  error Unauthorized();
  /// @notice Thrown when attribution amount exceeds campaign budget
  error CannotOverAttribute();
  /// @notice Thrown when attempting to interact with non-existent campaign
  error CampaignDoesNotExist();
  /// @notice Thrown when campaign is in invalid status for operation
  error InvalidStatusTransition();
  error InvalidCampaignStatus();
  /// @notice Thrown when provided address is invalid (usually zero address)
  error InvalidAddress();
  /// @notice Thrown when attribution provider does not exist
  error AttributionProviderDoesNotExist();
  /// @notice Thrown when conversion config does not exist
  error ConversionConfigDoesNotExist();
  /// @notice Thrown when conversion config is not active
  error ConversionConfigNotActive();
  /// @notice Thrown when maximum number of conversion configs is reached
  error MaxConversionConfigsReached();
  /// @notice Thrown when protocol fee is invalid
  error InvalidProtocolFee();
  /// @notice Thrown when conversion config is invalid
  error InvalidConversionConfig();
  /// @notice Thrown when caller is not the attribution provider
  error CallerIsNotAttributionProvider();
  /// @notice Thrown when publisher ref code is not allowed
  error PublisherRefCodeNotAllowed();
  /// @notice Thrown when publisher ref code allowlist is not set
  error PublisherAllowlistNotSet();
  /// @notice Thrown when publisher ref code does not exist
  error InvalidPublisherRefCode();
  /// @notice Thrown when conversion config event type doesn't match attribution function type
  error InvalidEventType();
  /// @notice Thrown when trying to renounce ownership (disabled for security)
  error OwnershipRenunciationDisabled();

  /// @notice Emitted when a new campaign is created
  event CampaignCreated(
    uint256 indexed campaignId,
    address indexed advertiserAddress,
    address campaignBalanceAddress,
    address tokenAddress,
    uint256 attributionProviderId,
    string campaignMetadataUrl
  );

  /// @notice Emitted when campaign status is updated
  event UpdateCampaignStatus(uint256 indexed campaignId, uint8 newStatus);

  /// @notice Emitted when an onchain attribution event occurs
  event OnchainConversion(
    uint256 indexed campaignId,
    string publisherRefCode,
    uint8 conversionConfigId,
    bytes16 eventId,
    address payoutAddress,
    uint256 payoutAmount,
    uint256 protocolFeeAmount,
    uint8 recipientType,
    string clickId,
    address userAddress,
    uint32 timestamp,
    bytes32 txHash,
    uint256 txChainId,
    uint256 txEventLogIndex
  );

  /// @notice Emitted when an allowed publisher ref code is added
  event AllowedPublisherRefCodeAdded(uint256 indexed campaignId, string publisherRefCode);

  /// @notice Emitted when an offchain attribution event occurs
  event OffchainConversion(
    uint256 indexed campaignId,
    string publisherRefCode,
    uint8 conversionConfigId,
    bytes16 eventId,
    address payoutAddress,
    uint256 payoutAmount,
    uint256 protocolFeeAmount,
    uint8 recipientType,
    string clickId,
    uint32 timestamp
  );

  /// @notice Emitted when rewards are claimed by a recipient
  event ClaimedReward(uint256 indexed campaignId, address indexed payoutAddress, uint256 payoutAmount, address to);

  /// @notice Emitted when rewards are pushed to a recipient
  event PushedReward(uint256 indexed campaignId, address indexed payoutAddress, uint256 payoutAmount, address to);

  /// @notice Emitted when allowed token address status is updated
  event UpdateAllowedTokenAddress(address indexed tokenAddress, bool indexed allowed);

  event CreatedConversionConfig(
    uint8 indexed conversionConfigId,
    uint256 indexed campaignId,
    uint8 eventType,
    string eventName,
    string conversionMetadataUrl,
    uint256 publisherBidValue,
    uint256 userBidValue,
    uint8 rewardType,
    uint8 cadenceType
  );

  /// @notice Emitted when a conversion config is deactivated
  event DeactivatedConversionConfig(uint256 indexed campaignId, uint8 conversionConfigId);

  /// @notice Emitted when remaining balance is withdrawn
  event RemainingBalanceWithdrawn(
    uint256 indexed campaignId,
    address indexed advertiserAddress,
    address to,
    uint256 amount
  );

  /// @notice Emitted when an attribution provider is registered
  event RegisterAttributionProvider(uint256 indexed id, address indexed ownerAddress, address signerAddress);
  /// @notice Emitted when an attribution provider signer is updated
  event UpdateAttributionProviderSigner(uint256 indexed id, address indexed signerAddress);

  /// @notice Emitted when protocol fees are withdrawn
  event ProtocolFeesWithdrawn(uint256 indexed campaignId, uint256 amount, address treasury);

  /// @notice Emitted when treasury address is updated
  event UpdateTreasuryAddress(address indexed treasuryAddress);

  /// @notice Emitted when protocol fee is updated
  event UpdateProtocolFee(uint16 indexed protocolFee);

  event UpdatePublisherRegistryAddress(address indexed publisherRegistryAddress);

  /// @notice Possible states a campaign can be in
  enum CampaignStatus {
    NONE, // Campaign does not exist
    CREATED, // Initial state when campaign is first created
    CAMPAIGN_READY, // Advertiser signals that campaign is ready to receive attribution
    ACTIVE, // Campaign is live and can receive attribution
    PAUSED, // Campaign is temporarily paused
    PENDING_COMPLETION, // Campaign is being finalized
    COMPLETED // Campaign is complete and closed
  }

  enum ConversionConfigStatus {
    NONE,
    ACTIVE,
    DEACTIVATED
  }

  enum EventType {
    NONE,
    OFFCHAIN,
    ONCHAIN
  }

  enum CadenceEventType {
    NONE,
    ONE_TIME,
    RECURRING
  }

  enum RewardType {
    NONE,
    FLAT_FEE,
    PERCENTAGE
  }

  struct AttributionProvider {
    address ownerAddress;
    address signerAddress;
  }

  struct ConversionConfigInput {
    EventType eventType;
    string eventName;
    string conversionMetadataUrl;
    uint256 publisherBidValue; // if %, value is between 0 and 10000 = %100.00
    uint256 userBidValue; // if %, value is between 0 and 10000 = %100.00
    RewardType rewardType;
    CadenceEventType cadenceType;
  }

  struct ConversionConfig {
    ConversionConfigStatus status;
    EventType eventType;
    string eventName; // method name for onchain events. offchain event name can be anything
    string conversionMetadataUrl; // url to extra metadata for offchain events
    uint256 publisherBidValue; // publisher bid value
    uint256 userBidValue; // user bid value
    RewardType rewardType;
    CadenceEventType cadenceType; // one time or recurring
  }

  /// @notice Stores all information related to a specific campaign
  struct CampaignInfo {
    CampaignStatus status;
    address campaignBalanceAddress; // Address of associated CampaignBalance contract
    address tokenAddress; // ERC20 token address or address(0) for native crypto
    uint256 attributionProviderId; // ID of the attribution provider for this campaign
    address advertiserAddress; // Campaign creator/manager address
    mapping(uint8 conversionConfigId => ConversionConfig conversionConfig) conversionConfigs;
    uint8 conversionConfigCount;
    string campaignMetadataUrl;
    // cumlative campaign values for tracking rewards
    uint256 totalAmountClaimed; // Total amount claimed by publishers
    uint256 totalAmountAllocated; // Total amount attributed across all events
    uint256 protocolFeesBalance; // Track accumulated protocol fees for this campaign
    // recipient specific values for tracking rewards
    mapping(address recipient => uint256 balance) payoutsBalance;
    mapping(address recipient => uint256 claimed) payoutsClaimed;
    mapping(string publisherRefCode => bool allowed) allowedPublisherRefCodes;
    bool isAllowlistSet;
  }

  /// @notice Structure for recording onchain attribution events
  struct OnchainEvent {
    uint8 conversionConfigId;
    bytes16 eventId;
    address payoutAddress;
    uint256 payoutAmount;
    uint8 recipientType; // publisher = 1. user = 2
    string publisherRefCode;
    string clickId;
    address userAddress;
    uint32 timestamp;
    bytes32 txHash; // onchain specific value
    uint256 txChainId; // onchain specific value
    uint256 txEventLogIndex; // onchain specific value
  }

  /// @notice Structure for recording offchain attribution events
  struct OffchainEvent {
    uint8 conversionConfigId;
    bytes16 eventId;
    address payoutAddress;
    uint256 payoutAmount;
    uint8 recipientType; // publisher = 1. user = 2
    string publisherRefCode;
    string clickId;
    uint32 timestamp;
  }
}

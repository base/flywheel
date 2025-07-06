// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { CampaignBalance } from "./CampaignBalance.sol";
import { IFlywheelCampaigns } from "./interfaces/IFlywheelCampaigns.sol";
import { FlywheelPublisherRegistry } from "./FlywheelPublisherRegistry.sol";

/// @notice Main contract for the Flywheel Protocol advertising system
/// @dev Manages campaign lifecycle, attribution, and reward distribution
contract FlywheelCampaigns is Initializable, Ownable2StepUpgradeable, UUPSUpgradeable, IFlywheelCampaigns {
  uint256 public nextCampaignId;
  uint256 public nextAttributionProviderId;
  address public treasuryAddress;
  uint16 public protocolFee;
  address public publisherRegistryAddress;

  uint16 public constant PROTOCOL_FEE_PRECISION = 10_000; // = 100.00% in basis points
  uint16 public constant MAX_PROTOCOL_FEE = 1_000; // = 10.00% in basis points

  /// @notice Attribution providers
  mapping(uint256 id => AttributionProvider provider) public attributionProviders;
  /// @notice Mapping of payment token addresses to their allowed status
  mapping(address tokenAddress => bool allowed) public allowedTokenAddresses;
  /// @notice Mapping of campaign IDs to their campaign info
  mapping(uint256 campaignId => CampaignInfo campaign) public campaigns;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initialize function to replace constructor
  /// @param _owner Address that will own the contract
  /// @param _treasuryAddress Address where protocol fees will be sent
  /// @param _allowedTokenAddresses Array of ERC20 token addresses allowed for payments
  /// @param _attributionProviders Array of initial attribution providers to register
  function initialize(
    address _owner,
    address _treasuryAddress,
    address[] memory _allowedTokenAddresses,
    AttributionProvider[] memory _attributionProviders,
    address _publisherRegistryAddress
  ) external initializer {
    if (_treasuryAddress == address(0) || _owner == address(0)) {
      revert InvalidAddress();
    }

    // if address(0), then we will not use the publisher registry to validate publisher ref codes, nor reference payout addresses
    publisherRegistryAddress = _publisherRegistryAddress;

    __Ownable2Step_init();
    __UUPSUpgradeable_init();

    // Transfer ownership to the provided owner address
    _transferOwnership(_owner);

    treasuryAddress = _treasuryAddress;

    allowedTokenAddresses[address(0)] = true; // native crypto is always allowed
    uint256 allowedTokenAddressesLength = _allowedTokenAddresses.length;
    for (uint256 i; i < allowedTokenAddressesLength; i++) {
      allowedTokenAddresses[_allowedTokenAddresses[i]] = true;
      emit UpdateAllowedTokenAddress(_allowedTokenAddresses[i], true);
    }

    uint256 attributionProvidersLength = _attributionProviders.length;
    for (uint256 i; i < attributionProvidersLength; i++) {
      _registerAttributionProvider(_attributionProviders[i].ownerAddress, _attributionProviders[i].signerAddress);
    }
  }

  /// @notice Ensures caller is authorized attribution provider and campaign is in valid state
  /// @param _campaignId ID of the campaign to validate
  modifier onlyValidCampaignAttribution(uint256 _campaignId) {
    if (campaigns[_campaignId].status == CampaignStatus.NONE) {
      revert CampaignDoesNotExist();
    }

    uint256 attributionProviderId = campaigns[_campaignId].attributionProviderId;
    if (msg.sender != attributionProviders[attributionProviderId].signerAddress) {
      revert CallerIsNotAttributionProvider();
    }

    CampaignStatus campaignStatus = campaigns[_campaignId].status;
    if (
      campaignStatus == CampaignStatus.CREATED ||
      campaignStatus == CampaignStatus.CAMPAIGN_READY ||
      campaignStatus == CampaignStatus.COMPLETED
    ) {
      revert InvalidCampaignStatus();
    }
    _;
  }

  /// @notice Ensures caller is the advertiser for the campaign
  /// @param _campaignId ID of the campaign to validate
  modifier onlyAdvertiser(uint256 _campaignId) {
    if (campaigns[_campaignId].advertiserAddress != msg.sender) {
      revert Unauthorized();
    }
    _;
  }

  function isPublisherRegistryDefined() internal view returns (bool) {
    return publisherRegistryAddress != address(0);
  }

  function isInvalidPublisherRefCode(string memory _publisherRefCode) internal view returns (bool) {
    if (!isPublisherRegistryDefined()) {
      return false;
    }
    FlywheelPublisherRegistry registry = FlywheelPublisherRegistry(publisherRegistryAddress);
    if (!registry.publisherExists(_publisherRefCode)) {
      return true;
    }
    return false;
  }

  /// @notice Updates the treasury address for protocol fee collection
  /// @param newTreasuryAddress New address to receive protocol fees
  function updateTreasuryAddress(address newTreasuryAddress) external onlyOwner {
    if (newTreasuryAddress == address(0)) {
      revert InvalidAddress();
    }
    treasuryAddress = newTreasuryAddress;
    emit UpdateTreasuryAddress(newTreasuryAddress);
  }

  /// @notice Updates the protocol fee percentage
  /// @param _newProtocolFee New fee in basis points (100 = 1%)
  function updateProtocolFee(uint16 _newProtocolFee) external onlyOwner {
    if (_newProtocolFee > MAX_PROTOCOL_FEE) {
      revert InvalidProtocolFee();
    }
    protocolFee = _newProtocolFee;
    emit UpdateProtocolFee(_newProtocolFee);
  }

  /// @notice Updates whether a token address is allowed for campaigns
  /// @param _tokenAddress Address of ERC20 token or address(0) for native crypto
  /// @param _allowed Whether the token address should be allowed
  function updateAllowedTokenAddress(address _tokenAddress, bool _allowed) external onlyOwner {
    allowedTokenAddresses[_tokenAddress] = _allowed;
    emit UpdateAllowedTokenAddress(_tokenAddress, _allowed);
  }

  /// @notice Registers a new attribution provider
  /// @param _signerAddress Address that will be authorized to sign attributions
  function registerAttributionProvider(address _signerAddress) external returns (uint256) {
    return _registerAttributionProvider(msg.sender, _signerAddress);
  }

  /// @notice Updates the signer address for an attribution provider
  /// @param _id ID of the attribution provider
  /// @param _signerAddress New signer address to use
  function updateAttributionProviderSigner(uint256 _id, address _signerAddress) external {
    if (_signerAddress == address(0)) {
      revert InvalidAddress();
    }

    // if owner is not the caller, revert
    if (attributionProviders[_id].ownerAddress != msg.sender) {
      revert Unauthorized();
    }

    attributionProviders[_id].signerAddress = _signerAddress;
    emit UpdateAttributionProviderSigner(_id, _signerAddress);
  }

  /// @notice Creates a new advertising campaign
  /// @param _tokenAddress Address of token used for payments (address(0) for native crypto)
  /// @param _attributionProviderId ID of the attribution provider authorized for this campaign
  /// @param _setToCampaignReady Whether to set campaign status to CAMPAIGN_READY immediately
  /// @param _campaignMetadataUrl URL containing campaign metadata
  /// @param _conversionConfigs Array of conversion configurations for the campaign
  /// @return campaignId Unique identifier for the created campaign
  /// @return campaignBalanceAddress Address of the created CampaignBalance contract
  /// @return Array of created conversion config IDs
  function createCampaign(
    address _tokenAddress,
    uint256 _attributionProviderId,
    bool _setToCampaignReady,
    string memory _campaignMetadataUrl,
    ConversionConfigInput[] memory _conversionConfigs,
    string[] memory _allowedPublisherRefCodes
  ) external returns (uint256, address, uint8[] memory) {
    if (!allowedTokenAddresses[_tokenAddress]) {
      revert TokenAddressNotSupported();
    }

    if (attributionProviders[_attributionProviderId].ownerAddress == address(0)) {
      revert AttributionProviderDoesNotExist();
    }

    // check if publisher ref codes are valid
    uint256 allowedPublisherRefCodesLength = _allowedPublisherRefCodes.length;
    for (uint256 i; i < allowedPublisherRefCodesLength; i++) {
      if (isInvalidPublisherRefCode(_allowedPublisherRefCodes[i])) {
        revert InvalidPublisherRefCode();
      }
    }

    nextCampaignId++;

    // Create campaign balance contract
    CampaignBalance newCampaignBalance = new CampaignBalance(nextCampaignId, _tokenAddress, msg.sender);
    address campaignBalanceAddress = address(newCampaignBalance);

    // Initialize campaign storage
    _initializeCampaign(
      nextCampaignId,
      _setToCampaignReady,
      campaignBalanceAddress,
      _tokenAddress,
      _attributionProviderId,
      _campaignMetadataUrl,
      _allowedPublisherRefCodes
    );

    emit CampaignCreated(
      nextCampaignId,
      msg.sender,
      campaignBalanceAddress,
      _tokenAddress,
      _attributionProviderId,
      _campaignMetadataUrl
    );

    // Create conversion events
    uint8[] memory conversionConfigIds = _createConversionConfigs(nextCampaignId, _conversionConfigs);

    return (nextCampaignId, campaignBalanceAddress, conversionConfigIds);
  }

  // Helper function to initialize campaign storage
  /// @notice Initializes campaign storage with provided parameters
  /// @param campaignId ID of the campaign
  /// @param setToCampaignReady Whether to set initial status to CAMPAIGN_READY
  /// @param campaignBalanceAddress Address of associated CampaignBalance contract
  /// @param tokenAddress Address of payment token
  /// @param attributionProviderId ID of attribution provider
  /// @param campaignMetadataUrl URL containing campaign metadata
  function _initializeCampaign(
    uint256 campaignId,
    bool setToCampaignReady,
    address campaignBalanceAddress,
    address tokenAddress,
    uint256 attributionProviderId,
    string memory campaignMetadataUrl,
    string[] memory allowedPublisherRefCodes
  ) private {
    CampaignInfo storage campaign = campaigns[campaignId];
    campaign.status = setToCampaignReady ? CampaignStatus.CAMPAIGN_READY : CampaignStatus.CREATED;
    campaign.campaignBalanceAddress = campaignBalanceAddress;
    campaign.tokenAddress = tokenAddress;
    campaign.attributionProviderId = attributionProviderId;
    campaign.advertiserAddress = msg.sender;
    campaign.conversionConfigCount = 0;
    campaign.campaignMetadataUrl = campaignMetadataUrl;
    campaign.totalAmountClaimed = 0;
    campaign.totalAmountAllocated = 0;
    campaign.protocolFeesBalance = 0;

    // for publisher ref code allowlist
    if (allowedPublisherRefCodes.length != 0) {
      campaigns[campaignId].isAllowlistSet = true;
    }
    uint256 allowedPublisherRefCodesLength = allowedPublisherRefCodes.length;
    for (uint256 i; i < allowedPublisherRefCodesLength; i++) {
      campaign.allowedPublisherRefCodes[allowedPublisherRefCodes[i]] = true;
      emit AllowedPublisherRefCodeAdded(campaignId, allowedPublisherRefCodes[i]);
    }
  }

  /// @notice Gets a conversion config for a campaign
  /// @param _campaignId ID of the campaign
  /// @param _conversionConfigId ID of the conversion config
  /// @return The conversion config
  function getConversionConfig(
    uint256 _campaignId,
    uint8 _conversionConfigId
  ) external view returns (ConversionConfig memory) {
    return campaigns[_campaignId].conversionConfigs[_conversionConfigId];
  }

  /// @notice Adds a new conversion config to an existing campaign
  /// @param _campaignId ID of the campaign
  /// @param _conversionConfig Configuration for the new conversion
  function addConversionConfig(
    uint256 _campaignId,
    ConversionConfigInput memory _conversionConfig
  ) external onlyAdvertiser(_campaignId) {
    if (campaigns[_campaignId].conversionConfigCount + 1 > type(uint8).max) {
      // we don't want to overflow or store more than 255 conversion configs per campaign
      revert MaxConversionConfigsReached();
    }

    uint8 conversionConfigId = campaigns[_campaignId].conversionConfigCount + 1;
    _createConversionConfig(_campaignId, conversionConfigId, _conversionConfig);
    campaigns[_campaignId].conversionConfigCount++;
  }

  /// @notice Deactivates an existing conversion config
  /// @param _campaignId ID of the campaign
  /// @param _conversionConfigId ID of the conversion config to deactivate
  function deactivateConversionConfig(
    uint256 _campaignId,
    uint8 _conversionConfigId
  ) external onlyAdvertiser(_campaignId) {
    if (campaigns[_campaignId].conversionConfigs[_conversionConfigId].status != ConversionConfigStatus.ACTIVE) {
      revert ConversionConfigNotActive();
    }

    campaigns[_campaignId].conversionConfigs[_conversionConfigId].status = ConversionConfigStatus.DEACTIVATED;

    emit DeactivatedConversionConfig(_campaignId, _conversionConfigId);
  }

  /// @notice Updates the status of a campaign
  /// @param _campaignId ID of the campaign to update
  /// @param _newStatus New status to set for the campaign
  /// @dev Only campaign manager or attribution provider can call this function
  /// @dev Status transitions are strictly controlled based on current status and caller role
  function updateCampaignStatus(uint256 _campaignId, CampaignStatus _newStatus) external {
    bool isAdvertiser = campaigns[_campaignId].advertiserAddress == msg.sender;
    bool isAttributionProvider = attributionProviders[campaigns[_campaignId].attributionProviderId].signerAddress ==
      msg.sender;

    if (!isAdvertiser && !isAttributionProvider) {
      revert Unauthorized();
    }

    CampaignStatus currentStatus = campaigns[_campaignId].status;

    // Basic validation of invalid status transitions
    if (
      _newStatus == CampaignStatus.NONE ||
      currentStatus == CampaignStatus.NONE ||
      _newStatus == currentStatus ||
      _newStatus == CampaignStatus.CREATED ||
      currentStatus == CampaignStatus.COMPLETED // Cannot transition from COMPLETED
    ) {
      revert InvalidStatusTransition();
    }

    // Validate transitions based on roles and current status
    if (_newStatus == CampaignStatus.CAMPAIGN_READY) {
      // Only A can set to CAMPAIGN_READY, only from CREATED
      if (!isAdvertiser || currentStatus != CampaignStatus.CREATED) {
        revert InvalidStatusTransition();
      }
    } else if (_newStatus == CampaignStatus.ACTIVE) {
      // From CAMPAIGN_READY: only AP can set to ACTIVE
      // From PAUSED: both A & AP can set to ACTIVE
      if (currentStatus == CampaignStatus.CAMPAIGN_READY) {
        if (!isAttributionProvider) {
          revert InvalidStatusTransition();
        }
      } else if (currentStatus == CampaignStatus.PAUSED) {
        // Allow both A & AP to unpause
      } else {
        revert InvalidStatusTransition();
      }
    } else if (_newStatus == CampaignStatus.PAUSED) {
      // Both A & AP can set to PAUSED, only from ACTIVE
      if (currentStatus != CampaignStatus.ACTIVE) {
        revert InvalidStatusTransition();
      }
    } else if (_newStatus == CampaignStatus.PENDING_COMPLETION) {
      // Only A can set to PENDING_COMPLETION, from ACTIVE or PAUSED
      if (!isAdvertiser || (currentStatus != CampaignStatus.ACTIVE && currentStatus != CampaignStatus.PAUSED)) {
        revert InvalidStatusTransition();
      }
    } else if (_newStatus == CampaignStatus.COMPLETED) {
      // Only AP can set to COMPLETED from PENDING_COMPLETION
      if (currentStatus == CampaignStatus.PENDING_COMPLETION) {
        if (!isAttributionProvider) {
          revert InvalidStatusTransition();
        }
        // Only A can set to COMPLETED from CREATED or CAMPAIGN_READY
      } else if (currentStatus == CampaignStatus.CREATED || currentStatus == CampaignStatus.CAMPAIGN_READY) {
        if (!isAdvertiser) {
          revert InvalidStatusTransition();
        }
      } else {
        revert InvalidStatusTransition();
      }
    }

    campaigns[_campaignId].status = _newStatus;
    emit UpdateCampaignStatus(_campaignId, uint8(_newStatus));
  }

  /// @notice Gets the total balance for a campaign
  /// @param _campaignId ID of the campaign to check
  /// @return Total balance including claimed amounts
  function getCampaignTotalBalance(uint256 _campaignId) public view returns (uint256) {
    return CampaignBalance(payable(campaigns[_campaignId].campaignBalanceAddress)).getBalance();
  }

  /// @notice Gets the total amount funded for a campaign
  /// @param _campaignId ID of the campaign to check
  /// @return Total balance including claimed amounts
  function getCampaignTotalFunded(uint256 _campaignId) public view returns (uint256) {
    uint256 totalBalanceAmount = getCampaignTotalBalance(_campaignId);
    uint256 totalAmountClaimed = campaigns[_campaignId].totalAmountClaimed;
    return totalBalanceAmount + totalAmountClaimed;
  }

  function isPublisherRefCodeAllowed(uint256 _campaignId, string memory _publisherRefCode) public view returns (bool) {
    return campaigns[_campaignId].allowedPublisherRefCodes[_publisherRefCode];
  }

  /// @notice Allows recipients to claim their rewards from multiple campaigns
  /// @param _campaignIds Array of campaign IDs to claim from
  /// @param _to Address to send the rewards to
  function claimRewards(uint256[] calldata _campaignIds, address _to) external {
    uint256 campaignIdsLength = _campaignIds.length;
    for (uint256 i; i < campaignIdsLength; i++) {
      uint256 campaignId = _campaignIds[i];
      // anyone can try to claim rewards technically. however only if the following conditions are met, can the reward be claimed:
      // 1. the campaign exists
      // 2. the recipient is the msg.sender & has a non-zero balance in the campaign
      uint256 recipientRewardAmount = _claimReward(campaignId, msg.sender, _to);
      if (recipientRewardAmount != 0) {
        emit ClaimedReward(_campaignIds[i], msg.sender, recipientRewardAmount, _to);
      }
    }
  }

  /// @notice Allows owner to push rewards to multiple recipients
  /// @param _campaignId Campaign ID to push rewards from
  /// @param _recipientAddresses Array of recipient addresses
  function pushRewards(uint256 _campaignId, address[] calldata _recipientAddresses) external {
    if (
      msg.sender != campaigns[_campaignId].advertiserAddress &&
      msg.sender != attributionProviders[campaigns[_campaignId].attributionProviderId].signerAddress
    ) {
      revert Unauthorized();
    }

    uint256 recipientAddressesLength = _recipientAddresses.length;
    for (uint256 i; i < recipientAddressesLength; i++) {
      uint256 recipientRewardAmount = _claimReward(_campaignId, _recipientAddresses[i], _recipientAddresses[i]);
      emit PushedReward(_campaignId, _recipientAddresses[i], recipientRewardAmount, _recipientAddresses[i]);
    }
  }

  /// @notice Records offchain attribution events
  /// @param _campaignId Campaign ID to attribute events to
  /// @param _events Array of offchain events to record
  function attributeOffchainEvents(
    uint256 _campaignId,
    OffchainEvent[] calldata _events
  ) external onlyValidCampaignAttribution(_campaignId) {
    uint256 totalNewAttributedAmount;
    uint256 totalNewProtocolFees;

    uint256 eventsLength = _events.length;
    for (uint256 i; i < eventsLength; i++) {
      _onlyExistingConversionConfig(_campaignId, _events[i].conversionConfigId);
      _onlyAllowedPublisherRefCode(_campaignId, _events[i].publisherRefCode);
      _onlyValidEventType(_campaignId, _events[i].conversionConfigId, EventType.OFFCHAIN);
      // Validation done up to this point
      // 1. onlyValidCampaignAttribution confirms campaign is in valid state & attribution provider is valid
      // 2. _onlyExistingConversionConfig confirms conversion config exists
      // 3. _onlyAllowedPublisherRefCode confirms publisher ref code is allowed (if set)
      // 4. _onlyValidEventType confirms conversion config event type matches function type

      // if publisher registry is defined, validate publisher ref code exists
      if (isInvalidPublisherRefCode(_events[i].publisherRefCode)) {
        revert InvalidPublisherRefCode();
      }

      FlywheelPublisherRegistry registry = FlywheelPublisherRegistry(publisherRegistryAddress);

      // Get payout address from registry
      address payoutAddress;
      uint8 userType = _events[i].recipientType;
      if (userType == 1 && isPublisherRegistryDefined()) {
        // publisher
        payoutAddress = registry.getPublisherPayoutAddress(_events[i].publisherRefCode, block.chainid);
      } else {
        // user
        payoutAddress = _events[i].payoutAddress;
      }

      // Calculate protocol fee and update recipient balance
      uint256 protocolFeeAmount = calculateProtocolFeeAmount(_events[i].payoutAmount);
      uint256 amountAfterFee = _events[i].payoutAmount - protocolFeeAmount;

      // Update recipient balance
      campaigns[_campaignId].payoutsBalance[payoutAddress] =
        campaigns[_campaignId].payoutsBalance[payoutAddress] +
        amountAfterFee;

      // Accumulate totals
      totalNewProtocolFees = totalNewProtocolFees + protocolFeeAmount;
      totalNewAttributedAmount = totalNewAttributedAmount + _events[i].payoutAmount;

      emit OffchainConversion(
        _campaignId,
        _events[i].publisherRefCode,
        _events[i].conversionConfigId,
        _events[i].eventId,
        payoutAddress,
        amountAfterFee,
        protocolFeeAmount,
        _events[i].recipientType,
        _events[i].clickId,
        _events[i].timestamp
      );
    }

    // Verify total attribution amount doesn't exceed funded amount
    uint256 currentTotalAllocated = campaigns[_campaignId].totalAmountAllocated;
    uint256 totalFundedAmount = getCampaignTotalFunded(_campaignId);

    if (totalNewAttributedAmount + currentTotalAllocated > totalFundedAmount) {
      revert CannotOverAttribute();
    }

    // Update totals once
    campaigns[_campaignId].totalAmountAllocated =
      campaigns[_campaignId].totalAmountAllocated +
      totalNewAttributedAmount;
    campaigns[_campaignId].protocolFeesBalance = campaigns[_campaignId].protocolFeesBalance + totalNewProtocolFees;
  }

  /// @notice Records onchain attribution events
  /// @param _campaignId Campaign ID to attribute events to
  /// @param _events Array of onchain events to record
  function attributeOnchainEvents(
    uint256 _campaignId,
    OnchainEvent[] calldata _events
  ) external onlyValidCampaignAttribution(_campaignId) {
    uint256 totalNewAttributedAmount;
    uint256 totalNewProtocolFees;

    uint256 eventsLength = _events.length;
    for (uint256 i; i < eventsLength; i++) {
      _onlyExistingConversionConfig(_campaignId, _events[i].conversionConfigId);
      _onlyAllowedPublisherRefCode(_campaignId, _events[i].publisherRefCode);
      _onlyValidEventType(_campaignId, _events[i].conversionConfigId, EventType.ONCHAIN);

      // if publisher registry is defined, validate publisher ref code exists
      if (isInvalidPublisherRefCode(_events[i].publisherRefCode)) {
        revert InvalidPublisherRefCode();
      }

      uint8 userType = _events[i].recipientType;
      address payoutAddress;

      FlywheelPublisherRegistry registry = FlywheelPublisherRegistry(publisherRegistryAddress);

      if (userType == 1 && isPublisherRegistryDefined()) {
        // publisher
        payoutAddress = registry.getPublisherDefaultPayoutAddress(_events[i].publisherRefCode);
      } else {
        // user
        payoutAddress = _events[i].payoutAddress;
      }

      // Calculate protocol fee and update recipient balance
      uint256 protocolFeeAmount = calculateProtocolFeeAmount(_events[i].payoutAmount);
      uint256 amountAfterFee = _events[i].payoutAmount - protocolFeeAmount;

      // Update recipient balance
      campaigns[_campaignId].payoutsBalance[payoutAddress] =
        campaigns[_campaignId].payoutsBalance[payoutAddress] +
        amountAfterFee;

      // Accumulate totals
      totalNewProtocolFees = totalNewProtocolFees + protocolFeeAmount;
      totalNewAttributedAmount = totalNewAttributedAmount + _events[i].payoutAmount;

      emit OnchainConversion(
        _campaignId,
        _events[i].publisherRefCode,
        _events[i].conversionConfigId,
        _events[i].eventId,
        payoutAddress,
        amountAfterFee,
        protocolFeeAmount,
        _events[i].recipientType,
        _events[i].clickId,
        _events[i].userAddress,
        _events[i].timestamp,
        _events[i].txHash,
        _events[i].txChainId,
        _events[i].txEventLogIndex
      );
    }

    // Verify total attribution amount doesn't exceed funded amount
    uint256 currentTotalAllocated = campaigns[_campaignId].totalAmountAllocated;
    uint256 totalFundedAmount = getCampaignTotalFunded(_campaignId);

    if (totalNewAttributedAmount + currentTotalAllocated > totalFundedAmount) {
      revert CannotOverAttribute();
    }

    // Update totals once
    campaigns[_campaignId].totalAmountAllocated =
      campaigns[_campaignId].totalAmountAllocated +
      totalNewAttributedAmount;
    campaigns[_campaignId].protocolFeesBalance = campaigns[_campaignId].protocolFeesBalance + totalNewProtocolFees;
  }

  function calculateProtocolFeeAmount(uint256 _amount) public view returns (uint256) {
    return (_amount * protocolFee) / PROTOCOL_FEE_PRECISION;
    // protocol fee is 5%
  }

  /// @notice Adds a publisher ref code to the allowlist
  /// @param _campaignId Campaign ID to add the publisher ref code to
  /// @param _publisherRefCode Publisher ref code to add
  function addAllowedPublisherRefCode(
    uint256 _campaignId,
    string memory _publisherRefCode
  ) external onlyAdvertiser(_campaignId) {
    if (!campaigns[_campaignId].isAllowlistSet) {
      revert PublisherAllowlistNotSet();
    }

    // check if publisher ref code exists in registry
    FlywheelPublisherRegistry registry = FlywheelPublisherRegistry(publisherRegistryAddress);
    if (isPublisherRegistryDefined() && !registry.publisherExists(_publisherRefCode)) {
      revert InvalidPublisherRefCode();
    }

    if (campaigns[_campaignId].allowedPublisherRefCodes[_publisherRefCode]) {
      return;
    }

    campaigns[_campaignId].allowedPublisherRefCodes[_publisherRefCode] = true;

    emit AllowedPublisherRefCodeAdded(_campaignId, _publisherRefCode);
  }

  /// @notice Gets the current balance for a recipient in a campaign
  /// @param campaignId Campaign ID to check
  /// @param payoutAddress Address of the recipient payoutAddress
  /// @return Current balance of the recipient
  function getRecipientBalance(uint256 campaignId, address payoutAddress) external view returns (uint256) {
    return campaigns[campaignId].payoutsBalance[payoutAddress];
  }

  /// @notice Gets the total amount claimed by a recipient in a campaign
  /// @param campaignId Campaign ID to check
  /// @param recipient Address of the recipient
  /// @return Total amount claimed by the recipient
  function getRecipientClaimed(uint256 campaignId, address recipient) external view returns (uint256) {
    return campaigns[campaignId].payoutsClaimed[recipient];
  }

  /// @notice Withdraws remaining balance from a completed campaign
  /// @param _campaignId ID of the campaign
  /// @param _to Address to send the remaining balance to
  function withdrawRemainingBalance(uint256 _campaignId, address _to) external onlyAdvertiser(_campaignId) {
    // only if campaign is completed
    if (campaigns[_campaignId].status != CampaignStatus.COMPLETED) {
      revert InvalidCampaignStatus();
    }

    uint256 totalFundedAmount = getCampaignTotalFunded(_campaignId);

    // get total amount attributed
    uint256 totalAmountAllocated = campaigns[_campaignId].totalAmountAllocated;

    // calculate remaining balance

    uint256 remainingBalance = totalFundedAmount - totalAmountAllocated;

    if (remainingBalance == 0) {
      return;
    }

    // update the campaign's attributed & total claimed state
    campaigns[_campaignId].totalAmountAllocated = campaigns[_campaignId].totalAmountAllocated + remainingBalance;
    campaigns[_campaignId].totalAmountClaimed = campaigns[_campaignId].totalAmountClaimed + remainingBalance;

    // transfer remaining balance to advertiser
    CampaignBalance(payable(campaigns[_campaignId].campaignBalanceAddress)).sendPayment(remainingBalance, _to);

    emit RemainingBalanceWithdrawn(_campaignId, msg.sender, _to, remainingBalance);
  }

  /// @notice Claims protocol fees from multiple campaigns
  /// @param _campaignIds Array of campaign IDs to claim fees from
  function claimProtocolFees(uint256[] calldata _campaignIds) external {
    if (msg.sender != treasuryAddress) {
      revert Unauthorized();
    }

    uint256 campaignIdsLength = _campaignIds.length;
    for (uint256 i; i < campaignIdsLength; i++) {
      uint256 campaignId = _campaignIds[i];
      uint256 feesToClaim = campaigns[campaignId].protocolFeesBalance;

      if (feesToClaim != 0) {
        // Reset accumulated fees to 0 before transfer
        campaigns[campaignId].protocolFeesBalance = 0;
        campaigns[campaignId].totalAmountClaimed = campaigns[campaignId].totalAmountClaimed + feesToClaim;

        // Transfer fees from campaign balance contract
        CampaignBalance(payable(campaigns[campaignId].campaignBalanceAddress)).sendPayment(
          feesToClaim,
          treasuryAddress
        );

        emit ProtocolFeesWithdrawn(campaignId, feesToClaim, treasuryAddress);
      }
    }
  }

  /// @notice Gets the available protocol fees for a campaign
  /// @param _campaignId ID of the campaign to check
  /// @return Amount of unclaimed protocol fees
  function getAvailableProtocolFees(uint256 _campaignId) external view returns (uint256) {
    return campaigns[_campaignId].protocolFeesBalance;
  }

  /// @notice Registers a new attribution provider
  /// @param _ownerAddress Address that will own the attribution provider
  /// @param _signerAddress Address that will be authorized to sign attributions
  function _registerAttributionProvider(address _ownerAddress, address _signerAddress) private returns (uint256) {
    if (_ownerAddress == address(0) || _signerAddress == address(0)) {
      revert InvalidAddress();
    }

    nextAttributionProviderId++;
    attributionProviders[nextAttributionProviderId] = AttributionProvider(_ownerAddress, _signerAddress);

    emit RegisterAttributionProvider(nextAttributionProviderId, _ownerAddress, _signerAddress);

    return nextAttributionProviderId;
  }

  /// @notice private function to process reward claims
  /// @param _campaignId Campaign ID to claim from
  /// @param _recipient Address of the recipient
  /// @param _to Address to send rewards to
  /// @return Amount of rewards claimed
  function _claimReward(uint256 _campaignId, address _recipient, address _to) private returns (uint256) {
    uint256 recipientRewardAmount = campaigns[_campaignId].payoutsBalance[_recipient];

    if (recipientRewardAmount == 0) {
      return 0;
    }

    campaigns[_campaignId].payoutsClaimed[_recipient] =
      campaigns[_campaignId].payoutsClaimed[_recipient] +
      recipientRewardAmount;
    campaigns[_campaignId].payoutsBalance[_recipient] = 0;
    campaigns[_campaignId].totalAmountClaimed = campaigns[_campaignId].totalAmountClaimed + recipientRewardAmount;

    CampaignBalance payout = CampaignBalance(payable(campaigns[_campaignId].campaignBalanceAddress));
    payout.sendPayment(recipientRewardAmount, _to);

    return recipientRewardAmount;
  }

  // @notice Private function to check if a conversion config exists
  // @param _campaignId Campaign ID to check
  // @param _conversionConfigId Conversion config ID to check
  function _onlyExistingConversionConfig(uint256 _campaignId, uint8 _conversionConfigId) private view {
    if (campaigns[_campaignId].conversionConfigs[_conversionConfigId].status == ConversionConfigStatus.NONE) {
      revert ConversionConfigDoesNotExist();
    }
  }

  // @notice Private function to check if a publisher ref code is allowed
  // @param _campaignId Campaign ID to check
  // @param _publisherRefCode Publisher ref code to check
  function _onlyAllowedPublisherRefCode(uint256 _campaignId, string memory _publisherRefCode) private view {
    if (campaigns[_campaignId].isAllowlistSet && !isPublisherRefCodeAllowed(_campaignId, _publisherRefCode)) {
      revert PublisherRefCodeNotAllowed();
    }
  }

  // @notice Private function to check if conversion config event type matches attribution function type
  // @param _campaignId Campaign ID to check
  // @param _conversionConfigId Conversion config ID to check
  // @param _expectedEventType Expected event type for this attribution function
  function _onlyValidEventType(
    uint256 _campaignId,
    uint8 _conversionConfigId,
    EventType _expectedEventType
  ) private view {
    EventType configEventType = campaigns[_campaignId].conversionConfigs[_conversionConfigId].eventType;
    if (configEventType != _expectedEventType) {
      revert InvalidEventType();
    }
  }

  // Helper function to create multiple conversion events
  function _createConversionConfigs(
    uint256 campaignId,
    ConversionConfigInput[] memory conversionConfigs
  ) private returns (uint8[] memory) {
    if (conversionConfigs.length > type(uint8).max) {
      // we don't want to overflow or store more than 255 conversion configs per campaign
      revert MaxConversionConfigsReached();
    }
    uint8 conversionConfigId = 1;

    uint8[] memory conversionConfigIds = new uint8[](conversionConfigs.length);
    uint256 conversionConfigsLength = conversionConfigs.length;
    for (uint256 i; i < conversionConfigsLength; i++) {
      _createConversionConfig(campaignId, conversionConfigId, conversionConfigs[i]);
      campaigns[campaignId].conversionConfigCount++;
      conversionConfigIds[i] = conversionConfigId;
      conversionConfigId++;
    }

    return conversionConfigIds;
  }

  // @notice Private function to create a single conversion config
  // @param campaignId Campaign ID to create the conversion config for
  // @param conversionConfigId Conversion config ID to create
  // @param input Conversion config input to create
  function _createConversionConfig(
    uint256 campaignId,
    uint8 conversionConfigId,
    ConversionConfigInput memory input
  ) private {
    if (
      input.rewardType == RewardType.NONE ||
      input.cadenceType == CadenceEventType.NONE ||
      input.eventType == EventType.NONE
    ) {
      revert InvalidConversionConfig();
    }

    campaigns[campaignId].conversionConfigs[conversionConfigId] = ConversionConfig({
      status: ConversionConfigStatus.ACTIVE,
      eventType: input.eventType,
      eventName: input.eventName,
      conversionMetadataUrl: input.conversionMetadataUrl,
      publisherBidValue: input.publisherBidValue,
      userBidValue: input.userBidValue,
      rewardType: input.rewardType,
      cadenceType: input.cadenceType
    });

    emit CreatedConversionConfig(
      conversionConfigId,
      campaignId,
      uint8(input.eventType),
      input.eventName,
      input.conversionMetadataUrl,
      input.publisherBidValue,
      input.userBidValue,
      uint8(input.rewardType),
      uint8(input.cadenceType)
    );
  }

  /// @notice Function that authorizes an upgrade
  /// @dev Only the owner can upgrade the implementation
  /// @param newImplementation Address of the new implementation contract
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  /// @notice Updates the publisher registry address
  /// @param _publisherRegistryAddress New address of the publisher registry
  function updatePublisherRegistryAddress(address _publisherRegistryAddress) external onlyOwner {
    if (_publisherRegistryAddress == address(0)) {
      revert InvalidAddress();
    }
    publisherRegistryAddress = _publisherRegistryAddress;
    emit UpdatePublisherRegistryAddress(_publisherRegistryAddress);
  }

  /// @notice Gets the payout address for a publisher from the registry
  /// @param _refCode Publisher ref code
  /// @return payoutAddress The payout address for the publisher
  function getPublisherPayoutAddress(string memory _refCode) public view returns (address) {
    FlywheelPublisherRegistry registry = FlywheelPublisherRegistry(publisherRegistryAddress);
    return registry.getPublisherPayoutAddress(_refCode, block.chainid);
  }

  /// @notice Disabled to prevent accidental ownership renunciation
  /// @dev Overrides OpenZeppelin's renounceOwnership to prevent accidental calls
  function renounceOwnership() public pure override {
    revert OwnershipRenunciationDisabled();
  }
}

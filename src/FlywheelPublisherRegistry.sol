// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @notice Thrown when caller doesn't have required permissions
error Unauthorized();

/// @notice Thrown when ref code is already taken
error RefCodeAlreadyTaken();

/// @notice Emitted when a new publisher is registered
event PublisherRegistered(
  address indexed owner,
  address indexed defaultPayout,
  string refCode,
  string metadataUrl,
  bool isCustom
);

/// @notice Emitted when a publisher's payout override is created or updated
event UpdatePublisherChainPayoutAddress(string refCode, uint256 chainId, address payoutAddress);

event UpdatePublisherDefaultPayoutAddress(string refCode, address payoutAddress);

/// @notice Emitted when a publisher's metadata URL is updated
event UpdateMetadataUrl(string refCode, string metadataUrl);

/// @notice Emitted when a publisher's owner is updated
event UpdatedPublisherOwner(string refCode, address newOwner);

/// @notice Registry for publishers in the Flywheel Protocol
/// @dev Manages publisher registration and payout address management
contract FlywheelPublisherRegistry is Initializable, UUPSUpgradeable, OwnableUpgradeable {
  /// @notice Counter for generating unique publisher ref codes
  uint256 public nextPublisherNonce = 1;
  uint256 private constant REF_CODE_LENGTH = 8;

  /// @notice Mapping of publisher ref codes to their information
  mapping(string refCode => Publisher) public publishers;

  /// @notice Structure for chain-specific payout address overrides
  struct OverridePublisherPayout {
    uint256 chainId; // Chain ID for the override
    address payoutAddress; // Payout address for the specific chain
  }

  /// @notice Information about a registered publisher
  struct Publisher {
    address owner; // Address that controls this publisher
    string metadataUrl; // URL containing metadata info
    address defaultPayout; // Default payout address for all chains
    mapping(uint256 chainId => address payoutAddress) overridePayouts; // Chain-specific payout addresses in case a publisher wants to override the default payout for a specific chain
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes the contract (replaces constructor)
  /// @param _owner Address that will own the contract
  function initialize(address _owner) external initializer {
    __Ownable_init(_owner);
    __UUPSUpgradeable_init();
  }

  /// @notice Ensures caller is the owner of the specified publisher
  /// @param _refCode Ref code of the publisher to validate
  modifier onlyPublisher(string memory _refCode) {
    if (publishers[_refCode].owner != msg.sender) {
      revert Unauthorized();
    }
    _;
  }

  /// @notice Registers a new publisher in the system
  /// @param _metadataUrl URL containing publisher's metadata
  /// @param _defaultPayout Default payout address for all chains
  /// @param _overridePayouts Array of chain-specific payout overrides
  function registerPublisher(
    string memory _metadataUrl,
    address _defaultPayout,
    OverridePublisherPayout[] memory _overridePayouts
  ) external returns (string memory, uint256) {
    string memory refCode = _generateUniqueRefCode();

    publishers[refCode].owner = msg.sender;
    publishers[refCode].metadataUrl = _metadataUrl;
    publishers[refCode].defaultPayout = _defaultPayout;

    for (uint256 i = 0; i < _overridePayouts.length; i++) {
      publishers[refCode].overridePayouts[uint256(_overridePayouts[i].chainId)] = _overridePayouts[i].payoutAddress;

      emit UpdatePublisherChainPayoutAddress(refCode, _overridePayouts[i].chainId, _overridePayouts[i].payoutAddress);
    }

    emit PublisherRegistered(msg.sender, _defaultPayout, refCode, _metadataUrl, false);

    return (refCode, nextPublisherNonce);
  }

  /// @notice Registers a new publisher in the system with a custom ref code
  /// @param _refCode Custom ref code for the publisher
  /// @param _publisherOwner Owner of the publisher
  /// @param _metadataUrl URL containing publisher's metadata
  /// @param _defaultPayout Default payout address for all chains
  /// @param _overridePayouts Array of chain-specific payout overrides
  function registerPublisherCustom(
    string memory _refCode,
    address _publisherOwner,
    string memory _metadataUrl,
    address _defaultPayout,
    OverridePublisherPayout[] memory _overridePayouts
  ) external onlyOwner {
    // check if ref code is already taken
    if (publishers[_refCode].owner != address(0)) {
      revert RefCodeAlreadyTaken();
    }

    // validate ref code uniqueness
    publishers[_refCode].owner = _publisherOwner;
    publishers[_refCode].metadataUrl = _metadataUrl;
    publishers[_refCode].defaultPayout = _defaultPayout;

    for (uint256 i = 0; i < _overridePayouts.length; i++) {
      publishers[_refCode].overridePayouts[uint256(_overridePayouts[i].chainId)] = _overridePayouts[i].payoutAddress;
    }
    emit PublisherRegistered(_publisherOwner, _defaultPayout, _refCode, _metadataUrl, true);
  }

  /// @notice Updates the owner of a publisher
  /// @param _refCode ID of the publisher to update
  /// @param _newOwner New owner address
  /// @dev Only callable by current publisher owner
  function updatePublisherOwner(string memory _refCode, address _newOwner) external onlyPublisher(_refCode) {
    publishers[_refCode].owner = _newOwner;
    emit UpdatedPublisherOwner(_refCode, _newOwner);
  }

  /// @notice Updates the inventory dimensions URL for a publisher
  /// @param _refCode ID of the publisher to update
  /// @param _metadataUrl New URL containing inventory dimensions
  /// @dev Only callable by publisher owner
  function updateMetadataUrl(string memory _refCode, string memory _metadataUrl) external onlyPublisher(_refCode) {
    publishers[_refCode].metadataUrl = _metadataUrl;

    emit UpdateMetadataUrl(_refCode, _metadataUrl);
  }

  /// @notice Updates the default payout address for a publisher
  /// @param _refCode ID of the publisher to update
  /// @param _newDefaultPayoutAddress New default payout address
  /// @dev Only callable by publisher owner
  function updatePublisherDefaultPayout(
    string memory _refCode,
    address _newDefaultPayoutAddress
  ) external onlyPublisher(_refCode) {
    publishers[_refCode].defaultPayout = _newDefaultPayoutAddress;

    emit UpdatePublisherDefaultPayoutAddress(_refCode, _newDefaultPayoutAddress);
  }

  /// @notice Updates a chain-specific payout override for a publisher
  /// @param _refCode refCode of the publisher to update
  /// @param _chainId Chain ID for the override
  /// @param _newPayoutAddress New payout address for the specified chain
  /// @dev Only callable by publisher owner
  function updatePublisherOverridePayout(
    string memory _refCode,
    uint256 _chainId,
    address _newPayoutAddress
  ) external onlyPublisher(_refCode) {
    publishers[_refCode].overridePayouts[_chainId] = _newPayoutAddress;

    emit UpdatePublisherChainPayoutAddress(_refCode, _chainId, _newPayoutAddress);
  }

  function getRefCode(uint256 _publisherNonce) public pure returns (string memory) {
    bytes32 hash = keccak256(abi.encodePacked(_publisherNonce));
    bytes memory alphabet = "0123456789abcdefghijklmnopqrstuvwxyz";
    bytes memory str = new bytes(REF_CODE_LENGTH);

    // Use all 32 bytes of the hash to generate the ref code
    uint256 hashNum = uint256(hash);
    for (uint256 i = 0; i < REF_CODE_LENGTH; i++) {
      // Use division instead of byte indexing to better distribute values
      str[i] = alphabet[hashNum % 36];
      hashNum = hashNum / 36;
    }

    return string(str);
  }

  /// @notice Gets the chain-specific payout address for a publisher
  /// @param _refCode ID of the publisher
  /// @param _chainId Chain ID to get the payout address for
  /// @return The payout address for the specified chain
  function getPublisherOverridePayout(string memory _refCode, uint256 _chainId) external view returns (address) {
    return publishers[_refCode].overridePayouts[_chainId];
  }

  /// @notice Authorization for upgrades
  /// @param newImplementation Address of new implementation
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function _generateUniqueRefCode() internal returns (string memory) {
    string memory refCode;
    do {
      nextPublisherNonce++;
      refCode = getRefCode(nextPublisherNonce);
    } while (publishers[refCode].owner != address(0));

    return refCode;
  }
}

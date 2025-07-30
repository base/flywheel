// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice Thrown when caller doesn't have required permissions
error Unauthorized();

/// @notice Thrown when ref code is already taken
error RefCodeAlreadyTaken();

/// @notice Thrown when trying to renounce ownership (disabled for security)
error OwnershipRenunciationDisabled();

/// @notice Thrown when provided address is invalid (usually zero address)
error InvalidAddress();

/// @notice Emitted when a new publisher is registered
event PublisherRegistered(
    address indexed owner, address indexed defaultPayout, string refCode, string metadataUrl, bool isCustom
);

/// @notice Emitted when a publisher's payout override is created or updated
event UpdatePublisherChainPayoutAddress(string refCode, uint256 chainId, address payoutAddress);

event UpdatePublisherDefaultPayoutAddress(string refCode, address payoutAddress);

/// @notice Emitted when a publisher's metadata URL is updated
event UpdateMetadataUrl(string refCode, string metadataUrl);

/// @notice Emitted when a publisher's owner is updated
event UpdatedPublisherOwner(string refCode, address newOwner);

/// @notice Emitted when a signer role is granted
event SignerRoleGranted(address indexed account, address indexed admin);

/// @notice Emitted when a signer role is revoked
event SignerRoleRevoked(address indexed account, address indexed admin);

/// @notice Registry for publishers in the Flywheel Protocol
/// @dev Manages publisher registration and payout address management
contract FlywheelPublisherRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable, Ownable2StepUpgradeable {
    /// @notice Counter for generating unique publisher ref codes
    uint256 public nextPublisherNonce = 1;
    uint256 private constant REF_CODE_LENGTH = 8;

    /// @notice Role identifier for addresses authorized to call registerPublisherCustom
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    
    /// @notice EIP-1967 storage slot base for publishers mapping
    /// @dev keccak256("flywheel.publisher.registry.publishers") - 1
    bytes32 private constant PUBLISHERS_SLOT_BASE = 0x3456789012cdef013456789012cdef013456789012cdef013456789012cdef01;

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
    
    /// @notice EIP-712 storage structure for publisher data
    struct PublisherStorage {
        address owner;
        string metadataUrl;
        address defaultPayout;
        mapping(uint256 chainId => address payoutAddress) overridePayouts;
    }


    
    /// @notice Gets the storage slot for a specific publisher ref code
    /// @param refCode The publisher ref code
    /// @return slot The storage slot for the publisher data
    function _getPublisherSlot(string memory refCode) private pure returns (bytes32 slot) {
        return keccak256(abi.encodePacked(PUBLISHERS_SLOT_BASE, refCode));
    }
    
    /// @notice Gets the storage reference for a publisher
    /// @param refCode The publisher ref code
    /// @return r The storage reference to the publisher data
    function _getPublisherStorage(string memory refCode) private pure returns (PublisherStorage storage r) {
        bytes32 slot = _getPublisherSlot(refCode);
        assembly {
            r.slot := slot
        }
    }
    
    
    /// @notice Public getter for publisher information
    /// @param refCode The publisher ref code
    /// @return owner The publisher owner
    /// @return metadataUrl The publisher metadata URL
    /// @return defaultPayout The publisher default payout address
    function publishers(string memory refCode) external view returns (address owner, string memory metadataUrl, address defaultPayout) {
        PublisherStorage storage publisher = _getPublisherStorage(refCode);
        return (publisher.owner, publisher.metadataUrl, publisher.defaultPayout);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract (replaces constructor)
    /// @param _owner Address that will own the contract
    /// @param _signer Address to grant SIGNER_ROLE (can be address(0) to skip)
    function initialize(address _owner, address _signer) external initializer {
        if (_owner == address(0)) {
            revert InvalidAddress();
        }

        __AccessControl_init();
        __Ownable2Step_init();
        // Transfer ownership to the provided owner address
        _transferOwnership(_owner);
        __UUPSUpgradeable_init();

        // Grant DEFAULT_ADMIN_ROLE to owner (for managing other roles)
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        
        // Grant SIGNER_ROLE to initial signer if provided
        if (_signer != address(0)) {
            _grantRole(SIGNER_ROLE, _signer);
            emit SignerRoleGranted(_signer, _owner);
        }
    }

    /// @notice Ensures caller is the owner of the specified publisher
    /// @param _refCode Ref code of the publisher to validate
    modifier onlyPublisher(string memory _refCode) {
        if (_getPublisherStorage(_refCode).owner != msg.sender) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Ensures caller is either the owner or has SIGNER_ROLE
    modifier onlyOwnerOrSigner() {
        bool isOwner = msg.sender == owner();
        bool hasSigner = hasRole(SIGNER_ROLE, msg.sender);

        if (!isOwner && !hasSigner) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Grants SIGNER_ROLE to an address
    /// @param _signer Address to grant SIGNER_ROLE
    function grantSignerRole(address _signer) external onlyOwner {
        if (_signer == address(0)) {
            revert InvalidAddress();
        }
        _grantRole(SIGNER_ROLE, _signer);
        emit SignerRoleGranted(_signer, msg.sender);
    }

    /// @notice Revokes SIGNER_ROLE from an address
    /// @param _signer Address to revoke SIGNER_ROLE from
    function revokeSignerRole(address _signer) external onlyOwner {
        _revokeRole(SIGNER_ROLE, _signer);
        emit SignerRoleRevoked(_signer, msg.sender);
    }

    /// @notice Checks if an address has SIGNER_ROLE
    /// @param _account Address to check
    /// @return True if the address has SIGNER_ROLE
    function isSigner(address _account) external view returns (bool) {
        return hasRole(SIGNER_ROLE, _account);
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
        PublisherStorage storage publisher = _getPublisherStorage(refCode);

        publisher.owner = msg.sender;
        publisher.metadataUrl = _metadataUrl;
        publisher.defaultPayout = _defaultPayout;

        uint256 overridePayoutsLength = _overridePayouts.length;
        for (uint256 i; i < overridePayoutsLength; i++) {
            publisher.overridePayouts[uint256(_overridePayouts[i].chainId)] =
                _overridePayouts[i].payoutAddress;

            emit UpdatePublisherChainPayoutAddress(
                refCode, _overridePayouts[i].chainId, _overridePayouts[i].payoutAddress
            );
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
    ) external onlyOwnerOrSigner {
        PublisherStorage storage publisher = _getPublisherStorage(_refCode);
        
        // check if ref code is already taken
        if (publisher.owner != address(0)) {
            revert RefCodeAlreadyTaken();
        }

        if (_publisherOwner == address(0) || _defaultPayout == address(0)) {
            revert InvalidAddress();
        }

        // validate ref code uniqueness
        publisher.owner = _publisherOwner;
        publisher.metadataUrl = _metadataUrl;
        publisher.defaultPayout = _defaultPayout;

        uint256 overridePayoutsLength = _overridePayouts.length;
        for (uint256 i; i < overridePayoutsLength; i++) {
            publisher.overridePayouts[uint256(_overridePayouts[i].chainId)] =
                _overridePayouts[i].payoutAddress;
        }
        emit PublisherRegistered(_publisherOwner, _defaultPayout, _refCode, _metadataUrl, true);
    }

    /// @notice Updates the owner of a publisher
    /// @param _refCode ID of the publisher to update
    /// @param _newOwner New owner address
    /// @dev Only callable by current publisher owner
    function updatePublisherOwner(string memory _refCode, address _newOwner) external onlyPublisher(_refCode) {
        if (_newOwner == address(0)) {
            revert InvalidAddress();
        }
        _getPublisherStorage(_refCode).owner = _newOwner;
        emit UpdatedPublisherOwner(_refCode, _newOwner);
    }

    /// @notice Updates the inventory dimensions URL for a publisher
    /// @param _refCode ID of the publisher to update
    /// @param _metadataUrl New URL containing inventory dimensions
    /// @dev Only callable by publisher owner
    function updateMetadataUrl(string memory _refCode, string memory _metadataUrl) external onlyPublisher(_refCode) {
        _getPublisherStorage(_refCode).metadataUrl = _metadataUrl;

        emit UpdateMetadataUrl(_refCode, _metadataUrl);
    }

    /// @notice Updates the default payout address for a publisher
    /// @param _refCode ID of the publisher to update
    /// @param _newDefaultPayoutAddress New default payout address
    /// @dev Only callable by publisher owner
    function updatePublisherDefaultPayout(string memory _refCode, address _newDefaultPayoutAddress)
        external
        onlyPublisher(_refCode)
    {
        _getPublisherStorage(_refCode).defaultPayout = _newDefaultPayoutAddress;

        emit UpdatePublisherDefaultPayoutAddress(_refCode, _newDefaultPayoutAddress);
    }

    /// @notice Updates a chain-specific payout override for a publisher
    /// @param _refCode refCode of the publisher to update
    /// @param _chainId Chain ID for the override
    /// @param _newPayoutAddress New payout address for the specified chain
    /// @dev Only callable by publisher owner
    function updatePublisherOverridePayout(string memory _refCode, uint256 _chainId, address _newPayoutAddress)
        external
        onlyPublisher(_refCode)
    {
        _getPublisherStorage(_refCode).overridePayouts[_chainId] = _newPayoutAddress;

        emit UpdatePublisherChainPayoutAddress(_refCode, _chainId, _newPayoutAddress);
    }

    function getRefCode(uint256 _publisherNonce) public pure returns (string memory) {
        bytes32 hash = keccak256(abi.encodePacked(_publisherNonce));
        bytes memory alphabet = "0123456789abcdefghijklmnopqrstuvwxyz";
        bytes memory str = new bytes(REF_CODE_LENGTH);

        // Use all 32 bytes of the hash to generate the ref code
        uint256 hashNum = uint256(hash);
        for (uint256 i; i < REF_CODE_LENGTH; i++) {
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
        return _getPublisherStorage(_refCode).overridePayouts[_chainId];
    }

    /// @notice Gets the default payout address for a publisher
    /// @param _refCode Ref code of the publisher
    /// @return The default payout address
    function getPublisherDefaultPayoutAddress(string memory _refCode) external view returns (address) {
        return _getPublisherStorage(_refCode).defaultPayout;
    }

    function getPublisherPayoutAddress(string memory _refCode, uint256 _chainId) external view returns (address) {
        PublisherStorage storage publisher = _getPublisherStorage(_refCode);
        return publisher.overridePayouts[_chainId] != address(0)
            ? publisher.overridePayouts[_chainId]
            : publisher.defaultPayout;
    }

    /// @notice Checks if a publisher exists
    /// @param _refCode Ref code of the publisher to check
    /// @return True if the publisher exists
    function publisherExists(string memory _refCode) external view returns (bool) {
        return _getPublisherStorage(_refCode).owner != address(0);
    }

    /// @notice Authorization for upgrades
    /// @param newImplementation Address of new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Disabled to prevent accidental ownership renunciation
    /// @dev Overrides OpenZeppelin's renounceOwnership to prevent accidental calls
    function renounceOwnership() public pure override {
        revert OwnershipRenunciationDisabled();
    }


    function _generateUniqueRefCode() internal returns (string memory) {
        string memory refCode;
        do {
            nextPublisherNonce++;
            refCode = getRefCode(nextPublisherNonce);
        } while (_getPublisherStorage(refCode).owner != address(0));

        return refCode;
    }
}

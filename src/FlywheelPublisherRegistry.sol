// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice Registry for publishers in the Flywheel Protocol
///
/// @dev Manages publisher registration and payout address management
///
/// @author Coinbase
contract FlywheelPublisherRegistry is
    Initializable,
    AccessControlUpgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    /// @notice Information about a registered publisher
    struct Publisher {
        /// @dev Address that controls this publisher
        address owner;
        /// @dev URL containing metadata info
        string metadataUrl;
        /// @dev Default payout address for all chains
        address defaultPayout;
    }

    /// @notice EIP-712 storage structure for registry data
    /// @custom:storage-location erc7201:flywheel.publisher.registry.publishers
    struct RegistryStorage {
        /// @dev Mapping of ref codes to publishers
        mapping(string refCode => Publisher publisher) publishers;
    }

    /// @notice Default length of new permissionless referral codes
    uint256 public constant REF_CODE_LENGTH = 8;

    /// @notice Role identifier for addresses authorized to call registerPublisherCustom
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /// @notice EIP-1967 storage slot base for publishers mapping
    /// @dev keccak256("flywheel.publisher.registry.publishers") - 1
    bytes32 private constant REGISTRY_STORAGE_LOCATION =
        0x3456789012cdef013456789012cdef013456789012cdef013456789012cdef01;

    /// @notice Counter for generating unique publisher referral codes
    uint256 public nextPublisherNonce = 1;

    /// @notice Emitted when a new publisher is registered
    ///
    /// @param owner Address that controls the publisher
    /// @param defaultPayout Default payout address for all chains
    /// @param refCode Referral code for the publisher
    /// @param metadataUrl URL containing metadata info
    /// @param isCustom Whether the publisher was registered with a custom ref code
    event PublisherRegistered(
        address indexed owner, address indexed defaultPayout, string refCode, string metadataUrl, bool isCustom
    );

    /// @notice Emitted when a publisher's owner is updated
    ///
    /// @param refCode Referral code for the publisher
    /// @param newOwner New owner address
    event UpdatedPublisherOwner(string refCode, address newOwner);

    /// @notice Emitted when a publisher's metadata URL is updated
    ///
    /// @param refCode Referral code for the publisher
    /// @param metadataUrl New URL containing metadata info
    event UpdateMetadataUrl(string refCode, string metadataUrl);

    /// @notice Emitted when a publisher's default payout address is updated
    ///
    /// @param refCode Referral code for the publisher
    /// @param payoutAddress New default payout address for all chains
    event UpdatePublisherDefaultPayoutAddress(string refCode, address payoutAddress);

    /// @notice Thrown when caller doesn't have required permissions
    error Unauthorized();

    /// @notice Thrown when ref code is already taken
    error RefCodeAlreadyTaken();

    /// @notice Thrown when trying to renounce ownership (disabled for security)
    error OwnershipRenunciationDisabled();

    /// @notice Thrown when provided address is invalid (usually zero address)
    error InvalidAddress();

    /// @notice Ensures caller is the owner of the specified publisher
    ///
    /// @param _refCode Ref code of the publisher to validate
    modifier onlyPublisher(string memory _refCode) {
        if (_getRegistryStorage().publishers[_refCode].owner != msg.sender) revert Unauthorized();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract (replaces constructor)
    ///
    /// @param _owner Address that will own the contract
    /// @param _signer Address to grant SIGNER_ROLE (can be address(0) to skip)
    function initialize(address _owner, address _signer) external initializer {
        if (_owner == address(0)) revert InvalidAddress();

        __AccessControl_init();
        __Ownable2Step_init();
        _transferOwnership(_owner);
        __UUPSUpgradeable_init();

        if (_signer != address(0)) _grantRole(SIGNER_ROLE, _signer);
    }

    /// @notice Registers a new publisher in the system
    ///
    /// @param _metadataUrl URL containing publisher's metadata
    /// @param _defaultPayout Default payout address for all chains
    function registerPublisher(string memory _metadataUrl, address _defaultPayout)
        external
        returns (string memory refCode, uint256 publisherNonce)
    {
        // Generate unique ref code by looping until we find an unused one
        do {
            nextPublisherNonce++;
            refCode = getRefCode(nextPublisherNonce);
        } while (_getRegistryStorage().publishers[refCode].owner != address(0));

        _register(refCode, msg.sender, _metadataUrl, _defaultPayout);

        return (refCode, nextPublisherNonce);
    }

    /// @notice Registers a new publisher in the system with a custom ref code
    ///
    /// @param _refCode Custom ref code for the publisher
    /// @param _publisherOwner Owner of the publisher
    /// @param _metadataUrl URL containing publisher's metadata
    /// @param _defaultPayout Default payout address for all chains
    function registerPublisherCustom(
        string memory _refCode,
        address _publisherOwner,
        string memory _metadataUrl,
        address _defaultPayout
    ) external {
        // Check sender is signer (owner has all roles)
        _checkRole(SIGNER_ROLE, msg.sender);

        _register(_refCode, _publisherOwner, _metadataUrl, _defaultPayout);
    }

    /// @notice Updates the owner of a publisher
    ///
    /// @param _refCode ID of the publisher to update
    /// @param _newOwner New owner address
    /// @dev Only callable by current publisher owner
    function updatePublisherOwner(string memory _refCode, address _newOwner) external onlyPublisher(_refCode) {
        if (_newOwner == address(0)) revert InvalidAddress();
        _getRegistryStorage().publishers[_refCode].owner = _newOwner;
        emit UpdatedPublisherOwner(_refCode, _newOwner);
    }

    /// @notice Updates the inventory dimensions URL for a publisher
    ///
    /// @param _refCode ID of the publisher to update
    /// @param _metadataUrl New URL containing inventory dimensions
    /// @dev Only callable by publisher owner
    function updateMetadataUrl(string memory _refCode, string memory _metadataUrl) external onlyPublisher(_refCode) {
        _getRegistryStorage().publishers[_refCode].metadataUrl = _metadataUrl;
        emit UpdateMetadataUrl(_refCode, _metadataUrl);
    }

    /// @notice Updates the default payout address for a publisher
    ///
    /// @param _refCode ID of the publisher to update
    /// @param _newDefaultPayoutAddress New default payout address
    /// @dev Only callable by publisher owner
    function updatePublisherDefaultPayout(string memory _refCode, address _newDefaultPayoutAddress)
        external
        onlyPublisher(_refCode)
    {
        _getRegistryStorage().publishers[_refCode].defaultPayout = _newDefaultPayoutAddress;
        emit UpdatePublisherDefaultPayoutAddress(_refCode, _newDefaultPayoutAddress);
    }

    /// @notice Gets the publisher data
    ///
    /// @param _refCode Ref code of the publisher
    /// @return owner Owner of the publisher
    ///
    /// @return metadataUrl Metadata URL of the publisher
    /// @return defaultPayout Default payout address of the publisher
    function publishers(string memory _refCode) external view returns (address, string memory, address) {
        Publisher memory publisher = _getRegistryStorage().publishers[_refCode];
        return (publisher.owner, publisher.metadataUrl, publisher.defaultPayout);
    }

    /// @notice Gets the default payout address for a publisher
    ///
    /// @param _refCode Ref code of the publisher
    ///
    /// @return The default payout address
    function getPublisherPayoutAddress(string memory _refCode) external view returns (address) {
        return _getRegistryStorage().publishers[_refCode].defaultPayout;
    }

    /// @notice Checks if a publisher exists
    ///
    /// @param _refCode Ref code of the publisher to check
    ///
    /// @return True if the publisher exists
    function publisherExists(string memory _refCode) external view returns (bool) {
        return _getRegistryStorage().publishers[_refCode].owner != address(0);
    }

    /// @notice Checks if an address has a role
    ///
    /// @param role The role to check
    /// @param account The address to check
    ///
    /// @return True if the address has the role
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return account == owner() || super.hasRole(role, account);
    }

    /// @notice Generates a unique ref code for a publisher
    ///
    /// @param _publisherNonce Nonce of the publisher
    ///
    /// @return refCode Referral code for the publisher
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

    /// @notice Disabled to prevent accidental ownership renunciation
    ///
    /// @dev Overrides OpenZeppelin's renounceOwnership to prevent accidental calls
    function renounceOwnership() public pure override {
        revert OwnershipRenunciationDisabled();
    }

    /// @notice Registers a new publisher
    ///
    /// @param _refCode Ref code of the publisher
    /// @param _publisherOwner Owner of the publisher
    /// @param _metadataUrl URL containing publisher's metadata
    /// @param _defaultPayout Default payout address for all chains
    function _register(
        string memory _refCode,
        address _publisherOwner,
        string memory _metadataUrl,
        address _defaultPayout
    ) internal {
        // Validate addresses
        if (_publisherOwner == address(0) || _defaultPayout == address(0)) revert InvalidAddress();

        // Check if ref code is already taken
        Publisher storage publisher = _getRegistryStorage().publishers[_refCode];
        if (publisher.owner != address(0)) revert RefCodeAlreadyTaken();

        publisher.owner = _publisherOwner;
        publisher.metadataUrl = _metadataUrl;
        publisher.defaultPayout = _defaultPayout;
        emit PublisherRegistered(_publisherOwner, _defaultPayout, _refCode, _metadataUrl, true);
    }

    /// @notice Authorization for upgrades
    ///
    /// @param newImplementation Address of new implementation
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {}

    /// @notice Gets the storage reference for the registry
    ///
    /// @return $ Storage reference for the registry
    function _getRegistryStorage() private pure returns (RegistryStorage storage $) {
        assembly {
            $.slot := REGISTRY_STORAGE_LOCATION
        }
    }
}

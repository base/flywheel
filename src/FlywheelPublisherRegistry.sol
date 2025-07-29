// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

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

/// @notice Emitted when the signer address is updated
event UpdateSignerAddress(address indexed signerAddress);

/// @notice Registry for publishers in the Flywheel Protocol
/// @dev Manages publisher registration and payout address management
contract FlywheelPublisherRegistry is Initializable, UUPSUpgradeable, Ownable2StepUpgradeable {
    /// @notice Counter for generating unique publisher ref codes
    uint256 public nextPublisherNonce = 1;
    uint256 private constant REF_CODE_LENGTH = 8;

    /// @notice Address authorized to call registerPublisherCustom
    address public signerAddress;

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
    /// @param _signerAddress Address authorized to call registerPublisherCustom
    function initialize(address _owner, address _signerAddress) external initializer {
        if (_owner == address(0)) {
            revert InvalidAddress();
        }

        __Ownable2Step_init();
        // Transfer ownership to the provided owner address
        _transferOwnership(_owner);
        __UUPSUpgradeable_init();

        // Set signer address (can be address(0) if not using signer)
        signerAddress = _signerAddress;
        if (_signerAddress != address(0)) {
            emit UpdateSignerAddress(_signerAddress);
        }
    }

    /// @notice Ensures caller is the owner of the specified publisher
    /// @param _refCode Ref code of the publisher to validate
    modifier onlyPublisher(string memory _refCode) {
        if (publishers[_refCode].owner != msg.sender) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Ensures caller is either the owner or authorized signer
    modifier onlyOwnerOrSigner() {
        bool isOwner = msg.sender == owner();
        bool isSigner = msg.sender == signerAddress;

        if (!isOwner && !isSigner) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Updates the signer address
    /// @param _newSignerAddress New signer address (can be address(0) to disable)
    function updateSignerAddress(address _newSignerAddress) external onlyOwner {
        signerAddress = _newSignerAddress;
        emit UpdateSignerAddress(_newSignerAddress);
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

        uint256 overridePayoutsLength = _overridePayouts.length;
        for (uint256 i; i < overridePayoutsLength; i++) {
            publishers[refCode].overridePayouts[uint256(_overridePayouts[i].chainId)] =
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
        // check if ref code is already taken
        if (publishers[_refCode].owner != address(0)) {
            revert RefCodeAlreadyTaken();
        }

        if (_publisherOwner == address(0) || _defaultPayout == address(0)) {
            revert InvalidAddress();
        }

        // validate ref code uniqueness
        publishers[_refCode].owner = _publisherOwner;
        publishers[_refCode].metadataUrl = _metadataUrl;
        publishers[_refCode].defaultPayout = _defaultPayout;

        uint256 overridePayoutsLength = _overridePayouts.length;
        for (uint256 i; i < overridePayoutsLength; i++) {
            publishers[_refCode].overridePayouts[uint256(_overridePayouts[i].chainId)] =
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
    function updatePublisherDefaultPayout(string memory _refCode, address _newDefaultPayoutAddress)
        external
        onlyPublisher(_refCode)
    {
        publishers[_refCode].defaultPayout = _newDefaultPayoutAddress;

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
        publishers[_refCode].overridePayouts[_chainId] = _newPayoutAddress;

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
        return publishers[_refCode].overridePayouts[_chainId];
    }

    /// @notice Gets the default payout address for a publisher
    /// @param _refCode Ref code of the publisher
    /// @return The default payout address
    function getPublisherDefaultPayoutAddress(string memory _refCode) external view returns (address) {
        return publishers[_refCode].defaultPayout;
    }

    function getPublisherPayoutAddress(string memory _refCode, uint256 _chainId) external view returns (address) {
        return publishers[_refCode].overridePayouts[_chainId] != address(0)
            ? publishers[_refCode].overridePayouts[_chainId]
            : publishers[_refCode].defaultPayout;
    }

    /// @notice Checks if a publisher exists
    /// @param _refCode Ref code of the publisher to check
    /// @return True if the publisher exists
    function publisherExists(string memory _refCode) external view returns (bool) {
        return publishers[_refCode].owner != address(0);
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
        } while (publishers[refCode].owner != address(0));

        return refCode;
    }
}

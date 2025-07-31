// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice Registry for referral code records in the Flywheel Protocol
///
/// @dev Manages referral code registration and payout address management
///
/// @author Coinbase
contract ReferralCodeRegistry is Initializable, AccessControlUpgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
    /// @notice EIP-712 storage structure for registry data
    /// @custom:storage-location erc7201:base.flywheel.ReferralCodeRegistry
    struct RegistryStorage {
        /// @dev Nonce for generating unique referral codes
        uint256 nonce;
        /// @dev Mapping of ref codes to owners
        mapping(string refCode => address owner) owners;
        /// @dev Mapping of ref codes to payout recipients
        mapping(string refCode => address payoutRecipient) payoutRecipients;
        /// @dev Mapping of ref codes to metadata URLs
        mapping(string refCode => string metadataUrl) metadataUrls;
    }

    /// @notice Default length of new permissionless referral codes
    uint256 public constant REF_CODE_LENGTH = 8;

    /// @notice Role identifier for addresses authorized to call registerCustom
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /// @notice EIP-1967 storage slot base for registry mapping using ERC-7201
    /// @dev keccak256(abi.encode(uint256(keccak256("base.flywheel.ReferralCodeRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REGISTRY_STORAGE_LOCATION =
        0x6e7d4431538d420f63c9bb71a8a04d60eb7d1fab71f40fdd3a613396b82ec300;

    /// @notice Emitted when a new referral code is registered
    ///
    /// @param owner Address that controls the publisher
    /// @param payoutRecipient Default payout address for all chains
    /// @param refCode Referral code for the publisher
    /// @param metadataUrl URL containing metadata info
    /// @param isCustom Whether the publisher was registered with a custom ref code
    event ReferralCodeRegistered(
        string refCode, address indexed owner, address indexed payoutRecipient, string metadataUrl, bool isCustom
    );

    /// @notice Emitted when a publisher's owner is updated
    ///
    /// @param refCode Referral code for the publisher
    /// @param newOwner New owner address
    event ReferralCodeOwnerUpdated(string refCode, address newOwner);

    /// @notice Emitted when a publisher's metadata URL is updated
    ///
    /// @param refCode Referral code for the publisher
    /// @param metadataUrl New URL containing metadata info
    event ReferralCodeMetadataUrlUpdated(string refCode, string metadataUrl);

    /// @notice Emitted when a publisher's default payout address is updated
    ///
    /// @param refCode Referral code for the publisher
    /// @param payoutAddress New default payout address for all chains
    event ReferralCodePayoutRecipientUpdated(string refCode, address payoutAddress);

    /// @notice Thrown when caller doesn't have required permissions
    error Unauthorized();

    /// @notice Thrown when provided address is invalid (usually zero address)
    error ZeroAddress();

    /// @notice Thrown when referral code is not registered
    error Unregistered();

    /// @notice Thrown when referral code is already registered
    error AlreadyRegistered();

    /// @notice Thrown when trying to renounce ownership (disabled for security)
    error OwnershipRenunciationDisabled();

    /// @notice Ensures caller is the owner of the specified referral code
    ///
    /// @param refCode Ref code of the referral code to validate
    modifier onlyRefCodeOwner(string memory refCode) {
        address owner = _getRegistryStorage().owners[refCode];
        if (owner == address(0)) revert Unregistered();
        if (owner != msg.sender) revert Unauthorized();
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
        if (_owner == address(0)) revert ZeroAddress();

        __AccessControl_init();
        __Ownable2Step_init();
        _transferOwnership(_owner);
        __UUPSUpgradeable_init();

        if (_signer != address(0)) _grantRole(SIGNER_ROLE, _signer);
    }

    /// @notice Registers a new referral code in the system
    ///
    /// @param payoutRecipient Default payout address for all chains
    /// @param metadataUrl URL containing referral code's metadata
    function register(address payoutRecipient, string memory metadataUrl) external returns (string memory refCode) {
        // Generate unique referral code by looping until we find an unused one
        do {
            refCode = computeReferralCode(++_getRegistryStorage().nonce);
        } while (isReferralCodeRegistered(refCode));

        _register(refCode, msg.sender, payoutRecipient, metadataUrl, false);
    }

    /// @notice Registers a new referral code in the system with a custom value
    ///
    /// @param refCode Custom ref code for the referral code
    /// @param refCodeOwner Owner of the ref code
    /// @param metadataUrl URL containing referral code's metadata
    /// @param payoutRecipient Default payout address for all chains
    function registerCustom(
        string memory refCode,
        address refCodeOwner,
        address payoutRecipient,
        string memory metadataUrl
    ) external onlyRole(SIGNER_ROLE) {
        _register(refCode, refCodeOwner, payoutRecipient, metadataUrl, true);
    }

    /// @notice Updates the owner of a referral code
    ///
    /// @param refCode ID of the referral code to update
    /// @param newOwner New owner address
    /// @dev Only callable by current referral code owner
    function updateOwner(string memory refCode, address newOwner) external onlyRefCodeOwner(refCode) {
        if (newOwner == address(0)) revert ZeroAddress();
        _getRegistryStorage().owners[refCode] = newOwner;
        emit ReferralCodeOwnerUpdated(refCode, newOwner);
    }

    /// @notice Updates the default payout address for a referral code
    ///
    /// @param refCode ID of the referral code to update
    /// @param payoutRecipient New default payout address
    /// @dev Only callable by referral code owner
    function updatePayoutRecipient(string memory refCode, address payoutRecipient) external onlyRefCodeOwner(refCode) {
        if (payoutRecipient == address(0)) revert ZeroAddress();
        _getRegistryStorage().payoutRecipients[refCode] = payoutRecipient;
        emit ReferralCodePayoutRecipientUpdated(refCode, payoutRecipient);
    }

    /// @notice Updates the metadata URL for a referral code
    ///
    /// @param refCode ID of the referral code to update
    /// @param metadataUrl New URL containing inventory dimensions
    /// @dev Only callable by referral code owner
    function updateMetadataUrl(string memory refCode, string memory metadataUrl) external onlyRefCodeOwner(refCode) {
        _getRegistryStorage().metadataUrls[refCode] = metadataUrl;
        emit ReferralCodeMetadataUrlUpdated(refCode, metadataUrl);
    }

    /// @notice Gets the owner of a referral code
    ///
    /// @param refCode Ref code of the referral code
    ///
    /// @return The owner of the referral code
    function getOwner(string memory refCode) external view returns (address) {
        if (!isReferralCodeRegistered(refCode)) revert Unregistered();
        return _getRegistryStorage().owners[refCode];
    }

    /// @notice Gets the default payout address for a referral code
    ///
    /// @param refCode Ref code of the referral code
    ///
    /// @return The default payout address
    function getPayoutRecipient(string memory refCode) external view returns (address) {
        if (!isReferralCodeRegistered(refCode)) revert Unregistered();
        return _getRegistryStorage().payoutRecipients[refCode];
    }

    /// @notice Gets the metadata URL for a referral code
    ///
    /// @param refCode Ref code of the referral code
    ///
    /// @return The metadata URL for the referral code
    function getMetadataUrl(string memory refCode) external view returns (string memory) {
        if (!isReferralCodeRegistered(refCode)) revert Unregistered();
        return _getRegistryStorage().metadataUrls[refCode];
    }

    /// @notice Gets the nonce for the registry
    ///
    /// @return The nonce for the registry
    function nonce() public view returns (uint256) {
        return _getRegistryStorage().nonce;
    }

    /// @notice Checks if a referral code exists
    ///
    /// @param refCode Ref code of the referral code to check
    ///
    /// @return True if the referral code exists
    function isReferralCodeRegistered(string memory refCode) public view returns (bool) {
        return _getRegistryStorage().owners[refCode] != address(0);
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

    /// @notice Generates a unique ref code for a referral code
    ///
    /// @param nonceValue Nonce value to generate a ref code from
    ///
    /// @return refCode Referral code for the referral code
    function computeReferralCode(uint256 nonceValue) public pure returns (string memory) {
        bytes32 hash = keccak256(abi.encodePacked(nonceValue));
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

    /// @notice Registers a new referral code
    ///
    /// @param refCode Ref code of the referral code
    /// @param refCodeOwner Owner of the referral code
    /// @param metadataUrl URL containing referral code's metadata
    /// @param payoutRecipient Default payout address for all chains
    function _register(
        string memory refCode,
        address refCodeOwner,
        address payoutRecipient,
        string memory metadataUrl,
        bool isCustom
    ) internal {
        // Validate addresses
        if (refCodeOwner == address(0) || payoutRecipient == address(0)) revert ZeroAddress();

        // Check if ref code is already taken
        if (isReferralCodeRegistered(refCode)) revert AlreadyRegistered();

        RegistryStorage storage $ = _getRegistryStorage();
        $.owners[refCode] = refCodeOwner;
        $.payoutRecipients[refCode] = payoutRecipient;
        $.metadataUrls[refCode] = metadataUrl;
        emit ReferralCodeRegistered(refCode, refCodeOwner, payoutRecipient, metadataUrl, isCustom);
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

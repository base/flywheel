// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {TokenStore} from "./TokenStore.sol";
import {CampaignHooks} from "./CampaignHooks.sol";

/// @title Flywheel
///
/// @notice Main contract for managing advertising campaigns and attribution
///
/// @dev Handles campaign lifecycle, attribution, and token distribution
contract Flywheel {
    /// @notice Possible states a campaign can be in
    enum CampaignStatus {
        CREATED, // Initial state when campaign is first created
        OPEN, // Campaign is live and can accept attribution
        PAUSED, // Campaign is temporarily paused
        CLOSED, // Campaign is no longer live but can still accept lagging attribution
        FINALIZED // Campaign attribution is complete

    }

    /// @notice Campaign information structure
    struct CampaignInfo {
        /// @dev status Current status of the campaign
        CampaignStatus status;
        /// @dev hooks Address of the campaign hooks contract
        address hooks;
    }

    /// @notice Payout structure for attribution rewards
    struct Payout {
        /// @dev recipient Address receiving the payout
        address recipient;
        /// @dev amount Amount of tokens to be paid out
        uint256 amount;
    }

    /// @notice Implementation address for TokenStore contracts
    address public immutable tokenStoreImpl;

    /// @notice Mapping from token address to recipient address to payout amount
    mapping(address token => mapping(address recipient => uint256 amount)) public payouts;

    /// @notice Collectible fees
    mapping(address token => mapping(address recipient => uint256 amount)) public fees;

    /// @notice Mapping from campaign address to campaign information
    mapping(address campaign => CampaignInfo) internal _campaigns;

    /// @notice Emitted when a new campaign is created
    ///
    /// @param campaign Address of the created campaign
    /// @param hooks Address of the campaign hooks contract
    event CampaignCreated(address indexed campaign, address hooks);

    /// @notice Emitted when a campaign is updated
    ///
    /// @param campaign Address of the campaign
    /// @param uri The URI for the campaign
    event CampaignMetadataUpdated(address indexed campaign, string uri);

    /// @notice Emitted when a campaign status is updated
    ///
    /// @param campaign Address of the campaign
    /// @param sender Address that triggered the status change
    /// @param oldStatus Previous status of the campaign
    /// @param newStatus New status of the campaign
    event CampaignStatusUpdated(
        address indexed campaign, address sender, CampaignStatus oldStatus, CampaignStatus newStatus
    );

    /// @notice Emitted when a payout is allocated to a recipient
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the payout token
    /// @param recipient Address receiving the payout
    /// @param amount Amount of tokens allocated
    event PayoutAllocated(address indexed campaign, address token, address recipient, uint256 amount);

    /// @notice Emitted when a fee is allocated to a recipient
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the payout token
    /// @param recipient Address of the recipient
    /// @param amount Amount of tokens allocated
    event FeeAllocated(address indexed campaign, address token, address recipient, uint256 amount);

    /// @notice Emitted when someone withdraws funding from a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the withdrawn token
    /// @param amount Amount of tokens withdrawn
    event FundsWithdrawn(address indexed campaign, address token, address withdrawer, uint256 amount);

    /// @notice Emitted when accumulated balance is distributed to a recipient
    ///
    /// @param recipient Address receiving the distribution
    /// @param token Address of the distributed token
    /// @param amount Amount of tokens distributed
    event PayoutsDistributed(address token, address recipient, uint256 amount);

    /// @notice Emitted when accumulated fees are collected
    ///
    /// @param token Address of the collected token
    /// @param recipient Address of the recipient
    /// @param amount Amount of tokens collected
    event FeesCollected(address token, address recipient, uint256 amount);

    /// @notice Thrown when campaign does not exist
    error CampaignDoesNotExist();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when campaign is in invalid status for operation
    error InvalidCampaignStatus();

    /// @notice Modifier to check if a campaign exists
    ///
    /// @param campaign Address of the campaign
    modifier campaignExists(address campaign) {
        if (_campaigns[campaign].hooks == address(0)) revert CampaignDoesNotExist();
        _;
    }

    /// @notice Constructor for the Flywheel contract
    ///
    /// @dev Deploys a new TokenStore implementation for cloning
    constructor() {
        tokenStoreImpl = address(new TokenStore());
    }

    /// @notice Creates a new campaign
    ///
    /// @param hooks Address of the campaign hooks contract
    /// @param nonce Nonce used to create the campaign
    /// @param hookData Data for the campaign hook
    ///
    /// @return campaign Address of the newly created campaign
    ///
    /// @dev Clones a new TokenStore contract for the campaign
    /// @dev Call `campaignAddress` to know the address of the campaign without deploying it
    function createCampaign(address hooks, uint256 nonce, bytes calldata hookData)
        external
        returns (address campaign)
    {
        if (hooks == address(0)) revert ZeroAddress();
        campaign = Clones.cloneDeterministic(tokenStoreImpl, keccak256(abi.encode(nonce, hookData)));
        _campaigns[campaign] = CampaignInfo({status: CampaignStatus.CREATED, hooks: hooks});
        emit CampaignCreated(campaign, hooks);
        CampaignHooks(hooks).onCreateCampaign(campaign, hookData);
    }

    /// @notice Updates the metadata for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param hookData Data for the campaign hook
    ///
    /// @dev Indexers should update their metadata cache for this campaign by fetching the campaignURI
    function updateMetadata(address campaign, bytes calldata hookData) external campaignExists(campaign) {
        if (_campaigns[campaign].status == CampaignStatus.FINALIZED) revert InvalidCampaignStatus();
        CampaignHooks(_campaigns[campaign].hooks).onUpdateMetadata(msg.sender, campaign, hookData);
        emit CampaignMetadataUpdated(campaign, campaignURI(campaign));
    }

    /// @notice Updates the status of a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param newStatus New status of the campaign
    /// @param hookData Data for the campaign hook
    function updateStatus(address campaign, CampaignStatus newStatus, bytes calldata hookData)
        external
        campaignExists(campaign)
    {
        CampaignStatus oldStatus = _campaigns[campaign].status;

        // Check new and old status are different
        if (newStatus == oldStatus) revert InvalidCampaignStatus();

        // Cannot go back to created status
        if (newStatus == CampaignStatus.CREATED) revert InvalidCampaignStatus();

        // Finalized status cannot change
        if (oldStatus == CampaignStatus.FINALIZED) revert InvalidCampaignStatus();

        // Closed can only move to finalized
        if (oldStatus == CampaignStatus.CLOSED && newStatus != CampaignStatus.FINALIZED) revert InvalidCampaignStatus();

        // Apply hook for access control and storage updates
        CampaignHooks(_campaigns[campaign].hooks).onUpdateStatus(msg.sender, campaign, oldStatus, newStatus, hookData);

        // Update status
        _campaigns[campaign].status = newStatus;
        emit CampaignStatusUpdated(campaign, msg.sender, oldStatus, newStatus);
    }

    /// @notice Processes attribution for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param payoutToken Address of the token to be distributed
    /// @param hookData Data for the campaign hook
    function allocate(address campaign, address payoutToken, bytes calldata hookData)
        external
        campaignExists(campaign)
    {
        // Check campaign allows attribution (OPEN, PAUSED, or CLOSED)
        CampaignStatus status = _campaigns[campaign].status;
        if (status == CampaignStatus.CREATED || status == CampaignStatus.FINALIZED) revert InvalidCampaignStatus();

        (Payout[] memory newPayouts, uint256 fee) =
            CampaignHooks(_campaigns[campaign].hooks).onAllocate(msg.sender, campaign, payoutToken, hookData);

        // Add new payouts
        uint256 totalPayouts = 0;
        for (uint256 i = 0; i < newPayouts.length; i++) {
            address recipient = newPayouts[i].recipient;
            uint256 amount = newPayouts[i].amount;
            payouts[payoutToken][recipient] += amount;
            totalPayouts += amount;
            emit PayoutAllocated(campaign, payoutToken, recipient, amount);
        }

        // Add attribution fee
        fees[payoutToken][msg.sender] += fee;
        emit FeeAllocated(campaign, payoutToken, msg.sender, fee);

        // Transfer tokens to Flywheel to reserve for payouts and fees
        TokenStore(campaign).sendTokens(payoutToken, address(this), totalPayouts + fee);
    }

    /// @notice Allows sponsor to withdraw remaining tokens from a finalized campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the token to withdraw
    /// @param hookData Data for the campaign hook
    function withdrawFunds(address campaign, address token, uint256 amount, bytes calldata hookData)
        external
        campaignExists(campaign)
    {
        CampaignHooks(_campaigns[campaign].hooks).onWithdrawFunds(msg.sender, campaign, token, amount, hookData);
        TokenStore(campaign).sendTokens(token, msg.sender, amount);
        emit FundsWithdrawn(campaign, token, msg.sender, amount);
    }

    /// @notice Distributes accumulated balance to a recipient
    ///
    /// @param token Address of the token to distribute
    /// @param recipient Address of the recipient
    ///
    /// @dev Transfers the full balance for the token-recipient pair and resets it to zero
    function distributePayouts(address token, address recipient) external {
        uint256 balance = payouts[token][recipient];
        delete payouts[token][recipient];
        SafeERC20.safeTransfer(IERC20(token), recipient, balance);
        emit PayoutsDistributed(token, recipient, balance);
    }

    /// @notice Collects fees from a campaign
    ///
    /// @param token Address of the token to collect fees from
    /// @param recipient Address of the recipient to collect fees to
    function collectFees(address token, address recipient) external {
        uint256 amount = fees[token][msg.sender];
        delete fees[token][msg.sender];
        SafeERC20.safeTransfer(IERC20(token), recipient, amount);
        emit FeesCollected(token, msg.sender, amount);
    }

    /// @notice Returns the address of a campaign given its creation parameters
    ///
    /// @param nonce Nonce used to create the campaign
    /// @param hookData Data for the campaign hook
    ///
    /// @return campaign Address of the campaign
    function campaignAddress(uint256 nonce, bytes calldata hookData) external view returns (address campaign) {
        return Clones.predictDeterministicAddress(tokenStoreImpl, keccak256(abi.encode(nonce, hookData)));
    }

    /// @notice Returns the URI for a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return uri The URI for the campaign
    function campaignURI(address campaign) public view campaignExists(campaign) returns (string memory uri) {
        return CampaignHooks(_campaigns[campaign].hooks).campaignURI(campaign);
    }

    /// @notice Returns the status of a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return status of the campaign
    function campaignStatus(address campaign) public view campaignExists(campaign) returns (CampaignStatus status) {
        return _campaigns[campaign].status;
    }

    /// @notice Returns the hooks of a campaign
    ///
    /// @param campaign Address of the campaign
    ///
    /// @return hooks of the campaign
    function campaignHooks(address campaign) public view campaignExists(campaign) returns (address hooks) {
        return _campaigns[campaign].hooks;
    }
}

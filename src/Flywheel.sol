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
/// @dev Structures campaign metadata, lifecycle, payouts, and fees
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
        CampaignHooks hooks;
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

    /// @notice Allocated rewards that are pending distribution
    mapping(address campaign => mapping(address token => mapping(address recipient => uint256 amount))) public
        allocations;

    /// @notice Fees that are pending collection
    mapping(address campaign => mapping(address token => mapping(address recipient => uint256 amount))) public fees;

    /// @notice Total funds reserved for allocations and fees for a campaign
    mapping(address campaign => mapping(address token => uint256 amount)) public totalReserved;

    /// @notice Campaign state
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

    /// @notice Emitted when a payout is rewarded to a recipient
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the payout token
    /// @param recipient Address receiving the payout
    /// @param amount Amount of tokens rewarded
    event PayoutRewarded(address indexed campaign, address token, address recipient, uint256 amount);

    /// @notice Emitted when a payout is allocated to a recipient
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the payout token
    /// @param recipient Address receiving the payout
    /// @param amount Amount of tokens allocated
    event PayoutAllocated(address indexed campaign, address token, address recipient, uint256 amount);

    /// @notice Emitted when allocated payouts are distributed to a recipient
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the payout token
    /// @param recipient Address receiving the distribution
    /// @param amount Amount of tokens distributed
    event PayoutsDistributed(address indexed campaign, address token, address recipient, uint256 amount);

    /// @notice Emitted when allocated payouts are deallocated from a recipient
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the payout token
    /// @param recipient Address receiving the deallocation
    /// @param amount Amount of tokens deallocated
    event PayoutsDeallocated(address indexed campaign, address token, address recipient, uint256 amount);

    /// @notice Emitted when a fee is allocated to a recipient
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the payout token
    /// @param recipient Address of the recipient
    /// @param amount Amount of tokens allocated
    event FeeAllocated(address indexed campaign, address token, address recipient, uint256 amount);

    /// @notice Emitted when accumulated fees are collected
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the collected token
    /// @param recipient Address of the recipient
    /// @param amount Amount of tokens collected
    event FeesCollected(address indexed campaign, address token, address recipient, uint256 amount);

    /// @notice Emitted when someone withdraws funding from a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the withdrawn token
    /// @param amount Amount of tokens withdrawn
    event FundsWithdrawn(address indexed campaign, address token, address withdrawer, uint256 amount);

    /// @notice Thrown when campaign does not exist
    error CampaignDoesNotExist();

    /// @notice Thrown when campaign is in invalid status for operation
    error InvalidCampaignStatus();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when campaign does not have enough balance for an operation
    error InsufficientCampaignFunds();

    /// @notice Check if a campaign exists
    ///
    /// @param campaign Address of the campaign
    modifier campaignExists(address campaign) {
        if (address(_campaigns[campaign].hooks) == address(0)) revert CampaignDoesNotExist();
        _;
    }

    /// @notice Check if a campaign's status allows payouts
    ///
    /// @param campaign Address of the campaign
    modifier acceptingPayouts(address campaign) {
        CampaignStatus status = _campaigns[campaign].status;
        if (status == CampaignStatus.CREATED || status == CampaignStatus.FINALIZED) revert InvalidCampaignStatus();
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
        _campaigns[campaign] = CampaignInfo({status: CampaignStatus.CREATED, hooks: CampaignHooks(hooks)});
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
        _campaigns[campaign].hooks.onUpdateMetadata(msg.sender, campaign, hookData);
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
        if (
            newStatus == oldStatus // must be different
                || newStatus == CampaignStatus.CREATED // cannot go back to created
                || oldStatus == CampaignStatus.FINALIZED // cannot change finalized
                || (oldStatus == CampaignStatus.CLOSED && newStatus != CampaignStatus.FINALIZED) // closed can only move to finalized
        ) revert InvalidCampaignStatus();

        _campaigns[campaign].hooks.onUpdateStatus(msg.sender, campaign, oldStatus, newStatus, hookData);
        _campaigns[campaign].status = newStatus;
        emit CampaignStatusUpdated(campaign, msg.sender, oldStatus, newStatus);
    }

    /// @notice Rewards a recipient with an immediate payout for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the token to reward
    /// @param hookData Data for the campaign hook
    function reward(address campaign, address token, bytes calldata hookData)
        external
        acceptingPayouts(campaign)
        returns (Payout[] memory payouts, uint256 fee)
    {
        (payouts, fee) = _campaigns[campaign].hooks.onReward(msg.sender, campaign, token, hookData);

        _allocateFee(campaign, token, fee);
        uint256 totalPayouts = _sumAmounts(payouts);
        uint256 reserved = _canReserve(campaign, token, totalPayouts + fee);

        totalReserved[campaign][token] = reserved + fee;
        for (uint256 i = 0; i < payouts.length; i++) {
            (address recipient, uint256 amount) = (payouts[i].recipient, payouts[i].amount);
            TokenStore(campaign).sendTokens(token, recipient, amount);
            emit PayoutRewarded(campaign, token, recipient, amount);
        }
    }

    /// @notice Allocates payouts to a recipient for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the token to be distributed
    /// @param hookData Data for the campaign hook
    ///
    /// @dev Allocated payouts are transferred to recipients on `distribute`
    function allocate(address campaign, address token, bytes calldata hookData)
        external
        campaignExists(campaign)
        acceptingPayouts(campaign)
        returns (Payout[] memory payouts, uint256 fee)
    {
        (payouts, fee) = _campaigns[campaign].hooks.onAllocate(msg.sender, campaign, token, hookData);

        _allocateFee(campaign, token, fee);
        uint256 totalPayouts = _sumAmounts(payouts);
        uint256 reserved = _canReserve(campaign, token, totalPayouts + fee);

        totalReserved[campaign][token] = reserved + totalPayouts + fee;
        for (uint256 i = 0; i < payouts.length; i++) {
            (address recipient, uint256 amount) = (payouts[i].recipient, payouts[i].amount);
            allocations[campaign][token][recipient] += amount;
            emit PayoutAllocated(campaign, token, recipient, amount);
        }
    }

    /// @notice Distributes allocated payouts to a recipient for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the token to distribute
    /// @param hookData Data for the campaign hook
    ///
    /// @dev Payouts must first be allocated to a recipient before they can be distributed
    /// @dev Use `reward` for immediate payouts
    function distribute(address campaign, address token, bytes calldata hookData)
        external
        campaignExists(campaign)
        acceptingPayouts(campaign)
        returns (Payout[] memory payouts, uint256 fee)
    {
        (payouts, fee) = _campaigns[campaign].hooks.onDistribute(msg.sender, campaign, token, hookData);
        _allocateFee(campaign, token, fee);
        uint256 totalPayouts = _sumAmounts(payouts);

        totalReserved[campaign][token] = totalReserved[campaign][token] + fee - totalPayouts;
        for (uint256 i = 0; i < payouts.length; i++) {
            (address recipient, uint256 amount) = (payouts[i].recipient, payouts[i].amount);
            allocations[campaign][token][recipient] -= amount;
            TokenStore(campaign).sendTokens(token, recipient, amount);
            emit PayoutsDistributed(campaign, token, recipient, amount);
        }
    }

    /// @notice Deallocates allocated payouts from a recipient for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the token to deallocate
    /// @param hookData Data for the campaign hook
    function deallocate(address campaign, address token, bytes calldata hookData) external {
        Payout[] memory payouts = _campaigns[campaign].hooks.onDeallocate(msg.sender, campaign, token, hookData);

        totalReserved[campaign][token] -= _sumAmounts(payouts);
        for (uint256 i = 0; i < payouts.length; i++) {
            (address recipient, uint256 amount) = (payouts[i].recipient, payouts[i].amount);
            allocations[campaign][token][recipient] -= amount;
            emit PayoutsDeallocated(campaign, token, recipient, amount);
        }
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
        _canReserve(campaign, token, amount);
        _campaigns[campaign].hooks.onWithdrawFunds(msg.sender, campaign, token, amount, hookData);
        TokenStore(campaign).sendTokens(token, msg.sender, amount);
        emit FundsWithdrawn(campaign, token, msg.sender, amount);
    }

    /// @notice Collects fees from a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the token to collect fees from
    /// @param recipient Address of the recipient to collect fees to
    function collectFees(address campaign, address token, address recipient) external {
        uint256 amount = fees[campaign][token][msg.sender];
        delete fees[campaign][token][msg.sender];
        totalReserved[campaign][token] -= amount;
        TokenStore(campaign).sendTokens(token, recipient, amount);
        emit FeesCollected(campaign, token, msg.sender, amount);
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
        return _campaigns[campaign].hooks.campaignURI(campaign);
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
        return address(_campaigns[campaign].hooks);
    }

    /// @notice Allocates fees to a recipient for a campaign
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the payout token
    /// @param fee Amount of tokens to allocate
    ///
    /// @dev Fees are allocated to the recipient
    function _allocateFee(address campaign, address token, uint256 fee) internal {
        if (fee > 0) {
            fees[campaign][token][msg.sender] += fee;
            emit FeeAllocated(campaign, token, msg.sender, fee);
        }
    }

    /// @notice Checks if a campaign has sufficient balance for an operation
    ///
    /// @param campaign Address of the campaign
    /// @param token Address of the token to check balance of
    /// @param amount Amount of tokens to check balance of
    ///
    /// @dev Reverts if the campaign does not have sufficient balance
    function _canReserve(address campaign, address token, uint256 amount) internal view returns (uint256 reserved) {
        reserved = totalReserved[campaign][token];
        if (IERC20(token).balanceOf(campaign) < reserved + amount) revert InsufficientCampaignFunds();
    }

    /// @notice Sums the amounts of a list of payouts
    ///
    /// @param payouts List of payouts
    ///
    /// @return total Sum of the amounts of the payouts
    function _sumAmounts(Payout[] memory payouts) internal pure returns (uint256 total) {
        for (uint256 i = 0; i < payouts.length; i++) {
            total += payouts[i].amount;
        }
    }
}

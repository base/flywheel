// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BuilderCodes} from "builder-codes/BuilderCodes.sol";
import {LibString} from "solady/utils/LibString.sol";

import {CampaignHooks} from "../CampaignHooks.sol";
import {Flywheel} from "../Flywheel.sol";

/// @title BridgeRewards
///
/// @notice This contract is used to configure bridge rewards for Base builder codes. It is expected to be used in
///         conjunction with the BuilderCodes contract that manages codes registration. Once registered, this contract
///         allows the builder to start receiving rewards for each usage of the code during a bridge operation that
///         involves a transfer of tokens.
contract BridgeRewards is CampaignHooks {
    /// @notice ERC-7528 address for native token
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Maximum fee basis points
    uint16 public immutable MAX_FEE_BASIS_POINTS;

    /// @notice Address of the BuilderCodes contract
    BuilderCodes public immutable BUILDER_CODES;

    /// @notice URI prefix for the campaign
    string public uriPrefix;

    /// @notice Error thrown to enforce only one campaign can be initialized
    error InvalidCampaignInitialization();

    /// @notice Error thrown when the balance is zero
    error ZeroBridgedAmount();

    /// @notice Hooks constructor
    ///
    /// @param flywheel Address of the flywheel contract
    constructor(address flywheel, address builderCodes, string memory uriPrefix_, uint16 maxFeeBasisPoints)
        CampaignHooks(flywheel)
    {
        BUILDER_CODES = BuilderCodes(builderCodes);
        uriPrefix = uriPrefix_;
        MAX_FEE_BASIS_POINTS = maxFeeBasisPoints;
    }

    /// @inheritdoc CampaignHooks
    function campaignURI(address campaign) external view override returns (string memory uri) {
        return bytes(uriPrefix).length > 0 ? string.concat(uriPrefix, LibString.toHexStringChecksummed(campaign)) : "";
    }

    /// @inheritdoc CampaignHooks
    function _onCreateCampaign(address campaign, uint256 nonce, bytes calldata hookData) internal pure override {
        if (nonce != 0 || hookData.length > 0) revert InvalidCampaignInitialization();
    }

    /// @inheritdoc CampaignHooks
    function _onSend(address sender, address campaign, address token, bytes calldata hookData)
        internal
        view
        override
        returns (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow)
    {
        (address user, bytes32 code, uint16 feeBps) = abi.decode(hookData, (address, bytes32, uint16));

        // Calculate bridged amount as current balance minus total fees allocated and not yet sent
        uint256 bridgedAmount = token == NATIVE_TOKEN ? campaign.balance : IERC20(token).balanceOf(campaign);
        bridgedAmount -= FLYWHEEL.totalAllocatedFees(campaign, token);

        // Check bridged amount nonzero
        if (bridgedAmount == 0) revert ZeroBridgedAmount();

        // set feeBps to 0 if builder code not registered
        feeBps = BUILDER_CODES.isRegistered(BUILDER_CODES.toCode(uint256(code))) ? feeBps : 0;

        // set feeBps to MAX_FEE_BASIS_POINTS if feeBps exceeds MAX_FEE_BASIS_POINTS
        feeBps = feeBps > MAX_FEE_BASIS_POINTS ? MAX_FEE_BASIS_POINTS : feeBps;

        // Prepare payout
        uint256 feeAmount = (bridgedAmount * feeBps) / 1e4;
        payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: user,
            amount: bridgedAmount - feeAmount,
            extraData: abi.encode(code, feeAmount)
        });

        // Prepare fee if applicable
        if (feeAmount > 0) {
            sendFeesNow = true;
            fees = new Flywheel.Distribution[](1);
            fees[0] = Flywheel.Distribution({
                key: code, // allow fee send to fallback to builder code
                recipient: BUILDER_CODES.payoutAddress(uint256(code)), // if payoutAddress misconfigured, builder loses their fee
                amount: feeAmount,
                extraData: ""
            });
        }
    }

    /// @inheritdoc CampaignHooks
    ///
    /// @dev Will only need to use this function if the initial fee send fails
    function _onDistributeFees(address sender, address campaign, address token, bytes calldata hookData)
        internal
        view
        override
        returns (Flywheel.Distribution[] memory distributions)
    {
        bytes32 code = bytes32(hookData);
        distributions = new Flywheel.Distribution[](1);
        distributions[0] = Flywheel.Distribution({
            recipient: BUILDER_CODES.payoutAddress(uint256(code)),
            key: code,
            amount: FLYWHEEL.allocatedFee(campaign, token, code),
            extraData: ""
        });
    }

    /// @inheritdoc CampaignHooks
    function _onWithdrawFunds(address sender, address campaign, address token, bytes calldata hookData)
        internal
        pure
        override
        returns (Flywheel.Payout memory payout)
    {
        // Intended use is for funds to be sent into the campaign and atomically sent out to recipients
        // If tokens are sent into the campaign outside of this scope on accident, anyone can take them (no access control for `onSend` hook)
        // To keep the event feed clean for payouts/fees, we leave open the ability to withdraw funds directly
        // Those wishing to take accidental tokens left in the campaign should find this function easier
        payout = abi.decode(hookData, (Flywheel.Payout));
    }

    /// @inheritdoc CampaignHooks
    function _onUpdateStatus(
        address sender,
        address campaign,
        Flywheel.CampaignStatus oldStatus,
        Flywheel.CampaignStatus newStatus,
        bytes calldata hookData
    ) internal pure override {
        // This is a perpetual campaign, so it should always be active
        // Campaigns are created as INACTIVE, so still need to let someone turn it on
        if (newStatus != Flywheel.CampaignStatus.ACTIVE) revert Flywheel.InvalidCampaignStatus();
    }

    /// @inheritdoc CampaignHooks
    function _onUpdateMetadata(address sender, address campaign, bytes calldata hookData) internal override {
        // Anyone can prompt metadata cache updates
        // Even though metadataURI is fixed, its returned data may change over time
    }
}

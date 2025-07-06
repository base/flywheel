// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Flywheel } from "../Flywheel.sol";

/// @title AttributionHook
///
/// @notice Base contract for attribution hooks that process campaign attributions
///
/// @dev This contract provides the interface and base functionality for attribution hooks
contract AttributionHook {
  /// @notice Address of the protocol contract
  address public immutable protocol;

  /// @notice Constructor for AttributionHook
  ///
  /// @param protocol_ Address of the protocol contract
  constructor(address protocol_) {
    protocol = protocol_;
  }

  /// @notice Modifier to restrict function access to protocol only
  modifier onlyProtocol() {
    require(msg.sender == protocol);
    _;
  }

  /// @notice Creates a campaign in the hook
  ///
  /// @param campaign Address of the campaign
  /// @param initData Initialization data for the campaign
  ///
  /// @dev Only callable by the protocol contract
  function createCampaign(address campaign, bytes calldata initData) external onlyProtocol {
    _createCampaign(campaign, initData);
  }

  /// @notice Processes attribution for a campaign
  ///
  /// @param campaign Address of the campaign
  /// @param payoutToken Address of the token to be distributed
  /// @param attributionData Encoded attribution data
  /// @return payouts Array of payouts to be distributed
  ///
  /// @dev Only callable by the protocol contract
  function attribute(
    address campaign,
    address attributor,
    address payoutToken,
    bytes calldata attributionData
  ) external onlyProtocol returns (Flywheel.Payout[] memory payouts, uint256 attributorFee) {
    return _attribute(campaign, attributor, payoutToken, attributionData);
  }

  /// @notice Returns the URI for a campaign
  ///
  /// @param campaign Address of the campaign
  /// @return uri The URI for the campaign
  function campaignURI(address campaign) external view virtual returns (string memory uri) {}

  /// @notice Internal function to create a campaign
  ///
  /// @param campaign Address of the campaign
  /// @param initData Initialization data for the campaign
  ///
  /// @dev Override this function in derived contracts
  function _createCampaign(address campaign, bytes calldata initData) internal virtual {}

  /// @notice Internal function to process attribution
  ///
  /// @param campaign Address of the campaign
  /// @param payoutToken Address of the token to be distributed
  /// @param attributionData Encoded attribution data
  /// @return payouts Array of payouts to be distributed
  ///
  /// @dev Override this function in derived contracts
  function _attribute(
    address campaign,
    address attributor,
    address payoutToken,
    bytes calldata attributionData
  ) internal virtual returns (Flywheel.Payout[] memory payouts, uint256 attributorFee) {}
}

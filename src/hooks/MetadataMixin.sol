// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract MetadataMixin is Ownable2Step {
  /// @notice Base URI for campaign metadata
  string public baseURI;

  /// @notice Emitted when the base URI is updated
  ///
  /// @param baseURI The new base URI
  event BaseURIUpdated(string baseURI);

  /// @notice Emitted when a campaign is updated
  //.
  /// @param campaign Address of the campaign
  /// @param uri The URI for the campaign
  event CampaignUpdated(address indexed campaign, string uri);

  /// @notice Constructor for ConversionAttestation
  ///
  /// @param owner_ Address of the contract owner
  constructor(address owner_) Ownable(owner_) {}

  /// @notice Sets the base URI for campaign metadata
  ///
  /// @param baseURI_ The new base URI
  ///
  /// @dev Only callable by the owner

  function setBaseURI(string memory baseURI_) external onlyOwner {
    baseURI = baseURI_;
    emit BaseURIUpdated(baseURI_);
  }

  /// @notice Broadcasts a campaign update event
  ///
  /// @param campaign Address of the campaign
  ///
  /// @dev Only callable by the owner
  function broadcastCampaignUpdate(address campaign) external onlyOwner {
    emit CampaignUpdated(campaign, _campaignURI(campaign));
  }

  /// @notice Returns the URI for a campaign
  ///
  /// @param campaign Address of the campaign
  ///
  /// @return uri The URI for the campaign
  function _campaignURI(address campaign) internal view returns (string memory uri) {
    return string.concat(baseURI, Strings.toHexString(campaign));
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.29;

import { FlywheelPublisherRegistry } from "../../FlywheelPublisherRegistry.sol";
import { FlywheelCampaigns } from "../FlywheelCampaigns.sol";

// First, let's create a contract for the new implementation
contract FlywheelCampaignsV2 is FlywheelCampaigns {
  // Add a new variable to track total campaigns created
  uint256 public totalCampaignsCreated;

  // Add a new function that will only exist in V2
  function incrementTotalCampaigns() external {
    require(msg.sender == owner(), "Only owner can increment");
    totalCampaignsCreated += 1;
  }

  // adding this to be excluded from coverage report
  function test() public {}
}

// Create a mock V2 contract for testing upgrades
contract FlywheelPublisherRegistryV2 is FlywheelPublisherRegistry {
  uint256 public totalPublishersCreated;

  function incrementTotalPublishers() external onlyOwner {
    totalPublishersCreated++;
  }

  function version() external pure returns (string memory) {
    return "V2";
  }

  // adding this to be excluded from coverage report
  function test() public {}
}

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Flywheel} from "../../src/Flywheel.sol";
import {BridgeReferralFees} from "../../src/hooks/BridgeReferralFees.sol";

/// @notice Script for deploying the BridgeReferralFees hook contract
contract DeployBridgeReferralFees is Script {
    function run(address flywheel, address builderCodes) public returns (address) {
        require(flywheel != address(0), "Flywheel cannot be zero address");
        require(builderCodes != address(0), "Flywheel cannot be zero address");

        string memory metadataURI = "";
        uint8 maxFeeBasisPoints = 100;

        vm.startBroadcast();

        bytes32 salt = bytes32(uint256(keccak256(abi.encodePacked(block.timestamp))));

        // Deploy BridgeReferralFees
        BridgeReferralFees hook = new BridgeReferralFees{salt: salt}(
            flywheel, builderCodes, maxFeeBasisPoints, 0x6EcB18183838265968039955F1E8829480Db5329, metadataURI
        );
        console.log("BridgeReferralFees deployed at:", address(hook));

        // Create campaign singleton
        address campaign = Flywheel(flywheel).createCampaign(address(hook), 0, "");
        console.log("Campaign singleton deployed at:", campaign);

        // Activate campaign
        Flywheel(flywheel).updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
        console.log("Campaign activated");

        vm.stopBroadcast();

        return address(hook);
    }
}

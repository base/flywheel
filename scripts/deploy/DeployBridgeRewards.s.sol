// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {BridgeRewards} from "../../src/hooks/BridgeRewards.sol";

/// @notice Script for deploying the BridgeRewards hook contract
contract DeployBridgeRewards is Script {
    // function run(address flywheel, address escrow) external returns (address) {
    function run(address flywheel, address builderCodes) external returns (address) {
        require(flywheel != address(0), "Flywheel cannot be zero address");
        require(builderCodes != address(0), "Flywheel cannot be zero address");

        string memory metadataURI = "https://base.dev/campaign/";
        uint16 maxFeeBasisPoints = 200;

        vm.startBroadcast();

        // Deploy BridgeRewards
        BridgeRewards hook = new BridgeRewards{salt: 0}(flywheel, builderCodes, metadataURI, maxFeeBasisPoints);
        console.log("BridgeRewards deployed at:", address(hook));

        vm.stopBroadcast();

        return address(hook);
    }
}

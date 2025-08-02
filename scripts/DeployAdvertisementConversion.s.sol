// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {AdvertisementConversion} from "../src/hooks/AdvertisementConversion.sol";

/// @notice Script for deploying the AdvertisementConversion hook contract
contract DeployAdvertisementConversion is Script {
    /// @notice Deploys the AdvertisementConversion hook
    /// @param flywheel Address of the deployed Flywheel contract
    /// @param owner Address that will own the hook contract
    /// @param publisherRegistry Address of the deployed PublisherRegistry contract
    function run(address flywheel, address owner, address publisherRegistry) external returns (address) {
        require(flywheel != address(0), "Flywheel cannot be zero address");
        require(owner != address(0), "Owner cannot be zero address");
        require(publisherRegistry != address(0), "PublisherRegistry cannot be zero address");

        vm.startBroadcast();

        // Deploy AdvertisementConversion hook
        AdvertisementConversion hook = new AdvertisementConversion(flywheel, owner, publisherRegistry);

        console.log("AdvertisementConversion hook deployed at:", address(hook));
        console.log("Flywheel address:", flywheel);
        console.log("Publisher registry address:", publisherRegistry);
        console.log("Owner:", owner);
        console.log("Attribution deadline duration:", hook.attributionWindow(), "seconds");

        vm.stopBroadcast();

        return address(hook);
    }
}

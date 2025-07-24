// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {AdvertisementConversion} from "../src/hooks/AdvertisementConversion.sol";

/// @notice Script for deploying the AdvertisementConversion hook contract
contract DeployAdvertisementConversion is Script {
    /// @notice Owner address for the hook
    address public constant OWNER = 0x7116F87D6ff2ECa5e3b2D5C5224fc457978194B2;
    
    /// @notice Deploys the AdvertisementConversion hook
    /// @param flywheel Address of the deployed Flywheel contract
    /// @param publisherRegistry Address of the deployed PublisherRegistry contract
    function run(address flywheel, address publisherRegistry) external returns (address) {
        vm.startBroadcast();
        
        // Deploy AdvertisementConversion hook
        AdvertisementConversion hook = new AdvertisementConversion(
            flywheel,
            OWNER,
            publisherRegistry
        );
        
        console.log("AdvertisementConversion hook deployed at:", address(hook));
        console.log("Flywheel address:", flywheel);
        console.log("Publisher registry address:", publisherRegistry);
        console.log("Owner:", OWNER);
        console.log("Attribution deadline duration:", hook.attributionDeadlineDuration(), "seconds");
        
        vm.stopBroadcast();
        
        return address(hook);
    }
}
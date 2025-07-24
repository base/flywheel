// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {DeployFlywheel} from "./DeployFlywheel.s.sol";
import {DeployPublisherRegistry} from "./DeployPublisherRegistry.s.sol";
import {DeployAdvertisementConversion} from "./DeployAdvertisementConversion.s.sol";

/// @notice Script for deploying all Flywheel protocol contracts in the correct order
contract DeployAll is Script {
    /// @notice Owner address for contracts that need it
    address public constant OWNER = 0x7116F87D6ff2ECa5e3b2D5C5224fc457978194B2;

    /// @notice Deployment information structure
    struct DeploymentInfo {
        address flywheel;
        address publisherRegistry;
        address advertisementConversion;
        address tokenStoreImpl;
    }

    /// @notice Deploys all contracts in the correct order
    /// @param signerAddress Address authorized to call registerPublisherCustom (can be zero address)
    function run(address signerAddress) external returns (DeploymentInfo memory info) {
        console.log("Starting deployment of Flywheel protocol contracts...");
        console.log("Owner address:", OWNER);
        console.log("Signer address:", signerAddress);
        console.log("==========================================");

        // Deploy Flywheel first (independent contract)
        console.log("1. Deploying Flywheel...");
        DeployFlywheel flywheelDeployer = new DeployFlywheel();
        info.flywheel = flywheelDeployer.run();

        // Deploy PublisherRegistry (independent contract)
        console.log("2. Deploying PublisherRegistry...");
        DeployPublisherRegistry registryDeployer = new DeployPublisherRegistry();
        info.publisherRegistry = registryDeployer.run(signerAddress);

        // Deploy AdvertisementConversion hook (depends on both Flywheel and PublisherRegistry)
        console.log("3. Deploying AdvertisementConversion hook...");
        DeployAdvertisementConversion hookDeployer = new DeployAdvertisementConversion();
        info.advertisementConversion = hookDeployer.run(info.flywheel, info.publisherRegistry);

        console.log("==========================================");
        console.log("Deployment complete!");
        console.log("Flywheel:", info.flywheel);
        console.log("PublisherRegistry:", info.publisherRegistry);
        console.log("AdvertisementConversion:", info.advertisementConversion);

        return info;
    }

    /// @notice Deploys all contracts without signer
    function run() external returns (DeploymentInfo memory) {
        return this.run(address(0));
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {DeployFlywheel} from "./DeployFlywheel.s.sol";
import {DeployPublisherRegistry} from "./DeployPublisherRegistry.s.sol";
import {DeployAdConversion} from "./DeployAdConversion.s.sol";

/// @notice Script for deploying all Flywheel protocol contracts in the correct order
contract DeployAll is Script {
    /// @notice Deployment information structure
    struct DeploymentInfo {
        address flywheel;
        address publisherRegistry;
        address AdConversion;
        address tokenStoreImpl;
    }

    /// @notice Deploys all contracts in the correct order
    /// @param owner Address that will own the contracts
    /// @param signerAddress Address authorized to call registerPublisherCustom (can be zero address)
    function run(address owner, address signerAddress) external returns (DeploymentInfo memory info) {
        require(owner != address(0), "Owner cannot be zero address");

        console.log("Starting deployment of Flywheel protocol contracts...");
        console.log("Owner address:", owner);
        console.log("Signer address:", signerAddress);
        console.log("==========================================");

        // Deploy Flywheel first (independent contract)
        console.log("1. Deploying Flywheel...");
        DeployFlywheel flywheelDeployer = new DeployFlywheel();
        info.flywheel = flywheelDeployer.run();

        // Deploy PublisherRegistry (independent contract)
        console.log("2. Deploying PublisherRegistry...");
        DeployPublisherRegistry registryDeployer = new DeployPublisherRegistry();
        info.publisherRegistry = registryDeployer.run(owner, signerAddress);

        // Deploy AdConversion hook (depends on both Flywheel and PublisherRegistry)
        console.log("3. Deploying AdConversion hook...");
        DeployAdConversion hookDeployer = new DeployAdConversion();
        info.AdConversion = hookDeployer.run(info.flywheel, owner, info.publisherRegistry);

        console.log("==========================================");
        console.log("Deployment complete!");
        console.log("Flywheel:", info.flywheel);
        console.log("PublisherRegistry:", info.publisherRegistry);
        console.log("AdConversion:", info.AdConversion);

        return info;
    }

    /// @notice Deploys all contracts without signer
    /// @param owner Address that will own the contracts
    function run(address owner) external returns (DeploymentInfo memory) {
        return this.run(owner, address(0));
    }
}

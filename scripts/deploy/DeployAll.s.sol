// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {DeployFlywheel} from "./DeployFlywheel.s.sol";
import {DeployBuilderCodes} from "./DeployBuilderCodes.s.sol";
import {DeployAdConversion} from "./DeployAdConversion.s.sol";
import {DeploySimpleRewards} from "./DeploySimpleRewards.s.sol";
import {DeployCashbackRewards} from "./DeployCashbackRewards.s.sol";
import {DeployBridgeRewards} from "./DeployBridgeRewards.s.sol";

/// @notice Script for deploying all Flywheel protocol contracts in the correct order
contract DeployAll is Script {
    /// @notice Deployment information structure
    struct Deployments {
        address flywheel;
        address builderCodes;
        address adConversion;
        address cashbackRewards;
        address bridgeRewards;
        address simpleRewards;
    }

    function run() external returns (Deployments memory deployments) {
        address owner = 0x0BFc799dF7e440b7C88cC2454f12C58f8a29D986; // dev wallet

        console.log("Starting deployment of Flywheel protocol contracts...");
        console.log("Owner address:", owner);
        console.log("==========================================");

        // Deploy Flywheel first (no dependencies)
        console.log("1. Deploying Flywheel...");
        DeployFlywheel flywheelDeployer = new DeployFlywheel();
        deployments.flywheel = flywheelDeployer.run();

        // Deploy BuilderCodes (depends on owner)
        console.log("2. Deploying BuilderCodes...");
        DeployBuilderCodes builderCodesDeployer = new DeployBuilderCodes();
        deployments.builderCodes = builderCodesDeployer.run(owner);

        // Deploy AdConversion (depends on Flywheel, BuilderCodes, owner)
        console.log("3. Deploying AdConversion...");
        DeployAdConversion adConversionDeployer = new DeployAdConversion();
        deployments.adConversion = adConversionDeployer.run(deployments.flywheel, deployments.builderCodes, owner);

        // Deploy CashbackRewards (depends on Flywheel)
        console.log("4. Deploying CashbackRewards...");
        DeployCashbackRewards cashbackRewardsDeployer = new DeployCashbackRewards();
        deployments.cashbackRewards = cashbackRewardsDeployer.run(deployments.flywheel);

        // Deploy BridgeRewards (depends on Flywheel, BuilderCodes)
        console.log("4. Deploying BridgeRewards...");
        DeployBridgeRewards bridgeRewardsDeployer = new DeployBridgeRewards();
        deployments.bridgeRewards = bridgeRewardsDeployer.run(deployments.flywheel, deployments.builderCodes);

        // Deploy SimpleRewards (depends on Flywheel)
        console.log("5. Deploying SimpleRewards...");
        DeploySimpleRewards simpleRewardsDeployer = new DeploySimpleRewards();
        deployments.simpleRewards = simpleRewardsDeployer.run(deployments.flywheel);

        console.log("==========================================");
        console.log("Deployment complete!");
        console.log("Flywheel:", deployments.flywheel);
        console.log("BuilderCodes:", deployments.builderCodes);
        console.log("AdConversion:", deployments.adConversion);
        console.log("CashbackRewards:", deployments.cashbackRewards);
        console.log("BridgeRewards:", deployments.bridgeRewards);
        console.log("SimpleRewards:", deployments.simpleRewards);

        return deployments;
    }
}

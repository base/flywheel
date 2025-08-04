// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {BuyerRewards} from "../src/hooks/BuyerRewards.sol";

/// @notice Script for deploying the BuyerRewards hook contract
contract DeployBuyerRewards is Script {
    /// @notice Deploys the BuyerRewards hook
    /// @param flywheel Address of the deployed Flywheel contract
    function run(address flywheel, address escrow) external returns (address) {
        require(flywheel != address(0), "Flywheel cannot be zero address");

        vm.startBroadcast();

        // Deploy BuyerRewards hook
        BuyerRewards hook = new BuyerRewards(flywheel, escrow);
        console.log("BuyerRewards hook deployed at:", address(hook));

        vm.stopBroadcast();

        return address(hook);
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {FlywheelPublisherRegistry} from "../src/.sol";

/// @notice Script for deploying the FlywheelPublisherRegistry contract
contract DeployPublisherRegistry is Script {
    /// @notice Deploys the FlywheelPublisherRegistry with proxy
    /// @param owner Address that will own the registry contract
    /// @param signerAddress Address authorized to call registerPublisherCustom (can be zero address)
    function run(address owner, address signerAddress) external returns (address) {
        require(owner != address(0), "Owner cannot be zero address");

        vm.startBroadcast();

        // Deploy the implementation contract
        FlywheelPublisherRegistry implementation = new FlywheelPublisherRegistry();

        // Prepare initialization data
        bytes memory initData = abi.encodeCall(FlywheelPublisherRegistry.initialize, (owner, signerAddress));

        // Deploy the proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console.log("FlywheelPublisherRegistry implementation deployed at:", address(implementation));
        console.log("FlywheelPublisherRegistry proxy deployed at:", address(proxy));
        console.log("Owner:", owner);
        console.log("Signer address:", signerAddress);

        vm.stopBroadcast();

        return address(proxy);
    }

    /// @notice Deploys the FlywheelPublisherRegistry without signer
    /// @param owner Address that will own the registry contract
    function run(address owner) external returns (address) {
        return this.run(owner, address(0));
    }
}

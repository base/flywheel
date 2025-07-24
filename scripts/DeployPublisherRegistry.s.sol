// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {FlywheelPublisherRegistry} from "../src/FlywheelPublisherRegistry.sol";

/// @notice Script for deploying the FlywheelPublisherRegistry contract
contract DeployPublisherRegistry is Script {
    /// @notice Owner address for the registry
    address public constant OWNER = 0x7116F87D6ff2ECa5e3b2D5C5224fc457978194B2;

    /// @notice Deploys the FlywheelPublisherRegistry with proxy
    /// @param signerAddress Address authorized to call registerPublisherCustom (can be zero address)
    function run(address signerAddress) external returns (address) {
        vm.startBroadcast();

        // Deploy the implementation contract
        FlywheelPublisherRegistry implementation = new FlywheelPublisherRegistry();

        // Prepare initialization data
        bytes memory initData = abi.encodeCall(FlywheelPublisherRegistry.initialize, (OWNER, signerAddress));

        // Deploy the proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console.log("FlywheelPublisherRegistry implementation deployed at:", address(implementation));
        console.log("FlywheelPublisherRegistry proxy deployed at:", address(proxy));
        console.log("Owner:", OWNER);
        console.log("Signer address:", signerAddress);

        vm.stopBroadcast();

        return address(proxy);
    }

    /// @notice Deploys the FlywheelPublisherRegistry without signer
    function run() external returns (address) {
        return this.run(address(0));
    }
}

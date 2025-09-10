// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BuilderCodes} from "../../src/BuilderCodes.sol";

/// @notice Script for deploying the BuilderCodes contract
contract DeployBuilderCodes is Script {
    /// @notice Deploys the BuilderCodes with proxy
    /// @param owner Address that will own the registry contract
    function run(address owner) external returns (address) {
        require(owner != address(0), "Owner cannot be zero address");

        address signerAddress = 0x0000000000000000000000000000000000000000;
        string memory uriPrefix = "https://flywheel.com/";

        console.log("Signer address:", signerAddress);
        console.log("URI Prefix:", uriPrefix);

        vm.startBroadcast();

        // Deploy the implementation contract
        BuilderCodes implementation = new BuilderCodes();

        // Prepare initialization data
        bytes memory initData = abi.encodeCall(BuilderCodes.initialize, (owner, signerAddress, uriPrefix));

        // Deploy the proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console.log("BuilderCodes implementation deployed at:", address(implementation));
        console.log("BuilderCodes proxy deployed at:", address(proxy));

        vm.stopBroadcast();

        return address(proxy);
    }
}

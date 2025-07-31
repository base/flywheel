// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ReferralCodeRegistry} from "../src/ReferralCodeRegistry.sol";

/// @notice Script for deploying the ReferralCodeRegistry contract
contract DeployReferralCodeRegistry is Script {
    /// @notice Deploys the ReferralCodeRegistry with proxy
    /// @param owner Address that will own the registry contract
    /// @param signerAddress Address authorized to call registerPublisherCustom (can be zero address)
    function run(address owner, address signerAddress) external returns (address) {
        require(owner != address(0), "Owner cannot be zero address");

        vm.startBroadcast();

        // Deploy the implementation contract
        ReferralCodeRegistry implementation = new ReferralCodeRegistry();

        // Prepare initialization data
        bytes memory initData = abi.encodeCall(ReferralCodeRegistry.initialize, (owner, signerAddress));

        // Deploy the proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console.log("ReferralCodeRegistry implementation deployed at:", address(implementation));
        console.log("ReferralCodeRegistry proxy deployed at:", address(proxy));
        console.log("Owner:", owner);
        console.log("Signer address:", signerAddress);

        vm.stopBroadcast();

        return address(proxy);
    }

    /// @notice Deploys the ReferralCodeRegistry without signer
    /// @param owner Address that will own the registry contract
    function run(address owner) external returns (address) {
        return this.run(owner, address(0));
    }
}

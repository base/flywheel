pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {MockBuilderCodesV2} from "../lib/mocks/MockBuilderCodesV2.sol";

import {BuilderCodes} from "../../src/BuilderCodes.sol";

contract PublisherRegistryUpgradesTest is Test {
    BuilderCodes public implementation;
    BuilderCodes public pubRegistry;
    ERC1967Proxy public proxy;
    MockBuilderCodesV2 public implementationV2;
    address private owner = address(this);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation
        implementation = new BuilderCodes();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(BuilderCodes.initialize.selector, owner, address(0), "");
        proxy = new ERC1967Proxy(address(implementation), initData);

        // Create interface to proxy
        pubRegistry = BuilderCodes(address(proxy));

        // Deploy V2 implementation
        implementationV2 = new MockBuilderCodesV2();

        vm.stopPrank();
    }

    function test_upgrade() public {
        // Upgrade to V2
        vm.startPrank(owner);
        pubRegistry.upgradeToAndCall(address(implementationV2), "");
        vm.stopPrank();

        // Test V2 functionality
        MockBuilderCodesV2 registryV2 = MockBuilderCodesV2(address(proxy));
        assertEq(registryV2.version(), "V2");

        // Verify state is preserved
        assertEq(registryV2.owner(), owner);
    }

    function test_upgradeUnauthorized() public {
        vm.startPrank(address(0xbad));

        // Expect the custom error OwnableUnauthorizedAccount with the caller's address
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0xbad)));
        pubRegistry.upgradeToAndCall(address(implementationV2), "");

        vm.stopPrank();
    }
}

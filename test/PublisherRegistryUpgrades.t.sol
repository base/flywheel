pragma solidity 0.8.29;

import "forge-std/Test.sol";
import {ReferralCodeRegistry} from "../src/ReferralCodeRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ReferralCodeRegistryV2} from "./mocks/DummyUpgrades.sol";

contract PublisherRegistryUpgradesTest is Test {
    ReferralCodeRegistry public implementation;
    ReferralCodeRegistry public pubRegistry;
    ERC1967Proxy public proxy;
    ReferralCodeRegistryV2 public implementationV2;
    address private owner = address(this);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation
        implementation = new ReferralCodeRegistry();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(ReferralCodeRegistry.initialize.selector, owner, address(0));
        proxy = new ERC1967Proxy(address(implementation), initData);

        // Create interface to proxy
        pubRegistry = ReferralCodeRegistry(address(proxy));

        // Deploy V2 implementation
        implementationV2 = new ReferralCodeRegistryV2();

        vm.stopPrank();
    }

    function test_upgrade() public {
        // Upgrade to V2
        vm.startPrank(owner);
        pubRegistry.upgradeToAndCall(address(implementationV2), "");
        vm.stopPrank();

        // Test V2 functionality
        ReferralCodeRegistryV2 registryV2 = ReferralCodeRegistryV2(address(proxy));
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

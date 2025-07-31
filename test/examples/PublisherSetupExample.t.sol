// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {PublisherTestSetup, PublisherSetupHelper} from "../helpers/PublisherSetupHelper.sol";
import {ReferralCodeRegistry} from "../../src/ReferralCodeRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Example test showing how to use the PublisherSetupHelper
contract PublisherSetupExampleTest is Test, PublisherTestSetup {
    using PublisherSetupHelper for *;

    ReferralCodeRegistry public registry;
    address public owner = makeAddr("owner");
    address public signer = makeAddr("signer");

    function setUp() public {
        // Deploy registry
        vm.startPrank(owner);
        ReferralCodeRegistry impl = new ReferralCodeRegistry();
        bytes memory initData = abi.encodeWithSelector(ReferralCodeRegistry.initialize.selector, owner, signer);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        registry = ReferralCodeRegistry(address(proxy));
        vm.stopPrank();
    }

    function test_setupSinglePublisher() public {
        // Setup a single publisher with minimal config
        PublisherSetupHelper.PublisherConfig memory config =
            setupPublisher(registry, "TEST_REF", makeAddr("publisher1"), signer);

        // Verify publisher was registered
        assertTrue(registry.isReferralCodeRegistered(config.refCode));
        assertEq(registry.getOwner(config.refCode), config.owner);
        assertEq(registry.getPayoutRecipient(config.refCode), config.owner); // Defaults to owner
    }

    function test_setupPublisherWithCustomPayout() public {
        // Setup publisher with custom payout address
        address publisher = makeAddr("publisher2");
        address payoutAddr = makeAddr("payout2");

        PublisherSetupHelper.PublisherConfig memory config =
            setupPublisher(registry, "CUSTOM_REF", publisher, payoutAddr, signer);

        // Verify custom payout
        assertEq(registry.getPayoutRecipient(config.refCode), payoutAddr);
    }

    function test_batchSetupPublishers() public {
        // Create and setup multiple publishers at once
        PublisherSetupHelper.PublisherConfig[] memory configs = createTestPublishers(5);
        setupPublishers(registry, configs, signer);

        // Verify all were registered
        for (uint256 i = 0; i < configs.length; i++) {
            assertTrue(registry.isReferralCodeRegistered(configs[i].refCode));
            assertEq(registry.getOwner(configs[i].refCode), configs[i].owner);
        }
    }

    function test_customPublisherConfig() public {
        // Create a fully custom publisher configuration
        PublisherSetupHelper.PublisherConfig memory config = PublisherSetupHelper.createPublisherConfig(
            "FULL_CUSTOM", makeAddr("customOwner"), makeAddr("customPayout"), "https://custom.metadata.url"
        );

        setupPublisher(registry, config, signer);

        // Verify all custom values
        assertEq(registry.getOwner(config.refCode), config.owner);
        assertEq(registry.getPayoutRecipient(config.refCode), config.payoutRecipient);
        assertEq(registry.getMetadataUrl(config.refCode), config.metadataUrl);
    }
}

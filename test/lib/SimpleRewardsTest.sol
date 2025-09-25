// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {MockERC3009Token} from "../../lib/commerce-payments/test/mocks/MockERC3009Token.sol";

import {Flywheel} from "../../src/Flywheel.sol";
import {SimpleRewards} from "../../src/hooks/SimpleRewards.sol";

contract SimpleRewardsTest is Test {
    uint256 internal constant OWNER_PK = uint256(keccak256("owner"));
    uint256 internal constant MANAGER_PK = uint256(keccak256("manager"));

    address public owner;
    address public manager;

    MockERC3009Token public usdc;
    Flywheel public flywheel;
    SimpleRewards public simpleRewards;

    address public simpleRewardsCampaign;

    function setUp() public {
        owner = vm.addr(OWNER_PK);
        manager = vm.addr(MANAGER_PK);

        usdc = new MockERC3009Token("USD Coin", "USDC", 6);
        flywheel = new Flywheel();
        simpleRewards = new SimpleRewards(address(flywheel));

        bytes memory hookData = abi.encode(owner, manager, "");
        simpleRewardsCampaign = flywheel.createCampaign(address(simpleRewards), 0, hookData);

        vm.label(owner, "Owner");
        vm.label(manager, "Manager");
        vm.label(address(usdc), "USDC");
        vm.label(address(flywheel), "Flywheel");
        vm.label(address(simpleRewards), "SimpleRewards");
        vm.label(simpleRewardsCampaign, "SimpleRewardsCampaign");
    }
}

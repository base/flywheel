// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Flywheel} from "../src/Flywheel.sol";
import {SimpleRewards} from "../src/hooks/SimpleRewards.sol";

import {DummyERC20} from "../test/mocks/DummyERC20.sol";

/// @notice Script for deploying the Flywheel contract
contract SimpleReward is Script {
    /// @notice Deploys the SimpleReward contract
    function run() external returns (address) {
        vm.startBroadcast();

        address dev = 0x6EcB18183838265968039955F1E8829480Db5329;

        Flywheel flywheel = new Flywheel();
        SimpleRewards simpleRewards = new SimpleRewards(address(flywheel));

        address campaign = flywheel.createCampaign(address(simpleRewards), 0, abi.encode(dev, dev, ""));

        console.log("Campaign deployed at:", campaign);

        address[] memory initialHolders = new address[](1);
        initialHolders[0] = campaign;
        DummyERC20 token = new DummyERC20(initialHolders);

        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");

        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: dev, amount: 1e6, extraData: ""});

        flywheel.reward(campaign, address(token), abi.encode(payouts));

        console.log("Token balance of dev:", token.balanceOf(dev));
        console.log("Token balance of campaign:", token.balanceOf(campaign));

        vm.stopBroadcast();
    }
}

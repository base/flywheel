// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract UnsupportedOperationsTest is BridgeRewardsTest {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when onAllocate is called (BridgeRewards uses immediate payouts only)
    function test_onAllocate_revert_unsupported() public {
        vm.expectRevert();
        vm.prank(address(flywheel));
        bridgeRewards.onAllocate(address(this), bridgeRewardsCampaign, address(usdc), "");
    }

    /// @dev Reverts when onDeallocate is called (BridgeRewards uses immediate payouts only)
    function test_onDeallocate_revert_unsupported() public {
        vm.expectRevert();
        vm.prank(address(flywheel));
        bridgeRewards.onDeallocate(address(this), bridgeRewardsCampaign, address(usdc), "");
    }

    /// @dev Reverts when onDistribute is called (BridgeRewards uses immediate payouts only)
    function test_onDistribute_revert_unsupported() public {
        vm.expectRevert();
        vm.prank(address(flywheel));
        bridgeRewards.onDistribute(address(this), bridgeRewardsCampaign, address(usdc), "");
    }
}

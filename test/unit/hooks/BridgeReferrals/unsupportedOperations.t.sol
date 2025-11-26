// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeReferralsTest} from "../../../lib/BridgeReferralsTest.sol";

contract UnsupportedOperationsTest is BridgeReferralsTest {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when onAllocate is called (BridgeReferrals uses immediate payouts only)
    function test_onAllocate_revert_unsupported() public {
        vm.expectRevert();
        vm.prank(address(flywheel));
        bridgeReferrals.onAllocate(address(this), bridgeReferralsCampaign, address(usdc), "");
    }

    /// @dev Reverts when onDeallocate is called (BridgeReferrals uses immediate payouts only)
    function test_onDeallocate_revert_unsupported() public {
        vm.expectRevert();
        vm.prank(address(flywheel));
        bridgeReferrals.onDeallocate(address(this), bridgeReferralsCampaign, address(usdc), "");
    }

    /// @dev Reverts when onDistribute is called (BridgeReferrals uses immediate payouts only)
    function test_onDistribute_revert_unsupported() public {
        vm.expectRevert();
        vm.prank(address(flywheel));
        bridgeReferrals.onDistribute(address(this), bridgeReferralsCampaign, address(usdc), "");
    }
}

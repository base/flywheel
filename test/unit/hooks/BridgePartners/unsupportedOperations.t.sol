// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgePartnersTest} from "../../../lib/BridgePartnersTest.sol";

contract UnsupportedOperationsTest is BridgePartnersTest {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when onAllocate is called (BridgePartners uses immediate payouts only)
    function test_onAllocate_revert_unsupported() public {
        vm.expectRevert();
        vm.prank(address(flywheel));
        bridgePartners.onAllocate(address(this), bridgePartnersCampaign, address(usdc), "");
    }

    /// @dev Reverts when onDeallocate is called (BridgePartners uses immediate payouts only)
    function test_onDeallocate_revert_unsupported() public {
        vm.expectRevert();
        vm.prank(address(flywheel));
        bridgePartners.onDeallocate(address(this), bridgePartnersCampaign, address(usdc), "");
    }

    /// @dev Reverts when onDistribute is called (BridgePartners uses immediate payouts only)
    function test_onDistribute_revert_unsupported() public {
        vm.expectRevert();
        vm.prank(address(flywheel));
        bridgePartners.onDistribute(address(this), bridgePartnersCampaign, address(usdc), "");
    }
}

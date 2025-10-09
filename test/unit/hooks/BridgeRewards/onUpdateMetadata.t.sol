// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnUpdateMetadataTest is BridgeRewardsTest {
    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Accepts metadata update from any sender (no access restrictions)
    /// @param randomCaller Random caller address
    function test_success_noAccessRestrictions(address randomCaller) public {
        // Test that any address can update metadata (the hook has no access restrictions)
        vm.assume(randomCaller != address(0));
        vm.assume(randomCaller != user);
        vm.assume(randomCaller != builder);

        vm.prank(randomCaller);
        flywheel.updateMetadata(bridgeRewardsCampaign, "some metadata");

        // Should not revert - the hook allows anyone to trigger metadata updates
        // Even though metadataURI is fixed, its returned data may change over time
        vm.prank(randomCaller);
        flywheel.updateMetadata(bridgeRewardsCampaign, "different metadata");
    }
}

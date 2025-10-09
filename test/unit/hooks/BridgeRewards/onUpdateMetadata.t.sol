// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnUpdateMetadataTest is BridgeRewardsTest {
    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Accepts metadata update from any sender (no access restrictions)
    function test_success_noAccessRestrictions() public {
        // Test that any address can update metadata (the hook has no access restrictions)
        address randomCaller = address(0x999);

        vm.prank(randomCaller);
        flywheel.updateMetadata(bridgeRewardsCampaign, "some metadata");

        // Should not revert - the hook allows anyone to trigger metadata updates
        // Even though metadataURI is fixed, its returned data may change over time

        // Test with different callers
        vm.prank(user);
        flywheel.updateMetadata(bridgeRewardsCampaign, "different metadata");

        vm.prank(builder);
        flywheel.updateMetadata(bridgeRewardsCampaign, "builder metadata");

        // All should succeed without reverts
    }
}

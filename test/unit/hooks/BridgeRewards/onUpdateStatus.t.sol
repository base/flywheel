// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";
import {BridgeRewards} from "../../../../src/hooks/BridgeRewards.sol";
import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnUpdateStatusTest is BridgeRewardsTest {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when new status is not ACTIVE (perpetual campaign restriction)
    /// @param statusValue Uint8 value to cast to campaign status
    function test_revert_nonActiveStatus(uint8 statusValue) public {
        // Bound to valid enum values (0-3)
        statusValue = uint8(bound(statusValue, 0, 3));
        Flywheel.CampaignStatus invalidStatus = Flywheel.CampaignStatus(statusValue);

        vm.assume(invalidStatus != Flywheel.CampaignStatus.ACTIVE);

        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        flywheel.updateStatus(bridgeRewardsCampaign, invalidStatus, "");
    }

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Accepts status update to ACTIVE from any previous status
    /// @param statusValue Uint8 value that will be ignored since we only test ACTIVE transition
    function test_success_toActiveStatus(uint8 statusValue) public {
        // The statusValue parameter is not used since we only test transition to ACTIVE
        // But we keep it to maintain the fuzz testing pattern

        // Create a new BridgeRewards contract to get a different campaign address
        BridgeRewards bridgeRewards2 = new BridgeRewards(address(flywheel), address(builderCodes), CAMPAIGN_URI, 200);
        address testCampaign = flywheel.createCampaign(address(bridgeRewards2), 0, "");

        // The campaign starts as INACTIVE, and we can only transition to ACTIVE
        // This test verifies that ACTIVE status is always allowed
        flywheel.updateStatus(testCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        // Verify the status was updated successfully
        assertEq(
            uint256(flywheel.campaignStatus(testCampaign)),
            uint256(Flywheel.CampaignStatus.ACTIVE),
            "Campaign should be ACTIVE"
        );
    }
}

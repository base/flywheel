// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";
import {Flywheel} from "../../../../src/Flywheel.sol";

contract OnUpdateStatusTest is BridgeRewardsTest {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when new status is not ACTIVE (perpetual campaign restriction)
    /// @param invalidStatus Any campaign status except ACTIVE
    function test_onUpdateStatus_revert_nonActiveStatus(Flywheel.CampaignStatus invalidStatus) public {}

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Accepts status update to ACTIVE from any previous status
    /// @param previousStatus Any valid campaign status
    function test_onUpdateStatus_success_toActiveStatus(Flywheel.CampaignStatus previousStatus) public {}
}

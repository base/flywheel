// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";
import {Flywheel} from "../../../../src/Flywheel.sol";

contract OnUpdateStatusTest is BridgeRewardsTest {
    /// @notice Tests that onUpdateStatus reverts when called by non-Flywheel address
    ///
    /// @dev Should revert with access control error when called directly instead of through Flywheel
    function test_onUpdateStatus_revert_onlyFlywheel() public {}

    /// @notice Tests that onUpdateStatus reverts when new status is not ACTIVE
    ///
    /// @dev BridgeRewards is a perpetual campaign that only allows ACTIVE status
    ///      Should revert with InvalidCampaignStatus error for any non-ACTIVE status
    ///
    /// @param newStatus The campaign status that should cause revert (any except ACTIVE)
    function test_onUpdateStatus_revert_newStatusNotActive(Flywheel.CampaignStatus newStatus) public {}

    /// @notice Tests successful campaign activation
    ///
    /// @dev Verifies campaign can be activated from INACTIVE to ACTIVE status
    ///      Tests the only allowed status transition for BridgeRewards
    function test_onUpdateStatus_success_activatesCampaign() public {}
}

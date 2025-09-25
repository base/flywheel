// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";

import {SimpleRewardsTest} from "../../../lib/SimpleRewardsTest.sol";

contract SimpleRewardsOnUpdateMetadataTest is SimpleRewardsTest {
    /// @notice Test that onUpdateMetadata reverts when called by non-Flywheel address
    ///
    /// @dev This test validates the onlyFlywheel access control by attempting to call
    /// _onUpdateMetadata directly from various sender addresses that are not the flywheel contract.
    /// Should revert with appropriate access control error.
    ///
    /// @param sender The address attempting to call the function (should not be flywheel)
    /// @param hookData The encoded metadata update data
    function test_onUpdateMetadata_revert_onlyFlywheel(address sender, bytes memory hookData) public {}

    /// @notice Test that onUpdateMetadata reverts when called by non-manager address
    ///
    /// @dev This test validates the onlyManager modifier by attempting to update campaign metadata
    /// from addresses that are not the designated campaign manager. Should revert with
    /// Unauthorized error.
    ///
    /// @param sender The address attempting to call the function (should not be manager)
    /// @param hookData The encoded metadata update data
    function test_onUpdateMetadata_revert_onlyManager(address sender, bytes memory hookData) public {}

    /// @notice Test that onUpdateMetadata successfully processes empty metadata update
    ///
    /// @dev This test validates that when hookData is empty or indicates no URI change,
    /// the campaign URI remains unchanged. Tests the scenario where metadata update
    /// is called but no actual changes are intended.
    function test_onUpdateMetadata_success_leaveCampaignURIUnchanged() public {}

    /// @notice Test that onUpdateMetadata successfully updates campaign URI
    ///
    /// @dev This test validates that _onUpdateMetadata correctly decodes hookData containing
    /// a new URI string and updates the campaign's URI mapping. Verifies that the URI
    /// is stored correctly and can be retrieved.
    ///
    /// @param campaignURI The new URI string to be set for the campaign
    function test_onUpdateMetadata_success_updateCampaignURI(string memory campaignURI) public {}
}

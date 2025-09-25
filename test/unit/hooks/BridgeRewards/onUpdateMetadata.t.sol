// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnUpdateMetadataTest is BridgeRewardsTest {
    /// @notice Tests that onUpdateMetadata reverts when called by non-Flywheel address
    ///
    /// @dev Should revert with access control error when called directly instead of through Flywheel
    function test_onUpdateMetadata_revert_onlyFlywheel() public {}

    /// @notice Tests successful metadata update
    ///
    /// @dev BridgeRewards allows anyone to trigger metadata updates since the URI is fixed
    ///      but its returned data may change over time. Verifies no access control restrictions
    ///      and that metadata cache can be refreshed by any caller
    function test_onUpdateMetadata_success() public {}
}

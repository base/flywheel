// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnCreateCampaignTest is BridgeRewardsTest {
    /// @notice Tests that onCreateCampaign reverts when called by non-Flywheel address
    ///
    /// @dev Should revert with access control error when called directly instead of through Flywheel
    ///
    /// @param nonce The campaign nonce to test with
    /// @param hookData The hook data to test with
    function test_onCreateCampaign_revert_onlyFlywheel(uint256 nonce, bytes memory hookData) public {}

    /// @notice Tests that onCreateCampaign reverts when nonce is not zero
    ///
    /// @dev BridgeRewards only allows one campaign to be created (nonce must be 0)
    ///      Should revert with InvalidCampaignInitialization error
    ///
    /// @param nonce The non-zero nonce that should cause revert
    function test_onCreateCampaign_revert_invalidNonce(uint256 nonce) public {}

    /// @notice Tests that onCreateCampaign reverts when hookData is not empty
    ///
    /// @dev BridgeRewards requires empty hookData for campaign creation
    ///      Should revert with InvalidCampaignInitialization error
    ///
    /// @param hookData The non-empty hook data that should cause revert
    function test_onCreateCampaign_revert_invalidHookData(bytes memory hookData) public {}

    /// @notice Tests successful campaign creation with valid parameters
    ///
    /// @dev Should successfully create campaign when nonce is 0 and hookData is empty
    ///      Verifies campaign is created and accessible through Flywheel
    function test_onCreateCampaign_success() public {}
}

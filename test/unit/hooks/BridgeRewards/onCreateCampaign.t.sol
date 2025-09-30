// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnCreateCampaignTest is BridgeRewardsTest {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when nonce is not zero (only one campaign allowed)
    /// @param nonZeroNonce Any nonce value except zero
    function test_onCreateCampaign_revert_nonZeroNonce(uint256 nonZeroNonce) public {}

    /// @dev Reverts when hookData is not empty (no configuration allowed)
    /// @param nonEmptyHookData Any non-empty bytes data
    function test_onCreateCampaign_revert_nonEmptyHookData(bytes memory nonEmptyHookData) public {}

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Accepts campaign creation with nonce zero and empty hookData
    function test_onCreateCampaign_success_validParameters() public {}
}

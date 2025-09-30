// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnDistributeFeesTest is BridgeRewardsTest {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Should revert when hookData cannot be decoded as bytes32 (builder code)
    /// @param hookData The malformed hook data that should cause revert
    function test_onDistributeFees_revert_invalidHookData(bytes memory hookData) public {}

    /// @dev Reverts when builder code is not registered in BuilderCodes
    function test_onDistributeFees_revert_unregisteredBuilderCode() public {}

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Creates distribution to correct payout address for builder code
    function test_onDistributeFees_success_usesBuilderPayoutAddress() public {}

    /// @dev Sets distribution amount to full allocated fee amount for the builder code
    /// @param allocatedFeeAmount Amount of fees allocated for the builder code
    function test_onDistributeFees_success_distributesFullAmount(uint256 allocatedFeeAmount) public {}

    /// @dev Uses builder code as distribution key for fee tracking
    function test_onDistributeFees_success_usesBuilderCodeAsKey() public {}

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies single distribution is returned for valid builder code
    function test_onDistributeFees_singleDistribution() public {}

    /// @dev Verifies distribution extraData is empty for fee distributions
    function test_onDistributeFees_emptyExtraData() public {}
}

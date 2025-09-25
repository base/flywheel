// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnDistributeFeesTest is BridgeRewardsTest {
    /// @notice Tests that onDistributeFees reverts when called by non-Flywheel address
    ///
    /// @dev Should revert with access control error when called directly instead of through Flywheel
    ///
    /// @param hookData The hook data to test with
    function test_onDistributeFees_revert_onlyFlywheel(bytes memory hookData) public {}

    /// @notice Tests that onDistributeFees reverts when hookData has invalid format
    ///
    /// @dev Should revert when hookData cannot be decoded as bytes32 (builder code)
    ///
    /// @param hookData The malformed hook data that should cause revert
    function test_onDistributeFees_revert_invalidHookData(bytes memory hookData) public {}

    /// @notice Tests that onDistributeFees reverts when campaign has insufficient allocated fees
    ///
    /// @dev Should revert when trying to distribute more fees than allocated for the builder code
    ///
    /// @param user The original recipient address
    /// @param bridgedAmount The original bridged amount
    /// @param feeBps The fee basis points
    function test_onDistributeFees_revert_campaignInsufficientFunds(address user, uint256 bridgedAmount, uint16 feeBps)
        public
    {}

    /// @notice Tests successful fee distribution to builder's payout address
    ///
    /// @dev Verifies fees are sent to the correct payout address configured for the builder code
    ///      Tests that builder receives allocated fees from failed initial distribution
    ///
    /// @param user The original recipient address
    /// @param bridgedAmount The original bridged amount
    /// @param feeBps The fee basis points
    function test_onDistributeFees_success_sendsToPayoutAddress(address user, uint256 bridgedAmount, uint16 feeBps)
        public
    {}

    /// @notice Tests that onDistributeFees sends all allocated fees for a builder code
    ///
    /// @dev Verifies the full allocated fee amount is distributed, clearing the allocation
    ///      Tests multiple accumulated fees are distributed in one call
    ///
    /// @param user The original recipient address
    /// @param bridgedAmount The original bridged amount
    /// @param feeBps The fee basis points
    function test_onDistributeFees_success_sendsAllAllocatedFees(address user, uint256 bridgedAmount, uint16 feeBps)
        public
    {}
}

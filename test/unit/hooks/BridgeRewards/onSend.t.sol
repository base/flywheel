// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnSendTest is BridgeRewardsTest {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when campaign balance minus allocated fees equals zero
    function test_onSend_revert_zeroBridgedAmount() public {}

    /// @dev Reverts when caller is not flywheel
    /// @param caller Caller address
    function test_onSend_revert_onlyFlywheel(address caller) public {}

    /// @dev Reverts when hookData cannot be correctly decoded
    /// @param hookData The malformed hook data that should cause revert
    function test_onSend_revert_invalidHookData(bytes memory hookData) public {}

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Calculates correct payout and fee amounts with registered builder code
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    function test_onSend_success_registeredBuilderCode(uint256 bridgedAmount, uint16 feeBps) public {}

    /// @dev Sets fee to zero when builder code is not registered in BuilderCodes
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points (ignored for unregistered codes)
    function test_onSend_success_unregisteredBuilderCode(uint256 bridgedAmount, uint16 feeBps) public {}

    /// @dev Caps fee at maxFeeBasisPoints when requested fee exceeds maximum
    /// @param bridgedAmount Amount available for bridging
    /// @param excessiveFeeBps Fee basis points exceeding maximum
    function test_onSend_success_feeExceedsMaximum(uint256 bridgedAmount, uint16 excessiveFeeBps) public {}

    /// @dev Returns zero fees when fee basis points is zero
    /// @param bridgedAmount Amount available for bridging
    function test_onSend_success_zeroFeeBps(uint256 bridgedAmount) public {}

    /// @dev Returns nonzero fees when fee basis points is nonzero
    /// @param bridgedAmount Amount available for bridging
    function test_onSend_success_nonzeroFeeBps(uint256 bridgedAmount) public {}

    /// @dev Calculates bridged amount correctly with native token (ETH)
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    function test_onSend_success_nativeToken(uint256 bridgedAmount, uint16 feeBps) public {}

    /// @dev Excludes allocated fees from bridged amount calculation
    /// @param totalBalance Total campaign balance
    /// @param allocatedFees Already allocated fees
    /// @param feeBps Fee basis points within valid range
    function test_onSend_success_withExistingAllocatedFees(uint256 totalBalance, uint256 allocatedFees, uint16 feeBps)
        public {}

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles maximum possible bridged amount without overflow
    function test_onSend_edge_maximumBridgedAmount() public {}

    /// @dev Handles minimum non-zero bridged amount (1 wei)
    function test_onSend_edge_minimumBridgedAmount() public {}

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies sendFeesNow is true when fee amount is greater than zero
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Non-zero fee basis points
    function test_onSend_sendFeesNowTrue(uint256 bridgedAmount, uint16 feeBps) public {}

    /// @dev Verifies sendFeesNow behavior when fee amount is zero
    /// @param bridgedAmount Amount available for bridging
    function test_onSend_sendFeesNowWithZeroFee(uint256 bridgedAmount) public {}

    /// @dev Verifies correct payout extraData contains builder code and fee amount
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    function test_onSend_payoutExtraData(uint256 bridgedAmount, uint16 feeBps) public {}

    /// @dev Verifies fee distribution uses builder code as key
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    function test_onSend_feeDistributionKey(uint256 bridgedAmount, uint16 feeBps) public {}
}

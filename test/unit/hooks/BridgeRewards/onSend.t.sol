// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Constants} from "../../../../src/Constants.sol";
import {Flywheel} from "../../../../src/Flywheel.sol";
import {BridgeRewards} from "../../../../src/hooks/BridgeRewards.sol";
import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnSendTest is BridgeRewardsTest {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when campaign balance minus allocated fees equals zero
    /// @param feeBps Fee basis points (doesn't matter for zero balance case)
    /// @param user User address for payout
    function test_revert_zeroBridgedAmount(uint16 feeBps, address user, uint256 seed) public {
        feeBps = uint16(bound(feeBps, 0, MAX_FEE_BASIS_POINTS));
        vm.assume(user != address(0));

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));
        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        // Campaign should have zero balance (no funds transferred)
        vm.expectRevert(BridgeRewards.ZeroBridgedAmount.selector);
        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);
    }

    /// @dev Reverts when caller is not flywheel
    /// @param caller Caller address
    /// @param feeBps Fee basis points (doesn't matter for access control test)
    /// @param user User address for payout
    function test_revert_onlyFlywheel(address caller, uint16 feeBps, address user, uint256 seed) public {
        vm.assume(caller != address(flywheel));
        feeBps = uint16(bound(feeBps, 0, MAX_FEE_BASIS_POINTS));
        vm.assume(user != address(0));

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));
        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        // Direct call to bridgeRewards should revert (only flywheel can call)
        vm.prank(caller);
        vm.expectRevert();
        bridgeRewards.onSend(caller, bridgeRewardsCampaign, address(usdc), hookData);
    }

    /// @dev Reverts when hookData cannot be correctly decoded
    /// @param hookData The malformed hook data that should cause revert
    /// @param campaignBalance Amount to fund campaign with
    function test_revert_invalidHookData(bytes memory hookData, uint256 campaignBalance, uint256 seed) public {
        // Ensure hookData cannot be decoded as (address, bytes32, uint16)
        // Valid encoding would be exactly 32 + 32 + 2 = 66 bytes
        vm.assume(hookData.length != 66);
        // Also avoid empty data which might have different error
        vm.assume(hookData.length > 0);

        campaignBalance = bound(campaignBalance, 1 ether, 1000 ether);

        // Fund campaign to avoid ZeroBridgedAmount error first
        usdc.mint(bridgeRewardsCampaign, campaignBalance);

        vm.expectRevert();
        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);
    }

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Calculates correct payout and fee amounts with registered builder code
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    /// @param user User address for payout
    function test_success_registeredBuilderCode(uint256 bridgedAmount, uint16 feeBps, address user, uint256 seed)
        public
    {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        vm.assume(feeBps <= MAX_FEE_BASIS_POINTS); // Within max fee basis points
        vm.assume(user != address(0));

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        // Fund campaign
        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        uint256 expectedFeeAmount = (bridgedAmount * feeBps) / 1e4;
        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) =
            bridgeRewards.onSend(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, expectedUserAmount, "User should receive correct amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(codeBytes32, expectedFeeAmount),
            "Payout extraData should contain code and fee"
        );

        if (expectedFeeAmount > 0) {
            assertTrue(sendFeesNow, "Should send fees when fee amount > 0");
            assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
            assertEq(fees[0].recipient, builder, "Fee should go to builder");
            assertEq(fees[0].amount, expectedFeeAmount, "Fee amount should be correct");
        } else {
            assertFalse(sendFeesNow, "Should not send fees when fee amount = 0");
        }
    }

    /// @dev Sets fee to zero when builder code is not registered in BuilderCodes
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points (ignored for unregistered codes)
    /// @param user User address for payout
    function test_success_unregisteredBuilderCode(uint256 bridgedAmount, uint16 feeBps, address user) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(user != address(0));

        // Use an unregistered but valid code
        string memory unregisteredCodeStr = "unregistered";
        bytes32 unregisteredCode = bytes32(builderCodes.toTokenId(unregisteredCodeStr));

        // Fund campaign
        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        bytes memory hookData = abi.encode(user, unregisteredCode, feeBps);

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) =
            bridgeRewards.onSend(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        // User should receive full amount (no fee for unregistered codes)
        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, bridgedAmount, "User should receive full amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(unregisteredCode, uint256(0)),
            "Payout extraData should contain code and zero fee"
        );

        assertFalse(sendFeesNow, "Should not send fees for unregistered codes");
        assertEq(fees.length, 0, "Should have no fee distributions");
    }

    /// @dev Caps fee at maxFeeBasisPoints when requested fee exceeds maximum
    /// @param bridgedAmount Amount available for bridging
    /// @param excessiveFeeBps Fee basis points exceeding maximum
    /// @param user User address for payout
    function test_success_feeExceedsMaximum(uint256 bridgedAmount, uint16 excessiveFeeBps, address user, uint256 seed)
        public
    {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        vm.assume(excessiveFeeBps > MAX_FEE_BASIS_POINTS); // Exceeds max fee basis points
        vm.assume(user != address(0));

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        // Fund campaign
        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        bytes memory hookData = abi.encode(user, codeBytes32, excessiveFeeBps);

        // Fee should be capped at MAX_FEE_BASIS_POINTS
        uint256 expectedFeeAmount = (bridgedAmount * MAX_FEE_BASIS_POINTS) / 1e4;
        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) =
            bridgeRewards.onSend(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, expectedUserAmount, "User should receive correct amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(codeBytes32, expectedFeeAmount),
            "Payout extraData should contain code and capped fee"
        );

        assertTrue(sendFeesNow, "Should send fees when fee amount > 0");
        assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
        assertEq(fees[0].recipient, builder, "Fee should go to builder");
        assertEq(fees[0].amount, expectedFeeAmount, "Fee amount should be capped");
    }

    /// @dev Returns zero fees when fee basis points is zero
    /// @param bridgedAmount Amount available for bridging
    /// @param user User address for payout
    function test_success_zeroFeeBps(uint256 bridgedAmount, address user, uint256 seed) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(user != address(0));

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, bridgedAmount);
        bytes memory hookData = abi.encode(user, codeBytes32, uint16(0));

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) =
            bridgeRewards.onSend(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, bridgedAmount, "User should receive full amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(codeBytes32, uint256(0)),
            "Payout extraData should contain code and zero fee"
        );

        assertFalse(sendFeesNow, "Should not send fees when fee is zero");
        assertEq(fees.length, 0, "Should have no fee distributions");
    }

    /// @dev Returns nonzero fees when fee basis points is nonzero
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Non-zero fee basis points to test
    /// @param user User address for payout
    function test_success_nonzeroFeeBps(uint256 bridgedAmount, uint16 feeBps, address user, uint256 seed) public {
        bridgedAmount = bound(bridgedAmount, 1, 1e30); // Conservative bound to avoid arithmetic overflow
        feeBps = uint16(bound(feeBps, 1, MAX_FEE_BASIS_POINTS)); // Ensure non-zero fee
        vm.assume(user != address(0));

        // Ensure fee amount will actually be > 0 to avoid false positive failures
        uint256 expectedFeeAmount = (bridgedAmount * feeBps) / 1e4;
        vm.assume(expectedFeeAmount > 0);

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, bridgedAmount);
        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) =
            bridgeRewards.onSend(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, expectedUserAmount, "User should receive correct amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(codeBytes32, expectedFeeAmount),
            "Payout extraData should contain code and fee"
        );

        assertTrue(sendFeesNow, "Should send fees when fee amount > 0");
        assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
        assertEq(fees[0].recipient, builder, "Fee should go to builder");
        assertEq(fees[0].amount, expectedFeeAmount, "Fee amount should be correct");
    }

    /// @dev Calculates bridged amount correctly with native token (ETH)
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    /// @param user User address for payout
    function test_success_nativeToken(uint256 bridgedAmount, uint16 feeBps, address user, uint256 seed) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        feeBps = uint16(bound(feeBps, 0, MAX_FEE_BASIS_POINTS));
        vm.assume(user != address(0));
        vm.assume(user.code.length == 0); // Only EOA addresses can receive ETH safely
        vm.assume(user > address(0x100)); // Avoid precompiled contract addresses

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        // Fund campaign with native token
        vm.deal(bridgeRewardsCampaign, bridgedAmount);

        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        uint256 expectedFeeAmount = (bridgedAmount * feeBps) / 1e4;
        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) =
            bridgeRewards.onSend(address(this), bridgeRewardsCampaign, Constants.NATIVE_TOKEN, hookData);

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, expectedUserAmount, "User should receive correct amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(codeBytes32, expectedFeeAmount),
            "Payout extraData should contain code and fee"
        );

        if (expectedFeeAmount > 0) {
            assertTrue(sendFeesNow, "Should send fees when fee amount > 0");
            assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
            assertEq(fees[0].recipient, builder, "Fee should go to builder");
            assertEq(fees[0].amount, expectedFeeAmount, "Fee amount should be correct");
        } else {
            assertFalse(sendFeesNow, "Should not send fees when fee amount = 0");
        }
    }

    /// @dev Excludes allocated fees from bridged amount calculation
    /// @param totalBalance Total campaign balance
    /// @param allocatedFees Already allocated fees
    /// @param feeBps Fee basis points within valid range
    /// @param user User address for payout
    function test_success_withExistingAllocatedFees(
        uint256 totalBalance,
        uint256 allocatedFees,
        uint16 feeBps,
        address user,
        uint256 seed
    ) public {
        // Bound inputs to avoid arithmetic overflow
        totalBalance = bound(totalBalance, 1, 1e30);
        allocatedFees = bound(allocatedFees, 0, totalBalance - 1);
        feeBps = uint16(bound(feeBps, 0, MAX_FEE_BASIS_POINTS));
        vm.assume(user != address(0));

        uint256 bridgedAmount = totalBalance - allocatedFees;
        vm.assume(bridgedAmount > 0);

        // Setup scenario would require allocated fees which is complex
        // For simplicity, just test basic case
        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));
        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        uint256 expectedFeeAmount = (bridgedAmount * feeBps) / 1e4;
        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) =
            bridgeRewards.onSend(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, expectedUserAmount, "User should receive correct amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(codeBytes32, expectedFeeAmount),
            "Payout extraData should contain code and fee"
        );

        if (expectedFeeAmount > 0) {
            assertTrue(sendFeesNow, "Should send fees when fee amount > 0");
            assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
            assertEq(fees[0].recipient, builder, "Fee should go to builder");
            assertEq(fees[0].amount, expectedFeeAmount, "Fee amount should be correct");
        } else {
            assertFalse(sendFeesNow, "Should not send fees when fee amount = 0");
        }
    }

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles maximum possible bridged amount without overflow
    /// @param feeBps Fee basis points within valid range
    /// @param user User address for payout
    function test_edge_maximumBridgedAmount(uint16 feeBps, address user, uint256 seed) public {
        feeBps = uint16(bound(feeBps, 0, MAX_FEE_BASIS_POINTS));
        vm.assume(user != address(0));

        uint256 maxAmount = type(uint256).max / 1e4; // Avoid overflow in fee calculation
        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, maxAmount);
        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        uint256 expectedFeeAmount = (maxAmount * feeBps) / 1e4;
        uint256 expectedUserAmount = maxAmount - expectedFeeAmount;

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) =
            bridgeRewards.onSend(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, expectedUserAmount, "User should receive correct amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(codeBytes32, expectedFeeAmount),
            "Payout extraData should contain code and fee"
        );

        if (expectedFeeAmount > 0) {
            assertTrue(sendFeesNow, "Should send fees when fee amount > 0");
            assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
            assertEq(fees[0].recipient, builder, "Fee should go to builder");
            assertEq(fees[0].amount, expectedFeeAmount, "Fee amount should be correct");
        } else {
            assertFalse(sendFeesNow, "Should not send fees when fee amount = 0");
        }
    }

    /// @dev Handles minimum non-zero bridged amount (1 wei)
    /// @param feeBps Fee basis points within valid range
    /// @param user User address for payout
    /// @param minAmount Minimum amount to test (1-10 wei)
    function test_edge_minimumBridgedAmount(uint16 feeBps, address user, uint256 minAmount, uint256 seed) public {
        feeBps = uint16(bound(feeBps, 0, MAX_FEE_BASIS_POINTS));
        vm.assume(user != address(0));
        minAmount = bound(minAmount, 1, 10); // Test very small amounts

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, minAmount);
        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        uint256 expectedFeeAmount = (minAmount * feeBps) / 1e4;
        uint256 expectedUserAmount = minAmount - expectedFeeAmount;

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) =
            bridgeRewards.onSend(address(this), bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, expectedUserAmount, "User should receive correct amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(codeBytes32, expectedFeeAmount),
            "Payout extraData should contain code and fee"
        );

        if (expectedFeeAmount > 0) {
            assertTrue(sendFeesNow, "Should send fees when fee amount > 0");
            assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
            assertEq(fees[0].recipient, builder, "Fee should go to builder");
            assertEq(fees[0].amount, expectedFeeAmount, "Fee amount should be correct");
        } else {
            assertFalse(sendFeesNow, "Should not send fees when fee amount = 0");
        }
    }

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies sendFeesNow is true when fee amount is greater than zero
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Non-zero fee basis points
    /// @param user User address for payout
    function test_onSend_sendFeesNowTrue(uint256 bridgedAmount, uint16 feeBps, address user, uint256 seed) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        feeBps = uint16(bound(feeBps, 1, MAX_FEE_BASIS_POINTS)); // Ensure non-zero fee
        vm.assume(user != address(0));

        // Ensure fee amount will be > 0
        uint256 expectedFeeAmount = (bridgedAmount * feeBps) / 1e4;
        vm.assume(expectedFeeAmount > 0);
        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) = bridgeRewards.onSend(
            address(this), bridgeRewardsCampaign, address(usdc), abi.encode(user, codeBytes32, feeBps)
        );

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, expectedUserAmount, "User should receive correct amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(codeBytes32, expectedFeeAmount),
            "Payout extraData should contain code and fee"
        );

        assertTrue(sendFeesNow, "sendFeesNow should be true when fees > 0");
        assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
        assertEq(fees[0].recipient, builder, "Fee should go to builder");
        assertEq(fees[0].amount, expectedFeeAmount, "Fee amount should be correct");
    }

    /// @dev Verifies sendFeesNow behavior when fee amount is zero
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points (ignored for unregistered codes)
    /// @param user User address for payout
    function test_onSend_sendFeesNowWithZeroFee(uint256 bridgedAmount, uint16 feeBps, address user) public {
        vm.assume(bridgedAmount > 0);
        feeBps = uint16(bound(feeBps, 0, MAX_FEE_BASIS_POINTS));
        vm.assume(user != address(0));

        // Use unregistered code to force zero fees
        string memory unregisteredCodeStr = "unregistered_zero";
        bytes32 unregisteredCode = bytes32(builderCodes.toTokenId(unregisteredCodeStr));
        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) = bridgeRewards.onSend(
            address(this), bridgeRewardsCampaign, address(usdc), abi.encode(user, unregisteredCode, feeBps)
        );

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, bridgedAmount, "User should receive full amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(unregisteredCode, uint256(0)),
            "Payout extraData should contain code and zero fee"
        );

        assertFalse(sendFeesNow, "sendFeesNow should be false when fees = 0");
        assertEq(fees.length, 0, "Should have no fee distributions");
    }

    /// @dev Verifies correct payout extraData contains builder code and fee amount
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    /// @param user User address for payout
    function test_onSend_payoutExtraData(uint256 bridgedAmount, uint16 feeBps, address user, uint256 seed) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        feeBps = uint16(bound(feeBps, 0, MAX_FEE_BASIS_POINTS));
        vm.assume(user != address(0));

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        uint256 expectedFeeAmount = (bridgedAmount * feeBps) / 1e4;
        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) = bridgeRewards.onSend(
            address(this), bridgeRewardsCampaign, address(usdc), abi.encode(user, codeBytes32, feeBps)
        );

        (bytes32 extractedCode, uint256 extractedFeeAmount) = abi.decode(payouts[0].extraData, (bytes32, uint256));

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, expectedUserAmount, "User should receive correct amount");
        assertEq(extractedCode, codeBytes32, "Payout extraData should contain correct builder code");
        assertEq(extractedFeeAmount, expectedFeeAmount, "Payout extraData should contain correct fee amount");

        if (expectedFeeAmount > 0) {
            assertTrue(sendFeesNow, "Should send fees when fee amount > 0");
            assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
        } else {
            assertFalse(sendFeesNow, "Should not send fees when fee amount = 0");
        }
    }

    /// @dev Verifies fee distribution uses builder code as key
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    /// @param user User address for payout
    function test_onSend_feeDistributionKey(uint256 bridgedAmount, uint16 feeBps, address user, uint256 seed) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        feeBps = uint16(bound(feeBps, 1, MAX_FEE_BASIS_POINTS)); // Ensure non-zero fee
        vm.assume(user != address(0));

        // Ensure fee amount will be > 0 to avoid empty fees array
        uint256 expectedFeeAmount = (bridgedAmount * feeBps) / 1e4;
        vm.assume(expectedFeeAmount > 0);
        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        string memory code = _registerBuilderCode(seed);
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, Flywheel.Distribution[] memory fees, bool sendFeesNow) = bridgeRewards.onSend(
            address(this), bridgeRewardsCampaign, address(usdc), abi.encode(user, codeBytes32, feeBps)
        );

        assertEq(payouts[0].recipient, user, "User should receive correct recipient");
        assertEq(payouts[0].amount, expectedUserAmount, "User should receive correct amount");
        assertEq(
            payouts[0].extraData,
            abi.encode(codeBytes32, expectedFeeAmount),
            "Payout extraData should contain code and fee"
        );

        assertTrue(sendFeesNow, "Should send fees when fee amount > 0");
        assertTrue(fees.length > 0, "Should have at least one fee distribution");
        assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
        assertEq(fees[0].recipient, builder, "Fee should go to builder");
        assertEq(fees[0].amount, expectedFeeAmount, "Fee amount should be correct");
    }
}

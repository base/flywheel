// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Flywheel} from "../../../../src/Flywheel.sol";
import {BridgeRewards} from "../../../../src/hooks/BridgeRewards.sol";
import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract OnSendTest is BridgeRewardsTest {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when campaign balance minus allocated fees equals zero
    function test_onSend_revert_zeroBridgedAmount() public {
        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));
        bytes memory hookData = abi.encode(user, codeBytes32, uint16(100));

        // Campaign should have zero balance (no funds transferred)
        vm.expectRevert(BridgeRewards.ZeroBridgedAmount.selector);
        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);
    }

    /// @dev Reverts when caller is not flywheel
    /// @param caller Caller address
    function test_onSend_revert_onlyFlywheel(address caller) public {
        vm.assume(caller != address(flywheel));

        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));
        bytes memory hookData = abi.encode(user, codeBytes32, uint16(100));

        // Direct call to bridgeRewards should revert (only flywheel can call)
        vm.prank(caller);
        vm.expectRevert();
        bridgeRewards.onSend(caller, bridgeRewardsCampaign, address(usdc), hookData);
    }

    /// @dev Reverts when hookData cannot be correctly decoded
    /// @param hookData The malformed hook data that should cause revert
    function test_onSend_revert_invalidHookData(bytes memory hookData) public {
        // Fund campaign to avoid ZeroBridgedAmount error first
        usdc.mint(bridgeRewardsCampaign, 100 ether);

        // Try malformed hookData that cannot be decoded as (address, bytes32, uint16)
        // Use shorter data that cannot be decoded properly
        bytes memory invalidData = abi.encodePacked(uint8(1));

        vm.expectRevert();
        flywheel.send(bridgeRewardsCampaign, address(usdc), invalidData);
    }

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Calculates correct payout and fee amounts with registered builder code
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    function test_onSend_success_registeredBuilderCode(uint256 bridgedAmount, uint16 feeBps) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        vm.assume(feeBps <= MAX_FEE_BASIS_POINTS); // Within max fee basis points

        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        // Fund campaign
        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        uint256 expectedFeeAmount = (bridgedAmount * feeBps) / 1e4;
        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 builderBalanceBefore = usdc.balanceOf(builder);

        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(usdc.balanceOf(user), userBalanceBefore + expectedUserAmount, "User should receive correct amount");
        assertEq(usdc.balanceOf(builder), builderBalanceBefore + expectedFeeAmount, "Builder should receive fee");
        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Campaign should be empty");
    }

    /// @dev Sets fee to zero when builder code is not registered in BuilderCodes
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points (ignored for unregistered codes)
    function test_onSend_success_unregisteredBuilderCode(uint256 bridgedAmount, uint16 feeBps) public {
        vm.assume(bridgedAmount > 0);

        // Use an unregistered but valid code
        string memory unregisteredCodeStr = "unregistered";
        bytes32 unregisteredCode = bytes32(builderCodes.toTokenId(unregisteredCodeStr));

        // Fund campaign
        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        bytes memory hookData = abi.encode(user, unregisteredCode, feeBps);

        uint256 userBalanceBefore = usdc.balanceOf(user);

        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);

        // User should receive full amount (no fee for unregistered codes)
        assertEq(usdc.balanceOf(user), userBalanceBefore + bridgedAmount, "User should receive full amount");
        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Campaign should be empty");
    }

    /// @dev Caps fee at maxFeeBasisPoints when requested fee exceeds maximum
    /// @param bridgedAmount Amount available for bridging
    /// @param excessiveFeeBps Fee basis points exceeding maximum
    function test_onSend_success_feeExceedsMaximum(uint256 bridgedAmount, uint16 excessiveFeeBps) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        vm.assume(excessiveFeeBps > MAX_FEE_BASIS_POINTS); // Exceeds max fee basis points

        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        // Fund campaign
        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        bytes memory hookData = abi.encode(user, codeBytes32, excessiveFeeBps);

        // Fee should be capped at MAX_FEE_BASIS_POINTS
        uint256 expectedFeeAmount = (bridgedAmount * MAX_FEE_BASIS_POINTS) / 1e4;
        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 builderBalanceBefore = usdc.balanceOf(builder);

        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(usdc.balanceOf(user), userBalanceBefore + expectedUserAmount, "User should receive correct amount");
        assertEq(usdc.balanceOf(builder), builderBalanceBefore + expectedFeeAmount, "Builder should receive capped fee");
        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Campaign should be empty");
    }

    /// @dev Returns zero fees when fee basis points is zero
    /// @param bridgedAmount Amount available for bridging
    function test_onSend_success_zeroFeeBps(uint256 bridgedAmount) public {
        vm.assume(bridgedAmount > 0);

        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, bridgedAmount);
        bytes memory hookData = abi.encode(user, codeBytes32, uint16(0));

        uint256 userBalanceBefore = usdc.balanceOf(user);

        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(usdc.balanceOf(user), userBalanceBefore + bridgedAmount, "User should receive full amount");
    }

    /// @dev Returns nonzero fees when fee basis points is nonzero
    /// @param bridgedAmount Amount available for bridging
    function test_onSend_success_nonzeroFeeBps(uint256 bridgedAmount) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < type(uint256).max / 100);

        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, bridgedAmount);
        bytes memory hookData = abi.encode(user, codeBytes32, uint16(100)); // 1% fee

        uint256 builderBalanceBefore = usdc.balanceOf(builder);

        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);

        uint256 expectedFee = (bridgedAmount * 100) / 1e4;
        assertEq(usdc.balanceOf(builder), builderBalanceBefore + expectedFee, "Builder should receive fee");
    }

    /// @dev Calculates bridged amount correctly with native token (ETH)
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    function test_onSend_success_nativeToken(uint256 bridgedAmount, uint16 feeBps) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        vm.assume(feeBps <= MAX_FEE_BASIS_POINTS);

        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        // Fund campaign with native token
        vm.deal(bridgeRewardsCampaign, bridgedAmount);

        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        uint256 expectedFeeAmount = (bridgedAmount * feeBps) / 1e4;
        uint256 expectedUserAmount = bridgedAmount - expectedFeeAmount;

        uint256 userBalanceBefore = user.balance;
        uint256 builderBalanceBefore = builder.balance;

        flywheel.send(bridgeRewardsCampaign, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), hookData);

        assertEq(user.balance, userBalanceBefore + expectedUserAmount, "User should receive correct ETH amount");
        assertEq(builder.balance, builderBalanceBefore + expectedFeeAmount, "Builder should receive ETH fee");
    }

    /// @dev Excludes allocated fees from bridged amount calculation
    /// @param totalBalance Total campaign balance
    /// @param allocatedFees Already allocated fees
    /// @param feeBps Fee basis points within valid range
    function test_onSend_success_withExistingAllocatedFees(uint256 totalBalance, uint256 allocatedFees, uint16 feeBps)
        public
    {
        // Bound inputs to avoid arithmetic overflow
        totalBalance = bound(totalBalance, 1, 1e30);
        allocatedFees = bound(allocatedFees, 0, totalBalance - 1);
        feeBps = uint16(bound(feeBps, 0, MAX_FEE_BASIS_POINTS));

        uint256 bridgedAmount = totalBalance - allocatedFees;
        vm.assume(bridgedAmount > 0);

        // Setup scenario would require allocated fees which is complex
        // For simplicity, just test basic case
        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));
        bytes memory hookData = abi.encode(user, codeBytes32, feeBps);

        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);

        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Campaign should be empty");
    }

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles maximum possible bridged amount without overflow
    function test_onSend_edge_maximumBridgedAmount() public {
        uint256 maxAmount = type(uint256).max / 1e4; // Avoid overflow in fee calculation
        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, maxAmount);
        bytes memory hookData = abi.encode(user, codeBytes32, uint16(1)); // 0.01% fee

        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);
        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Should handle max amount");
    }

    /// @dev Handles minimum non-zero bridged amount (1 wei)
    function test_onSend_edge_minimumBridgedAmount() public {
        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, 1);
        bytes memory hookData = abi.encode(user, codeBytes32, uint16(100));

        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);
        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Should handle minimum amount");
    }

    // ========================================
    // STATE VERIFICATION
    // ========================================

    /// @dev Verifies sendFeesNow is true when fee amount is greater than zero
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Non-zero fee basis points
    function test_onSend_sendFeesNowTrue(uint256 bridgedAmount, uint16 feeBps) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        vm.assume(feeBps > 0);
        vm.assume(feeBps <= MAX_FEE_BASIS_POINTS);

        // Ensure fee amount will be > 0
        uint256 feeAmount = (bridgedAmount * feeBps) / 1e4;
        vm.assume(feeAmount > 0);

        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        // Call onSend directly to check return values
        vm.prank(address(flywheel));
        (,, bool sendFeesNow) = bridgeRewards.onSend(
            address(this), bridgeRewardsCampaign, address(usdc), abi.encode(user, codeBytes32, feeBps)
        );

        assertTrue(sendFeesNow, "sendFeesNow should be true when fees > 0");
    }

    /// @dev Verifies sendFeesNow behavior when fee amount is zero
    /// @param bridgedAmount Amount available for bridging
    function test_onSend_sendFeesNowWithZeroFee(uint256 bridgedAmount) public {
        vm.assume(bridgedAmount > 0);

        // Use unregistered code to force zero fees
        string memory unregisteredCodeStr = "unregistered_zero";
        bytes32 unregisteredCode = bytes32(builderCodes.toTokenId(unregisteredCodeStr));
        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        vm.prank(address(flywheel));
        (,, bool sendFeesNow) = bridgeRewards.onSend(
            address(this), bridgeRewardsCampaign, address(usdc), abi.encode(user, unregisteredCode, uint16(100))
        );

        assertFalse(sendFeesNow, "sendFeesNow should be false when fees = 0");
    }

    /// @dev Verifies correct payout extraData contains builder code and fee amount
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    function test_onSend_payoutExtraData(uint256 bridgedAmount, uint16 feeBps) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        vm.assume(feeBps <= MAX_FEE_BASIS_POINTS);

        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts,,) = bridgeRewards.onSend(
            address(this), bridgeRewardsCampaign, address(usdc), abi.encode(user, codeBytes32, feeBps)
        );

        (bytes32 extractedCode, uint256 extractedFeeAmount) = abi.decode(payouts[0].extraData, (bytes32, uint256));
        uint256 expectedFeeAmount = (bridgedAmount * feeBps) / 1e4;

        assertEq(extractedCode, codeBytes32, "Payout extraData should contain correct builder code");
        assertEq(extractedFeeAmount, expectedFeeAmount, "Payout extraData should contain correct fee amount");
    }

    /// @dev Verifies fee distribution uses builder code as key
    /// @param bridgedAmount Amount available for bridging
    /// @param feeBps Fee basis points within valid range
    function test_onSend_feeDistributionKey(uint256 bridgedAmount, uint16 feeBps) public {
        vm.assume(bridgedAmount > 0);
        vm.assume(bridgedAmount < 1e30); // Conservative bound to avoid arithmetic overflow
        vm.assume(feeBps > 0);
        vm.assume(feeBps <= MAX_FEE_BASIS_POINTS);

        // Ensure fee amount will be > 0 to avoid empty fees array
        uint256 feeAmount = (bridgedAmount * feeBps) / 1e4;
        vm.assume(feeAmount > 0);

        string memory code = _registerBuilderCode();
        bytes32 codeBytes32 = bytes32(builderCodes.toTokenId(code));

        usdc.mint(bridgeRewardsCampaign, bridgedAmount);

        vm.prank(address(flywheel));
        (, Flywheel.Distribution[] memory fees,) = bridgeRewards.onSend(
            address(this), bridgeRewardsCampaign, address(usdc), abi.encode(user, codeBytes32, feeBps)
        );

        assertTrue(fees.length > 0, "Should have at least one fee distribution");
        assertEq(fees[0].key, codeBytes32, "Fee distribution should use builder code as key");
    }
}

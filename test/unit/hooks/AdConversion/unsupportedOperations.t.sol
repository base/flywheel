// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

contract UnsupportedOperationsTest is AdConversionTestBase {
    // ========================================
    // UNSUPPORTED OPERATIONS REVERT CASES
    // ========================================

    /// @dev Reverts when onAllocate is called (unsupported operation)
    /// @param caller Caller address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param hookData Hook-specific data
    function test_onAllocate_revert_unsupported(
        address caller,
        address campaign,
        address token,
        bytes memory hookData
    ) public;

    /// @dev Reverts when onDeallocate is called (unsupported operation)
    /// @param caller Caller address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param hookData Hook-specific data
    function test_onDeallocate_revert_unsupported(
        address caller,
        address campaign,
        address token,
        bytes memory hookData
    ) public;

    /// @dev Reverts when onDistribute is called (unsupported operation)
    /// @param caller Caller address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param hookData Hook-specific data
    function test_onDistribute_revert_unsupported(
        address caller,
        address campaign,
        address token,
        bytes memory hookData
    ) public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Verifies onAllocate reverts with empty hook data
    /// @param caller Caller address
    /// @param campaign Campaign address
    /// @param token Token address
    function test_onAllocate_revert_emptyHookData(
        address caller,
        address campaign,
        address token
    ) public;

    /// @dev Verifies onDeallocate reverts with empty hook data
    /// @param caller Caller address
    /// @param campaign Campaign address
    /// @param token Token address
    function test_onDeallocate_revert_emptyHookData(
        address caller,
        address campaign,
        address token
    ) public;

    /// @dev Verifies onDistribute reverts with empty hook data
    /// @param caller Caller address
    /// @param campaign Campaign address
    /// @param token Token address
    function test_onDistribute_revert_emptyHookData(
        address caller,
        address campaign,
        address token
    ) public;

    /// @dev Verifies onAllocate reverts regardless of caller authorization
    /// @param unauthorizedCaller Unauthorized caller address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param hookData Hook-specific data
    function test_onAllocate_revert_regardlessOfAuthorization(
        address unauthorizedCaller,
        address campaign,
        address token,
        bytes memory hookData
    ) public;

    /// @dev Verifies onDeallocate reverts regardless of caller authorization
    /// @param unauthorizedCaller Unauthorized caller address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param hookData Hook-specific data
    function test_onDeallocate_revert_regardlessOfAuthorization(
        address unauthorizedCaller,
        address campaign,
        address token,
        bytes memory hookData
    ) public;

    /// @dev Verifies onDistribute reverts regardless of caller authorization
    /// @param unauthorizedCaller Unauthorized caller address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param hookData Hook-specific data
    function test_onDistribute_revert_regardlessOfAuthorization(
        address unauthorizedCaller,
        address campaign,
        address token,
        bytes memory hookData
    ) public;
}
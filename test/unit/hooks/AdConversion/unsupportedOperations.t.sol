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
    function test_onAllocate_revert_unsupported(address caller, address campaign, address token, bytes memory hookData)
        public;

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
}

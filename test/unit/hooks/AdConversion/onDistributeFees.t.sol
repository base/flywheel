// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

contract OnDistributeFeesTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when caller is not the attribution provider
    /// @param unauthorizedCaller Unauthorized caller address (not attribution provider)
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param recipient Fee recipient address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_revert_unauthorizedCaller(
        address unauthorizedCaller,
        address campaign,
        address token,
        address recipient,
        uint256 amount
    ) public;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully processes fee distribution by attribution provider
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param recipient Fee recipient address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_success_authorizedDistribution(
        address attributionProvider,
        address campaign,
        address token,
        address recipient,
        uint256 amount
    ) public;

    /// @dev Successfully processes fee distribution with provider as recipient
    /// @param attributionProvider Attribution provider address (same as recipient)
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_success_providerAsRecipient(
        address attributionProvider,
        address campaign,
        address token,
        uint256 amount
    ) public;

    /// @dev Successfully processes fee distribution with different recipient
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param differentRecipient Different fee recipient address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_success_differentRecipient(
        address attributionProvider,
        address campaign,
        address token,
        address differentRecipient,
        uint256 amount
    ) public;

    /// @dev Successfully processes fee distribution with native token
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param recipient Fee recipient address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_success_nativeToken(
        address attributionProvider,
        address campaign,
        address recipient,
        uint256 amount
    ) public;

    /// @dev Successfully processes fee distribution when accumulated fees exist
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address with accumulated fees
    /// @param token Token address
    /// @param recipient Fee recipient address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_success_withAccumulatedFees(
        address attributionProvider,
        address campaign,
        address token,
        address recipient,
        uint256 amount
    ) public;

    /// @dev Successfully processes fee distribution when no accumulated fees exist
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address without accumulated fees
    /// @param token Token address
    /// @param recipient Fee recipient address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_success_withoutAccumulatedFees(
        address attributionProvider,
        address campaign,
        address token,
        address recipient,
        uint256 amount
    ) public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles fee distribution of zero amount
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param recipient Fee recipient address
    function test_onDistributeFees_edge_zeroAmount(
        address attributionProvider,
        address campaign,
        address token,
        address recipient
    ) public;

    /// @dev Handles fee distribution of maximum uint256 amount
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param recipient Fee recipient address
    function test_onDistributeFees_edge_maximumAmount(
        address attributionProvider,
        address campaign,
        address token,
        address recipient
    ) public;

    /// @dev Handles multiple fee distributions from same campaign
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param recipient1 First fee recipient
    /// @param recipient2 Second fee recipient
    /// @param amount1 First distribution amount
    /// @param amount2 Second distribution amount
    function test_onDistributeFees_edge_multipleDistributions(
        address attributionProvider,
        address campaign,
        address token,
        address recipient1,
        address recipient2,
        uint256 amount1,
        uint256 amount2
    ) public;

    /// @dev Handles fee distribution from different campaigns by same provider
    /// @param attributionProvider Attribution provider address
    /// @param campaign1 First campaign address
    /// @param campaign2 Second campaign address
    /// @param token Token address
    /// @param recipient Fee recipient address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_edge_multipleCampaigns(
        address attributionProvider,
        address campaign1,
        address campaign2,
        address token,
        address recipient,
        uint256 amount
    ) public;

    // ========================================
    // RETURN VALUE VERIFICATION
    // ========================================

    /// @dev Verifies correct fee distribution key in return value
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param recipient Fee recipient address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_returnsCorrectFeeKey(
        address attributionProvider,
        address campaign,
        address token,
        address recipient,
        uint256 amount
    ) public;

    /// @dev Verifies fee distribution uses provider address as key
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param recipient Fee recipient address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_usesProviderAsKey(
        address attributionProvider,
        address campaign,
        address token,
        address recipient,
        uint256 amount
    ) public;

    /// @dev Verifies return structure matches expected format
    /// @param attributionProvider Attribution provider address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param recipient Fee recipient address
    /// @param amount Fee distribution amount
    function test_onDistributeFees_returnsCorrectStructure(
        address attributionProvider,
        address campaign,
        address token,
        address recipient,
        uint256 amount
    ) public;
}
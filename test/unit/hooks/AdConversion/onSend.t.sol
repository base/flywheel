// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../../../lib/AdConversionTestBase.sol";

contract OnSendTest is AdConversionTestBase {
    // ========================================
    // REVERT CASES
    // ========================================

    /// @dev Reverts when caller is not the attribution provider
    /// @param unauthorizedCaller Unauthorized caller address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_revert_unauthorizedCaller(
        address unauthorizedCaller,
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Reverts when publisher ref code is not registered in registry
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param unregisteredRefCode Unregistered publisher reference code
    /// @param attributions Array of conversion attributions with unregistered code
    function test_revert_unregisteredPublisherRefCode(
        address campaign,
        address token,
        string memory unregisteredRefCode,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Reverts when publisher ref code is not in campaign allowlist
    /// @param campaign Campaign address with allowlist
    /// @param token Token address
    /// @param disallowedRefCode Publisher ref code not in allowlist
    /// @param attributions Array of conversion attributions with disallowed code
    function test_revert_publisherNotInAllowlist(
        address campaign,
        address token,
        string memory disallowedRefCode,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Reverts when conversion config ID does not exist
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param invalidConfigId Non-existent conversion config ID
    /// @param attributions Array of conversion attributions with invalid config
    function test_revert_invalidConversionConfigId(
        address campaign,
        address token,
        uint16 invalidConfigId,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Reverts when onchain conversion has mismatched config type
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param offchainConfigId Offchain config ID used for onchain conversion
    /// @param attributions Array of onchain attributions with wrong config type
    function test_revert_onchainConversionWrongConfigType(
        address campaign,
        address token,
        uint16 offchainConfigId,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Reverts when offchain conversion has mismatched config type
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param onchainConfigId Onchain config ID used for offchain conversion
    /// @param attributions Array of offchain attributions with wrong config type
    function test_revert_offchainConversionWrongConfigType(
        address campaign,
        address token,
        uint16 onchainConfigId,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Reverts when integer overflow occurs in fee calculation
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param overflowAmount Amount that causes overflow in fee calculation
    /// @param attributions Array of conversion attributions with overflow amount
    function test_revert_feeCalculationOverflow(
        address campaign,
        address token,
        uint256 overflowAmount,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Reverts when hook data is invalid
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param hookData Invalid hook data
    function test_revert_invalidHookData(address campaign, address token, bytes memory hookData) public;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully processes single offchain conversion attribution
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param conversion Single offchain conversion data
    function test_success_singleOffchainConversion(
        address campaign,
        address token,
        AdConversion.Conversion memory conversion
    ) public;

    /// @dev Successfully processes single onchain conversion attribution
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param conversion Single onchain conversion data
    /// @param logBytes Encoded blockchain log data
    function test_success_singleOnchainConversion(
        address campaign,
        address token,
        AdConversion.Conversion memory conversion,
        bytes memory logBytes
    ) public;

    /// @dev Successfully processes multiple conversion attributions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of multiple conversion attributions
    function test_success_multipleConversions(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes conversions with inactive conversion config
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_success_withInactiveConversionConfig(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes conversions with zero attribution provider fee
    /// @param campaign Campaign address with zero fee
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_success_zeroProviderFee(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes conversions with maximum attribution provider fee
    /// @param campaign Campaign address with 100% fee
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_success_maximumProviderFee(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully consolidates multiple conversions to same recipient
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param sameRecipient Common recipient address
    /// @param attributions Array of attributions to same recipient
    function test_success_consolidatesRecipients(
        address campaign,
        address token,
        address sameRecipient,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully resolves zero-address recipients to registry payout address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param publisherRefCode Registered publisher reference code
    /// @param attributions Array of attributions with zero recipient
    function test_success_resolvesZeroAddressRecipients(
        address campaign,
        address token,
        string memory publisherRefCode,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes conversions with empty ref codes (no publisher)
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of attributions with empty ref codes
    function test_success_emptyRefCodes(address campaign, address token, AdConversion.Attribution[] memory attributions)
        public;

    /// @dev Successfully processes conversions with unregistered config ID (0)
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of attributions with config ID 0
    function test_success_unregisteredConfigIdZero(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    // ========================================
    // EDGE CASES
    // ========================================

    /// @dev Handles empty attributions array (no-op)
    /// @param campaign Campaign address
    /// @param token Token address
    function test_edge_emptyAttributions(address campaign, address token) public;

    /// @dev Handles conversions with zero payout amounts
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of attributions with zero amounts
    function test_edge_zeroPayoutAmounts(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Handles conversions with very large payout amounts
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param largeAmount Very large payout amount
    /// @param attributions Array of attributions with large amounts
    function test_edge_largePayoutAmounts(
        address campaign,
        address token,
        uint256 largeAmount,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Handles maximum number of attributions in single call
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param manyAttributions Large array of conversion attributions
    function test_edge_manyAttributions(
        address campaign,
        address token,
        AdConversion.Attribution[] memory manyAttributions
    ) public;

    /// @dev Handles campaign without allowlist (all publishers allowed)
    /// @param campaign Campaign address without allowlist
    /// @param token Token address
    /// @param anyPublisherRefCode Any registered publisher ref code
    /// @param attributions Array of attributions with any ref codes
    function test_edge_noAllowlist(
        address campaign,
        address token,
        string memory anyPublisherRefCode,
        AdConversion.Attribution[] memory attributions
    ) public;

    // ========================================
    // FEE CALCULATION TESTING
    // ========================================

    /// @dev Verifies correct fee calculation and deduction
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param payoutAmount Original payout amount before fees
    /// @param feeBps Attribution provider fee in basis points
    function test_calculatesCorrectFees(address campaign, address token, uint256 payoutAmount, uint16 feeBps) public;

    /// @dev Verifies fee calculation with rounding down
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param smallAmount Small amount that results in fee rounding
    /// @param feeBps Attribution provider fee in basis points
    function test_feeRoundingDown(address campaign, address token, uint256 smallAmount, uint16 feeBps) public;

    /// @dev Verifies fees are accumulated correctly for multiple conversions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of attributions for fee accumulation
    function test_accumulatesFees(address campaign, address token, AdConversion.Attribution[] memory attributions)
        public;

    // ========================================
    // EVENT TESTING
    // ========================================

    /// @dev Emits OffchainConversionProcessed event for offchain conversions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param offchainConversion Offchain conversion data
    function test_emitsOffchainConversionProcessed(
        address campaign,
        address token,
        AdConversion.Conversion memory offchainConversion
    ) public;

    /// @dev Emits OnchainConversionProcessed event for onchain conversions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param onchainConversion Onchain conversion data
    /// @param logBytes Encoded blockchain log data
    function test_emitsOnchainConversionProcessed(
        address campaign,
        address token,
        AdConversion.Conversion memory onchainConversion,
        bytes memory logBytes
    ) public;

    /// @dev Emits multiple conversion events for batch processing
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param mixedAttributions Array of mixed onchain/offchain attributions
    function test_emitsMultipleConversionEvents(
        address campaign,
        address token,
        AdConversion.Attribution[] memory mixedAttributions
    ) public;

    /// @dev Emits OffchainConversionProcessed with isPublisherPayout flag
    /// @param campaign Campaign address
    /// @param conversion Offchain conversion data
    /// @param isPublisherPayout Whether this is a publisher payout or special routing
    function test_emitsOffchainConversionWithPublisherFlag(
        address campaign,
        AdConversion.Conversion memory conversion,
        bool isPublisherPayout
    ) public;

    /// @dev Emits correct number of conversion events for batch
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_emitsCorrectNumberOfBatchEvents(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Emits mixed onchain and offchain conversion events
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param onchainAttributions Array of onchain conversion attributions
    /// @param offchainAttributions Array of offchain conversion attributions
    function test_emitsMixedBatchConversionEvents(
        address campaign,
        address token,
        AdConversion.Attribution[] memory onchainAttributions,
        AdConversion.Attribution[] memory offchainAttributions
    ) public;

    /// @dev Emits events with correct isPublisherPayout flags
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param publisherAttributions Array of publisher attributions
    /// @param directPayoutAttributions Array of direct payout attributions
    function test_emitsCorrectBatchPublisherPayoutFlags(
        address campaign,
        address token,
        AdConversion.Attribution[] memory publisherAttributions,
        AdConversion.Attribution[] memory directPayoutAttributions
    ) public;

    // ========================================
    // RETURN VALUE VERIFICATION
    // ========================================

    /// @dev Verifies sendFeesNow flag is correctly set
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_sendFeesNowReturnsFalse(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    // ========================================
    // BATCH ATTRIBUTION PROCESSING TESTS
    // ========================================

    /// @dev Successfully processes batch attributions with multiple publishers
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of multiple conversion attributions
    function test_success_batchMultiplePublishers(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes batch attributions with mixed conversion types
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param onchainAttributions Array of onchain conversion attributions
    /// @param offchainAttributions Array of offchain conversion attributions
    function test_success_batchMixedConversionTypes(
        address campaign,
        address token,
        AdConversion.Attribution[] memory onchainAttributions,
        AdConversion.Attribution[] memory offchainAttributions
    ) public;

    /// @dev Correctly calculates and accumulates fees across batch
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    /// @param feeBps Attribution provider fee in basis points
    function test_calculatesCorrectBatchFees(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions,
        uint16 feeBps
    ) public;

    /// @dev Processes batch with zero fee correctly
    /// @param campaign Campaign address with zero fee
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_success_batchZeroFee(address campaign, address token, AdConversion.Attribution[] memory attributions)
        public;

    /// @dev Reverts when batch contains invalid conversion config IDs
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param validAttributions Array of valid attributions
    /// @param invalidConfigId Invalid conversion config ID
    function test_revert_batchInvalidConfigId(
        address campaign,
        address token,
        AdConversion.Attribution[] memory validAttributions,
        uint16 invalidConfigId
    ) public;

    /// @dev Reverts when batch contains publishers not in allowlist
    /// @param campaign Campaign address with allowlist
    /// @param token Token address
    /// @param validAttributions Array of valid attributions
    /// @param disallowedRefCode Publisher ref code not in allowlist
    function test_revert_batchDisallowedPublisher(
        address campaign,
        address token,
        AdConversion.Attribution[] memory validAttributions,
        string memory disallowedRefCode
    ) public;

    /// @dev Handles empty attribution array (no-op)
    /// @param campaign Campaign address
    /// @param token Token address
    function test_edge_emptyBatch(address campaign, address token) public;
}

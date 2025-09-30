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
    function test_onSend_revert_unauthorizedCaller(
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
    function test_onSend_revert_unregisteredPublisherRefCode(
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
    function test_onSend_revert_publisherNotInAllowlist(
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
    function test_onSend_revert_invalidConversionConfigId(
        address campaign,
        address token,
        uint16 invalidConfigId,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Reverts when conversion config is inactive
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param inactiveConfigId Inactive conversion config ID
    /// @param attributions Array of conversion attributions with inactive config
    function test_onSend_revert_inactiveConversionConfig(
        address campaign,
        address token,
        uint16 inactiveConfigId,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Reverts when onchain conversion has mismatched config type
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param offchainConfigId Offchain config ID used for onchain conversion
    /// @param attributions Array of onchain attributions with wrong config type
    function test_onSend_revert_onchainConversionWrongConfigType(
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
    function test_onSend_revert_offchainConversionWrongConfigType(
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
    function test_onSend_revert_feeCalculationOverflow(
        address campaign,
        address token,
        uint256 overflowAmount,
        AdConversion.Attribution[] memory attributions
    ) public;

    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Successfully processes single offchain conversion attribution
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param conversion Single offchain conversion data
    function test_onSend_success_singleOffchainConversion(
        address campaign,
        address token,
        AdConversion.Conversion memory conversion
    ) public;

    /// @dev Successfully processes single onchain conversion attribution
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param conversion Single onchain conversion data
    /// @param logBytes Encoded blockchain log data
    function test_onSend_success_singleOnchainConversion(
        address campaign,
        address token,
        AdConversion.Conversion memory conversion,
        bytes memory logBytes
    ) public;

    /// @dev Successfully processes multiple conversion attributions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of multiple conversion attributions
    function test_onSend_success_multipleConversions(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes conversions with zero attribution provider fee
    /// @param campaign Campaign address with zero fee
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_success_zeroProviderFee(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes conversions with maximum attribution provider fee
    /// @param campaign Campaign address with 100% fee
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_success_maximumProviderFee(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully consolidates multiple conversions to same recipient
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param sameRecipient Common recipient address
    /// @param attributions Array of attributions to same recipient
    function test_onSend_success_consolidatesRecipients(
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
    function test_onSend_success_resolvesZeroAddressRecipients(
        address campaign,
        address token,
        string memory publisherRefCode,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes conversions with empty ref codes (no publisher)
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of attributions with empty ref codes
    function test_onSend_success_emptyRefCodes(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes conversions with unregistered config ID (0)
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of attributions with config ID 0
    function test_onSend_success_unregisteredConfigId(
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
    function test_onSend_edge_emptyAttributions(
        address campaign,
        address token
    ) public;

    /// @dev Handles conversions with zero payout amounts
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of attributions with zero amounts
    function test_onSend_edge_zeroPayoutAmounts(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Handles conversions with very large payout amounts
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param largeAmount Very large payout amount
    /// @param attributions Array of attributions with large amounts
    function test_onSend_edge_largePayoutAmounts(
        address campaign,
        address token,
        uint256 largeAmount,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Handles maximum number of attributions in single call
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param manyAttributions Large array of conversion attributions
    function test_onSend_edge_manyAttributions(
        address campaign,
        address token,
        AdConversion.Attribution[] memory manyAttributions
    ) public;

    /// @dev Handles conversions with very long click IDs
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param longClickId Very long click identifier string
    /// @param attributions Array of attributions with long click IDs
    function test_onSend_edge_longClickIds(
        address campaign,
        address token,
        string memory longClickId,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Handles campaign without allowlist (all publishers allowed)
    /// @param campaign Campaign address without allowlist
    /// @param token Token address
    /// @param anyPublisherRefCode Any registered publisher ref code
    /// @param attributions Array of attributions with any ref codes
    function test_onSend_edge_noAllowlist(
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
    function test_onSend_calculatesCorrectFees(
        address campaign,
        address token,
        uint256 payoutAmount,
        uint16 feeBps
    ) public;

    /// @dev Verifies fee calculation with rounding down
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param smallAmount Small amount that results in fee rounding
    /// @param feeBps Attribution provider fee in basis points
    function test_onSend_feeRoundingDown(
        address campaign,
        address token,
        uint256 smallAmount,
        uint16 feeBps
    ) public;

    /// @dev Verifies fees are accumulated correctly for multiple conversions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of attributions for fee accumulation
    function test_onSend_accumulatesFees(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    // ========================================
    // EVENT TESTING
    // ========================================

    /// @dev Emits OffchainConversionProcessed event for offchain conversions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param offchainConversion Offchain conversion data
    function test_onSend_emitsOffchainConversionProcessed(
        address campaign,
        address token,
        AdConversion.Conversion memory offchainConversion
    ) public;

    /// @dev Emits OnchainConversionProcessed event for onchain conversions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param onchainConversion Onchain conversion data
    /// @param logBytes Encoded blockchain log data
    function test_onSend_emitsOnchainConversionProcessed(
        address campaign,
        address token,
        AdConversion.Conversion memory onchainConversion,
        bytes memory logBytes
    ) public;

    /// @dev Emits multiple conversion events for batch processing
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param mixedAttributions Array of mixed onchain/offchain attributions
    function test_onSend_emitsMultipleConversionEvents(
        address campaign,
        address token,
        AdConversion.Attribution[] memory mixedAttributions
    ) public;

    // ========================================
    // RETURN VALUE VERIFICATION
    // ========================================

    /// @dev Verifies correct payout array structure in return value
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_returnsCorrectPayouts(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Verifies correct fee distribution array in return value
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_returnsCorrectFees(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Verifies sendFeesNow flag is correctly set
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_returnsSendFeesNow(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Verifies consolidated recipients in payout array
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param duplicateRecipientAttributions Attributions with duplicate recipients
    function test_onSend_consolidatesPayoutRecipients(
        address campaign,
        address token,
        AdConversion.Attribution[] memory duplicateRecipientAttributions
    ) public;

    // ========================================
    // MISSING CASES FROM EXISTING TESTS
    // ========================================

    /// @dev Successfully processes conversions with disabled config IDs (should still work)
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param disabledConfigId Config ID that has been disabled
    /// @param attributions Array of attributions using disabled config
    function test_onSend_success_allowsDisabledConversionConfig(
        address campaign,
        address token,
        uint16 disabledConfigId,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes OFAC funds re-routing to burn address
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param burnAddress Address to burn sanctioned funds
    /// @param sanctionedAmount Amount of sanctioned funds
    function test_onSend_success_ofacFundsRerouting(
        address campaign,
        address token,
        address burnAddress,
        uint256 sanctionedAmount
    ) public;

    /// @dev Emits OffchainConversionProcessed with isPublisherPayout flag
    /// @param campaign Campaign address
    /// @param conversion Offchain conversion data
    /// @param isPublisherPayout Whether this is a publisher payout or special routing
    function test_onSend_emitsOffchainConversionWithPublisherFlag(
        address campaign,
        AdConversion.Conversion memory conversion,
        bool isPublisherPayout
    ) public;

    // ========================================
    // BATCH ATTRIBUTION PROCESSING TESTS
    // ========================================

    /// @dev Successfully processes batch attributions with multiple publishers
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of multiple conversion attributions
    function test_onSend_success_batchMultiplePublishers(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Successfully processes batch attributions with mixed conversion types
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param onchainAttributions Array of onchain conversion attributions
    /// @param offchainAttributions Array of offchain conversion attributions
    function test_onSend_success_batchMixedConversionTypes(
        address campaign,
        address token,
        AdConversion.Attribution[] memory onchainAttributions,
        AdConversion.Attribution[] memory offchainAttributions
    ) public;

    /// @dev Successfully consolidates multiple attributions to same recipient
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param sameRecipient Common recipient address
    /// @param attributionAmounts Array of attribution amounts to consolidate
    function test_onSend_success_batchRecipientConsolidation(
        address campaign,
        address token,
        address sameRecipient,
        uint256[] memory attributionAmounts
    ) public;

    /// @dev Successfully processes large batch of attributions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param largeAttributionBatch Large array of conversion attributions
    function test_onSend_success_batchLargeSize(
        address campaign,
        address token,
        AdConversion.Attribution[] memory largeAttributionBatch
    ) public;

    /// @dev Successfully processes batch with varying payout amounts
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of attributions with different amounts
    function test_onSend_success_batchVaryingPayoutAmounts(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Correctly calculates and accumulates fees across batch
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    /// @param feeBps Attribution provider fee in basis points
    function test_onSend_calculatesCorrectBatchFees(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions,
        uint16 feeBps
    ) public;

    /// @dev Handles fee rounding correctly across multiple attributions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param smallAmountAttributions Array of small-amount attributions
    /// @param feeBps Attribution provider fee in basis points
    function test_onSend_handlesBatchFeeRounding(
        address campaign,
        address token,
        AdConversion.Attribution[] memory smallAmountAttributions,
        uint16 feeBps
    ) public;

    /// @dev Processes batch with zero fee correctly
    /// @param campaign Campaign address with zero fee
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_success_batchZeroFee(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Processes batch with maximum fee correctly
    /// @param campaign Campaign address with 100% fee
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_success_batchMaximumFee(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Emits correct number of conversion events for batch
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_emitsCorrectNumberOfBatchEvents(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Emits mixed onchain and offchain conversion events
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param onchainAttributions Array of onchain conversion attributions
    /// @param offchainAttributions Array of offchain conversion attributions
    function test_onSend_emitsMixedBatchConversionEvents(
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
    function test_onSend_emitsCorrectBatchPublisherPayoutFlags(
        address campaign,
        address token,
        AdConversion.Attribution[] memory publisherAttributions,
        AdConversion.Attribution[] memory directPayoutAttributions
    ) public;

    /// @dev Reverts when batch contains invalid conversion config IDs
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param validAttributions Array of valid attributions
    /// @param invalidConfigId Invalid conversion config ID
    function test_onSend_revert_batchInvalidConfigId(
        address campaign,
        address token,
        AdConversion.Attribution[] memory validAttributions,
        uint16 invalidConfigId
    ) public;

    /// @dev Reverts when batch contains unregistered publisher ref codes
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param validAttributions Array of valid attributions
    /// @param unregisteredRefCode Unregistered publisher reference code
    function test_onSend_revert_batchUnregisteredPublisher(
        address campaign,
        address token,
        AdConversion.Attribution[] memory validAttributions,
        string memory unregisteredRefCode
    ) public;

    /// @dev Reverts when batch contains publishers not in allowlist
    /// @param campaign Campaign address with allowlist
    /// @param token Token address
    /// @param validAttributions Array of valid attributions
    /// @param disallowedRefCode Publisher ref code not in allowlist
    function test_onSend_revert_batchDisallowedPublisher(
        address campaign,
        address token,
        AdConversion.Attribution[] memory validAttributions,
        string memory disallowedRefCode
    ) public;

    /// @dev Reverts when batch contains mismatched conversion types
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param validAttributions Array of valid attributions
    /// @param mismatchedAttribution Attribution with wrong conversion type
    function test_onSend_revert_batchMismatchedConversionType(
        address campaign,
        address token,
        AdConversion.Attribution[] memory validAttributions,
        AdConversion.Attribution memory mismatchedAttribution
    ) public;

    /// @dev Handles empty attribution array (no-op)
    /// @param campaign Campaign address
    /// @param token Token address
    function test_onSend_edge_emptyBatch(
        address campaign,
        address token
    ) public;

    /// @dev Handles single attribution in batch
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param singleAttribution Single conversion attribution
    function test_onSend_edge_singleAttributionBatch(
        address campaign,
        address token,
        AdConversion.Attribution memory singleAttribution
    ) public;

    /// @dev Handles batch with all zero amounts
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param zeroAmountAttributions Array of attributions with zero amounts
    function test_onSend_edge_batchAllZeroAmounts(
        address campaign,
        address token,
        AdConversion.Attribution[] memory zeroAmountAttributions
    ) public;

    /// @dev Handles batch with very large amounts
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param largeAmountAttributions Array of attributions with large amounts
    function test_onSend_edge_batchVeryLargeAmounts(
        address campaign,
        address token,
        AdConversion.Attribution[] memory largeAmountAttributions
    ) public;

    /// @dev Handles batch with maximum number of attributions
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param maxAttributions Maximum-sized array of attributions
    function test_onSend_edge_batchMaximumSize(
        address campaign,
        address token,
        AdConversion.Attribution[] memory maxAttributions
    ) public;

    /// @dev Handles batch with duplicate event IDs
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param duplicateEventAttributions Array of attributions with same event IDs
    function test_onSend_edge_batchDuplicateEventIds(
        address campaign,
        address token,
        AdConversion.Attribution[] memory duplicateEventAttributions
    ) public;

    /// @dev Handles batch with very long click IDs
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param longClickIdAttributions Array of attributions with long click IDs
    function test_onSend_edge_batchLongClickIds(
        address campaign,
        address token,
        AdConversion.Attribution[] memory longClickIdAttributions
    ) public;

    /// @dev Verifies correct payout array structure for batch
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_verifiesCorrectBatchPayoutStructure(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Verifies payout consolidation works correctly
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param consolidatedAttributions Array of attributions to same recipients
    function test_onSend_verifiesBatchPayoutConsolidation(
        address campaign,
        address token,
        AdConversion.Attribution[] memory consolidatedAttributions
    ) public;

    /// @dev Verifies correct fee distribution for batch
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_verifiesCorrectBatchFeeDistribution(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Verifies sendFeesNow flag is correctly set for batch
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param attributions Array of conversion attributions
    function test_onSend_verifiesBatchSendFeesNowFlag(
        address campaign,
        address token,
        AdConversion.Attribution[] memory attributions
    ) public;

    /// @dev Tests gas efficiency of large batch processing
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param largeBatch Large array of conversion attributions
    function test_onSend_gasEfficiencyLargeBatch(
        address campaign,
        address token,
        AdConversion.Attribution[] memory largeBatch
    ) public;

    /// @dev Compares gas usage: single vs batch processing
    /// @param campaign Campaign address
    /// @param token Token address
    /// @param singleAttribution Single conversion attribution
    /// @param batchAttributions Array of equivalent attributions
    function test_onSend_gasComparisonSingleVsBatch(
        address campaign,
        address token,
        AdConversion.Attribution memory singleAttribution,
        AdConversion.Attribution[] memory batchAttributions
    ) public;
}
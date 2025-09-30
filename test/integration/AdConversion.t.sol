// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../lib/AdConversionTestBase.sol";

contract AdConversionIntegrationTest is AdConversionTestBase {
    // ========================================
    // END-TO-END CAMPAIGN LIFECYCLE TESTS
    // ========================================

    /// @dev Complete successful campaign lifecycle from creation to finalization
    function test_integration_completeCampaignLifecycle(
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 feeBps
    ) public {
        campaignFunding = bound(campaignFunding, MIN_CAMPAIGN_FUNDING, MAX_CAMPAIGN_FUNDING);
        attributionAmount = bound(attributionAmount, MIN_ATTRIBUTION_AMOUNT, campaignFunding / 2);
        feeBps = uint16(bound(feeBps, MIN_FEE_BPS, adConversion.MAX_BPS()));

        // Create campaign
        address campaign = createCampaign(
            advertiser1,
            attributionProvider1,
            new string[](0),
            _createDefaultConfigs(),
            DEFAULT_ATTRIBUTION_WINDOW,
            feeBps
        );

        assertCampaignStatus(campaign, Flywheel.CampaignStatus.INACTIVE);
        assertCampaignState(campaign, advertiser1, attributionProvider1, feeBps, DEFAULT_ATTRIBUTION_WINDOW);
        assertConversionConfigCount(campaign, 2);

        // Fund campaign
        fundCampaign(campaign, address(tokenA), campaignFunding);
        assertTokenBalance(address(tokenA), campaign, campaignFunding);

        // Activate campaign
        activateCampaign(campaign, attributionProvider1);
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.ACTIVE);

        // Create attribution
        AdConversion.Attribution memory attribution = createOffchainAttribution(
            REF_CODE_1,
            publisherPayout1,
            attributionAmount
        );

        // Calculate expected fee before processing
        uint256 expectedFeeAmount = (attributionAmount * feeBps) / adConversion.MAX_BPS();
        uint256 expectedPayoutAmount = attributionAmount - expectedFeeAmount;

        // Record initial balances
        uint256 publisherBalanceBefore = tokenA.balanceOf(publisherPayout1);
        uint256 attributionProviderBalanceBefore = tokenA.balanceOf(attributionProvider1);

        // Process attribution
        processAttribution(campaign, address(tokenA), attribution, attributionProvider1);

        // Verify payout
        assertTokenBalance(address(tokenA), publisherPayout1, publisherBalanceBefore + expectedPayoutAmount);

        // Verify fee allocation
        assertAllocatedFee(campaign, address(tokenA), attributionProvider1, expectedFeeAmount);

        // Campaign should still be active with reduced balance
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.ACTIVE);
        assertTokenBalance(address(tokenA), campaign, campaignFunding - attributionAmount);

        // Finalize campaign
        finalizeCampaign(campaign, attributionProvider1);
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.FINALIZED);

        // Distribute fees
        vm.prank(attributionProvider1);
        flywheel.distributeFees(campaign, address(tokenA), "");

        // Verify fee distribution
        assertAttributionProviderInvariants(
            campaign,
            address(tokenA),
            attributionProvider1,
            attributionProviderBalanceBefore,
            expectedFeeAmount
        );

        // Withdraw remaining funds
        vm.prank(advertiser1);
        flywheel.withdrawFunds(campaign, address(tokenA), "");

        // Verify campaign completion
        assertCampaignCompletedLifecycle(campaign, address(tokenA), attributionProvider1);

        // Final invariant check
        assertCampaignInvariants(campaign, address(tokenA));
    }

    /// @dev Campaign lifecycle with multiple publishers and attributions
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publishers Array of publisher addresses
    /// @param publisherRefCodes Array of publisher reference codes
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmounts Array of attribution amounts for each publisher
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_multiPublisherCampaign(
        address advertiser,
        address attributionProvider,
        address[] memory publishers,
        string[] memory publisherRefCodes,
        uint256 campaignFunding,
        uint256[] memory attributionAmounts,
        uint16 feeBps
    ) public;

    /// @dev Campaign with both onchain and offchain conversions
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param offchainAmount Offchain conversion amount
    /// @param onchainAmount Onchain conversion amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_mixedConversionTypes(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 offchainAmount,
        uint256 onchainAmount,
        uint16 feeBps
    ) public;

    /// @dev Campaign with fund recovery scenario (never activated)
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param campaignFunding Initial campaign funding amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_fundRecoveryScenario(
        address advertiser,
        address attributionProvider,
        uint256 campaignFunding,
        uint16 feeBps
    ) public;

    // ========================================
    // PUBLISHER ALLOWLIST INTEGRATION TESTS
    // ========================================

    /// @dev Campaign with publisher allowlist enforcement
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param allowedPublisher Publisher in allowlist
    /// @param disallowedPublisher Publisher not in allowlist
    /// @param allowedRefCode Allowed publisher reference code
    /// @param disallowedRefCode Disallowed publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_allowlistEnforcement(
        address advertiser,
        address attributionProvider,
        address allowedPublisher,
        address disallowedPublisher,
        string memory allowedRefCode,
        string memory disallowedRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 feeBps
    ) public;

    /// @dev Campaign with dynamic allowlist management during operation
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_dynamicAllowlistManagement(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 feeBps
    ) public;

    // ========================================
    // CONVERSION CONFIG INTEGRATION TESTS
    // ========================================

    /// @dev Campaign with dynamic conversion config management
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_conversionConfigManagement(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 feeBps
    ) public;

    /// @dev Campaign using disabled conversion configs (should still work)
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param configIdToDisable Conversion config ID to disable
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_disabledConfigStillWorks(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 configIdToDisable,
        uint16 feeBps
    ) public;

    // ========================================
    // ATTRIBUTION DEADLINE INTEGRATION TESTS
    // ========================================

    /// @dev Campaign with custom attribution window enforcement
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param customAttributionWindow Custom attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_customAttributionWindowEnforcement(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint48 customAttributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Campaign with zero attribution window (instant finalization)
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_zeroAttributionWindowInstantFinalization(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 feeBps
    ) public;

    /// @dev Attribution provider bypasses attribution deadline wait
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_attributionProviderBypassesDeadline(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    // ========================================
    // FEE COLLECTION INTEGRATION TESTS
    // ========================================

    /// @dev Complete fee collection workflow with varying fee rates
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_completeFeeCollectionWorkflow(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 feeBps
    ) public;

    /// @dev Zero fee campaign (no fee collection)
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    function test_integration_zeroFeeCampaign(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount
    ) public;

    /// @dev Maximum fee campaign (100% fee)
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    function test_integration_maximumFeeCampaign(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount
    ) public;

    // ========================================
    // MULTI-TOKEN INTEGRATION TESTS
    // ========================================

    /// @dev Campaign with multiple token types
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param token1 First token address
    /// @param token2 Second token address
    /// @param funding1 Funding amount for first token
    /// @param funding2 Funding amount for second token
    /// @param attribution1 Attribution amount for first token
    /// @param attribution2 Attribution amount for second token
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_multiTokenCampaign(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        address token1,
        address token2,
        uint256 funding1,
        uint256 funding2,
        uint256 attribution1,
        uint256 attribution2,
        uint16 feeBps
    ) public;

    // ========================================
    // BATCH ATTRIBUTION INTEGRATION TESTS
    // ========================================

    /// @dev Large batch attribution processing with consolidation
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publishers Array of publisher addresses
    /// @param publisherRefCodes Array of publisher reference codes
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmounts Array of attribution amounts
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_largeBatchAttributionProcessing(
        address advertiser,
        address attributionProvider,
        address[] memory publishers,
        string[] memory publisherRefCodes,
        uint256 campaignFunding,
        uint256[] memory attributionAmounts,
        uint16 feeBps
    ) public;

    /// @dev Batch processing with mixed conversion types and recipient consolidation
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmounts Array of attribution amounts to same recipient
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_batchProcessingWithRecipientConsolidation(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256[] memory attributionAmounts,
        uint16 feeBps
    ) public;

    // ========================================
    // OFAC FUNDS RE-ROUTING INTEGRATION TESTS
    // ========================================

    /// @dev OFAC sanctioned funds re-routing to burn address
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param sanctionedAddress OFAC sanctioned address
    /// @param burnAddress Address to burn sanctioned funds
    /// @param campaignFunding Initial campaign funding amount
    /// @param sanctionedAmount Amount of sanctioned funds
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_ofacFundsRerouting(
        address advertiser,
        address attributionProvider,
        address sanctionedAddress,
        address burnAddress,
        uint256 campaignFunding,
        uint256 sanctionedAmount,
        uint16 feeBps
    ) public;

    // ========================================
    // SECURITY INTEGRATION TESTS
    // ========================================

    /// @dev Comprehensive unauthorized access prevention across all operations
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param unauthorizedUser Unauthorized user address
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_comprehensiveUnauthorizedAccessPrevention(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        address unauthorizedUser,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 feeBps
    ) public;

    /// @dev Attribution window bypass vulnerability prevention
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param attributionWindow Attribution window in days
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_attributionWindowBypassPrevention(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint48 attributionWindow,
        uint16 feeBps
    ) public;

    /// @dev Malicious pause attack prevention
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param maliciousActor Malicious actor address
    /// @param campaignFunding Initial campaign funding amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_maliciousPauseAttackPrevention(
        address advertiser,
        address attributionProvider,
        address maliciousActor,
        uint256 campaignFunding,
        uint16 feeBps
    ) public;

    // ========================================
    // EDGE CASE INTEGRATION TESTS
    // ========================================

    /// @dev Campaign with zero-address recipient resolution
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_zeroAddressRecipientResolution(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 feeBps
    ) public;

    /// @dev Campaign with empty publisher ref codes (no publisher attributions)
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param recipientAddress Direct recipient address for empty ref code
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_emptyRefCodeAttributions(
        address advertiser,
        address attributionProvider,
        uint256 campaignFunding,
        uint256 attributionAmount,
        address recipientAddress,
        uint16 feeBps
    ) public;

    /// @dev Campaign with unregistered config ID (config ID 0)
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_unregisteredConfigIdAttributions(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 feeBps
    ) public;

    /// @dev Campaign with maximum attribution amounts and fee calculations
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Large campaign funding amount
    /// @param largeAttributionAmount Very large attribution amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_maximumAttributionAmounts(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 largeAttributionAmount,
        uint16 feeBps
    ) public;

    // ========================================
    // METADATA UPDATE INTEGRATION TESTS
    // ========================================

    /// @dev Campaign metadata updates during different lifecycle phases
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param newMetadata New metadata to set
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_metadataUpdatesAcrossLifecycle(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        string memory newMetadata,
        uint16 feeBps
    ) public;

    // ========================================
    // FUND WITHDRAWAL INTEGRATION TESTS
    // ========================================

    /// @dev Advertiser fund withdrawal to different address after finalization
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param beneficiary Beneficiary address for fund withdrawal
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_advertiserWithdrawToDifferentAddress(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        address beneficiary,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint16 feeBps
    ) public;

    /// @dev Partial fund withdrawal scenarios
    /// @param advertiser Advertiser address
    /// @param attributionProvider Attribution provider address
    /// @param publisher Publisher address
    /// @param publisherRefCode Publisher reference code
    /// @param campaignFunding Initial campaign funding amount
    /// @param attributionAmount Attribution payout amount
    /// @param partialWithdrawalAmount Partial withdrawal amount
    /// @param feeBps Attribution provider fee in basis points
    function test_integration_partialFundWithdrawal(
        address advertiser,
        address attributionProvider,
        address publisher,
        string memory publisherRefCode,
        uint256 campaignFunding,
        uint256 attributionAmount,
        uint256 partialWithdrawalAmount,
        uint16 feeBps
    ) public;
}
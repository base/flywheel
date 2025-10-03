// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AdConversionTestBase} from "../lib/AdConversionTestBase.sol";
import {Flywheel} from "../../src/Flywheel.sol";
import {AdConversion} from "../../src/hooks/AdConversion.sol";
import {LibString} from "solady/utils/LibString.sol";

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
        AdConversion.Attribution memory attribution =
            createOffchainAttribution(REF_CODE_1, publisherPayout1, attributionAmount);

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
        // Note: Only the payout amount is deducted from campaign, fees stay until distributed
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.ACTIVE);
        assertTokenBalance(address(tokenA), campaign, campaignFunding - expectedPayoutAmount);

        // Finalize campaign
        finalizeCampaign(campaign, attributionProvider1);
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.FINALIZED);

        // Distribute fees
        vm.prank(attributionProvider1);
        flywheel.distributeFees(campaign, address(tokenA), abi.encode(attributionProvider1));

        // Verify fee distribution
        assertAttributionProviderInvariants(
            campaign, address(tokenA), attributionProvider1, attributionProviderBalanceBefore, expectedFeeAmount
        );

        // Withdraw remaining funds
        uint256 remainingBalance = tokenA.balanceOf(campaign);
        vm.prank(advertiser1);
        flywheel.withdrawFunds(campaign, address(tokenA), abi.encode(advertiser1, remainingBalance));

        // Verify campaign completion - after fees are distributed, balance should be funding - attribution
        assertCampaignCompletedLifecycle(campaign, address(tokenA), attributionProvider1);

        // Final invariant check
        assertCampaignInvariants(campaign, address(tokenA));
    }

    /// @dev Campaign lifecycle with multiple publishers and attributions - using fixed values for stability
    function test_integration_multiPublisherCampaign() public {
        address advertiser = advertiser1;
        address attributionProvider = attributionProvider1;
        uint256 campaignFunding = 100 ether;
        uint16 feeBps = 500; // 5% fees

        // Use fixed publisher data for predictable results
        address[] memory publishers = new address[](2);
        publishers[0] = publisherPayout1;
        publishers[1] = publisherPayout2;

        uint256[] memory attributionAmounts = new uint256[](2);
        attributionAmounts[0] = 5 ether;
        attributionAmounts[1] = 3 ether;

        uint256 numPublishers = 2; // Fixed number

        // Register publishers and create allowlist
        string[] memory allowlist = new string[](numPublishers);
        allowlist[0] = REF_CODE_1; // "pub1"
        allowlist[1] = REF_CODE_2; // "pub2"

        // Create campaign with allowlist
        address campaign = createCampaign(
            advertiser,
            attributionProvider,
            allowlist,
            _createDefaultConfigs(),
            DEFAULT_ATTRIBUTION_WINDOW,
            feeBps
        );

        // Fund and activate campaign
        fundCampaign(campaign, address(tokenA), campaignFunding);
        activateCampaign(campaign, attributionProvider);

        // Process attributions for each publisher
        uint256 totalFeesGenerated = 0;
        uint256[] memory expectedPayouts = new uint256[](numPublishers);

        for (uint256 i = 0; i < numPublishers; i++) {
            // Create attribution
            AdConversion.Attribution memory attribution = createOffchainAttribution(
                allowlist[i],
                publishers[i],
                attributionAmounts[i]
            );

            // Calculate expected amounts
            uint256 feeAmount = (attributionAmounts[i] * feeBps) / adConversion.MAX_BPS();
            expectedPayouts[i] = attributionAmounts[i] - feeAmount;
            totalFeesGenerated += feeAmount;

            // Record initial balance
            uint256 publisherBalanceBefore = tokenA.balanceOf(publishers[i]);

            // Process attribution
            processAttribution(campaign, address(tokenA), attribution, attributionProvider);

            // Verify payout
            assertTokenBalance(address(tokenA), publishers[i], publisherBalanceBefore + expectedPayouts[i]);
        }

        // Verify total fee allocation
        assertAllocatedFee(campaign, address(tokenA), attributionProvider, totalFeesGenerated);

        // Verify campaign balance (only payouts are sent, fees stay in campaign)
        uint256 totalAttributionAmount = attributionAmounts[0] + attributionAmounts[1]; // 5 + 3 = 8 ether
        uint256 totalPayoutAmount = totalAttributionAmount - totalFeesGenerated;
        uint256 expectedCampaignBalance = campaignFunding - totalPayoutAmount;
        assertTokenBalance(address(tokenA), campaign, expectedCampaignBalance);

        // Finalize campaign and verify completion
        finalizeCampaign(campaign, attributionProvider);
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.FINALIZED);

        // Verify final invariants
        assertCampaignInvariants(campaign, address(tokenA));
    }

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
    ) public {
        // Constrain inputs
        vm.assume(advertiser != address(0) && attributionProvider != address(0) && publisher != address(0));
        vm.assume(advertiser != attributionProvider);
        campaignFunding = bound(campaignFunding, MIN_CAMPAIGN_FUNDING, 1000 ether); // Cap at reasonable amount
        offchainAmount = bound(offchainAmount, MIN_ATTRIBUTION_AMOUNT, campaignFunding / 10);
        onchainAmount = bound(onchainAmount, MIN_ATTRIBUTION_AMOUNT, campaignFunding / 10);
        feeBps = uint16(bound(feeBps, MIN_FEE_BPS, 1000)); // Cap fees at 10%

        // Ensure total doesn't exceed funding
        vm.assume(offchainAmount + onchainAmount <= campaignFunding / 2); // More conservative

        // Use REF_CODE_1 as registered publisher
        string memory refCode = REF_CODE_1;

        // Create campaign without allowlist (allows any publisher)
        address campaign = createCampaign(
            advertiser,
            attributionProvider,
            new string[](0), // No allowlist
            _createDefaultConfigs(),
            DEFAULT_ATTRIBUTION_WINDOW,
            feeBps
        );

        // Fund and activate campaign
        fundCampaign(campaign, address(tokenA), campaignFunding);
        activateCampaign(campaign, attributionProvider);

        // Record initial publisher balance
        uint256 publisherBalanceBefore = tokenA.balanceOf(publisherPayout1);

        // Process offchain attribution (uses config ID 1 - offchain)
        AdConversion.Attribution memory offchainAttribution = createOffchainAttribution(
            refCode,
            publisherPayout1,
            offchainAmount
        );

        processAttribution(campaign, address(tokenA), offchainAttribution, attributionProvider);

        // Process onchain attribution (uses config ID 2 - onchain)
        AdConversion.Attribution memory onchainAttribution = createOnchainAttribution(
            refCode,
            publisherPayout1,
            onchainAmount
        );

        processAttribution(campaign, address(tokenA), onchainAttribution, attributionProvider);

        // Calculate expected totals (per-attribution rounding like the contract)
        uint256 totalAttributionAmount = offchainAmount + onchainAmount;
        uint256 totalFeeAmount = ((offchainAmount * feeBps) / adConversion.MAX_BPS()) +
                                 ((onchainAmount * feeBps) / adConversion.MAX_BPS()); // Calculate per attribution
        uint256 totalPayoutAmount = totalAttributionAmount - totalFeeAmount;

        // Verify publisher received both payouts
        assertTokenBalance(address(tokenA), publisherPayout1, publisherBalanceBefore + totalPayoutAmount);

        // Verify total fee allocation
        assertAllocatedFee(campaign, address(tokenA), attributionProvider, totalFeeAmount);

        // Verify campaign balance reduction (only payouts are sent, fees stay in campaign)
        uint256 expectedCampaignBalance = campaignFunding - totalPayoutAmount;
        assertTokenBalance(address(tokenA), campaign, expectedCampaignBalance);

        // Verify both config types were used correctly
        assertConversionConfigCount(campaign, 2);

        // Finalize campaign
        finalizeCampaign(campaign, attributionProvider);
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.FINALIZED);

        // Final invariant check
        assertCampaignInvariants(campaign, address(tokenA));
    }

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
    ) public {
        // Constrain inputs
        vm.assume(advertiser != address(0) && attributionProvider != address(0));
        vm.assume(advertiser != attributionProvider);
        campaignFunding = bound(campaignFunding, MIN_CAMPAIGN_FUNDING, MAX_CAMPAIGN_FUNDING);
        feeBps = uint16(bound(feeBps, MIN_FEE_BPS, adConversion.MAX_BPS()));

        // Create campaign
        address campaign = createCampaign(
            advertiser,
            attributionProvider,
            new string[](0), // No allowlist
            _createDefaultConfigs(),
            DEFAULT_ATTRIBUTION_WINDOW,
            feeBps
        );

        assertCampaignStatus(campaign, Flywheel.CampaignStatus.INACTIVE);

        // Fund campaign but never activate it
        fundCampaign(campaign, address(tokenA), campaignFunding);
        assertTokenBalance(address(tokenA), campaign, campaignFunding);

        // Record advertiser's initial balance
        uint256 advertiserBalanceBefore = tokenA.balanceOf(advertiser);

        // Advertiser can directly finalize an inactive campaign (fund recovery)
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "Fund recovery");

        assertCampaignStatus(campaign, Flywheel.CampaignStatus.FINALIZED);

        // No fees should be allocated since no attributions were processed
        assertAllocatedFee(campaign, address(tokenA), attributionProvider, 0);

        // Withdraw all funds back to advertiser
        uint256 remainingBalance = tokenA.balanceOf(campaign);
        vm.prank(advertiser);
        flywheel.withdrawFunds(campaign, address(tokenA), abi.encode(advertiser, remainingBalance));

        // Verify advertiser recovered all funds
        assertTokenBalance(address(tokenA), advertiser, advertiserBalanceBefore + campaignFunding);

        // Campaign should be empty
        assertTokenBalance(address(tokenA), campaign, 0);

        // Verify campaign completed lifecycle correctly
        assertCampaignCompletedLifecycle(campaign, address(tokenA), attributionProvider);

        // Final invariant check
        assertCampaignInvariants(campaign, address(tokenA));
    }

    // ========================================
    // PUBLISHER ALLOWLIST INTEGRATION TESTS
    // ========================================

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
    ) public {
        // Constrain inputs
        vm.assume(advertiser != address(0) && attributionProvider != address(0));
        vm.assume(advertiser != attributionProvider);
        campaignFunding = bound(campaignFunding, MIN_CAMPAIGN_FUNDING, 1000 ether); // Cap at reasonable amount
        attributionAmount = bound(attributionAmount, MIN_ATTRIBUTION_AMOUNT, campaignFunding / 10); // Conservative for 2 attributions + fees
        feeBps = uint16(bound(feeBps, MIN_FEE_BPS, 1000)); // Cap fees at 10%

        // Create initial allowlist with REF_CODE_1 only
        string[] memory initialAllowlist = new string[](1);
        initialAllowlist[0] = REF_CODE_1;

        address campaign = createCampaign(
            advertiser,
            attributionProvider,
            initialAllowlist,
            _createDefaultConfigs(),
            DEFAULT_ATTRIBUTION_WINDOW,
            feeBps
        );

        // Verify initial allowlist state
        assertTrue(adConversion.hasPublisherAllowlist(campaign), "Campaign should have allowlist");
        assertTrue(adConversion.isPublisherRefCodeAllowed(campaign, REF_CODE_1), "REF_CODE_1 should be allowed");
        assertFalse(adConversion.isPublisherRefCodeAllowed(campaign, REF_CODE_2), "REF_CODE_2 should not be allowed initially");

        // Fund and activate campaign
        fundCampaign(campaign, address(tokenA), campaignFunding);
        activateCampaign(campaign, attributionProvider);

        // Process attribution with allowed ref code
        AdConversion.Attribution memory attribution1 = createOffchainAttribution(
            REF_CODE_1,
            publisherPayout1,
            attributionAmount
        );
        processAttribution(campaign, address(tokenA), attribution1, attributionProvider);

        // Add REF_CODE_2 to allowlist during active campaign
        vm.prank(advertiser);
        adConversion.addAllowedPublisherRefCode(campaign, REF_CODE_2);

        // Verify REF_CODE_2 is now allowed
        assertTrue(adConversion.isPublisherRefCodeAllowed(campaign, REF_CODE_2), "REF_CODE_2 should now be allowed");

        // Process attribution with newly allowed ref code
        AdConversion.Attribution memory attribution2 = createOffchainAttribution(
            REF_CODE_2,
            publisherPayout2,
            attributionAmount
        );
        processAttribution(campaign, address(tokenA), attribution2, attributionProvider);

        // Add REF_CODE_3 as well
        vm.prank(advertiser);
        adConversion.addAllowedPublisherRefCode(campaign, REF_CODE_3);

        // Verify REF_CODE_3 is now allowed
        assertTrue(adConversion.isPublisherRefCodeAllowed(campaign, REF_CODE_3), "REF_CODE_3 should now be allowed");

        // Calculate expected fee and remaining balance (per-attribution rounding like the contract)
        uint256 totalAttributionAmount = attributionAmount * 2;
        uint256 totalFeeAmount = ((attributionAmount * feeBps) / adConversion.MAX_BPS()) * 2; // Calculate per attribution
        uint256 totalPayoutAmount = totalAttributionAmount - totalFeeAmount;
        uint256 expectedCampaignBalance = campaignFunding - totalPayoutAmount;

        // Verify fee allocation and balance
        assertAllocatedFee(campaign, address(tokenA), attributionProvider, totalFeeAmount);
        assertTokenBalance(address(tokenA), campaign, expectedCampaignBalance);

        // Finalize campaign
        finalizeCampaign(campaign, attributionProvider);

        // Verify all ref codes remain in allowlist even after finalization
        assertTrue(adConversion.isPublisherRefCodeAllowed(campaign, REF_CODE_1), "REF_CODE_1 should still be allowed");
        assertTrue(adConversion.isPublisherRefCodeAllowed(campaign, REF_CODE_2), "REF_CODE_2 should still be allowed");
        assertTrue(adConversion.isPublisherRefCodeAllowed(campaign, REF_CODE_3), "REF_CODE_3 should still be allowed");

        // Final invariant check
        assertCampaignInvariants(campaign, address(tokenA));
    }

    // ========================================
    // CONVERSION CONFIG INTEGRATION TESTS
    // ========================================

    /// @dev Campaign with dynamic conversion config management - using fixed values for stability
    function test_integration_conversionConfigManagement() public {
        address advertiser = advertiser1;
        address attributionProvider = attributionProvider1;
        uint256 campaignFunding = 100 ether;
        uint256 attributionAmount = 1 ether; // Conservative amount for 3 attributions + fees
        uint16 feeBps = 500; // 5% fees

        // Create campaign with default configs (2 configs)
        address campaign = createCampaign(
            advertiser,
            attributionProvider,
            new string[](0), // No allowlist
            _createDefaultConfigs(),
            DEFAULT_ATTRIBUTION_WINDOW,
            feeBps
        );

        // Verify initial config count
        assertConversionConfigCount(campaign, 2);

        // Fund and activate campaign
        fundCampaign(campaign, address(tokenA), campaignFunding);
        activateCampaign(campaign, attributionProvider);

        // Process attribution with config 1 (offchain)
        AdConversion.Attribution memory attribution1 = createOffchainAttribution(
            REF_CODE_1,
            publisherPayout1,
            attributionAmount
        );
        processAttribution(campaign, address(tokenA), attribution1, attributionProvider);

        // Process attribution with config 2 (onchain)
        AdConversion.Attribution memory attribution2 = createOnchainAttribution(
            REF_CODE_2,
            publisherPayout2,
            attributionAmount
        );
        processAttribution(campaign, address(tokenA), attribution2, attributionProvider);

        // Add new conversion config during active campaign
        AdConversion.ConversionConfigInput memory newConfig = AdConversion.ConversionConfigInput({
            isEventOnchain: true,
            metadataURI: "https://new-config.example.com/metadata"
        });

        vm.prank(advertiser);
        adConversion.addConversionConfig(campaign, newConfig);

        // Verify config count increased
        assertConversionConfigCount(campaign, 3);

        // Verify new config properties
        assertConversionConfig(campaign, 3, true, true, "https://new-config.example.com/metadata");

        // Create attribution using new config ID 3 (onchain)
        AdConversion.Attribution memory attribution3 = createOnchainAttribution(
            REF_CODE_3,
            publisherPayout3,
            attributionAmount
        );
        attribution3.conversion.configId = 3; // Set to use new config
        processAttribution(campaign, address(tokenA), attribution3, attributionProvider);

        // Disable config 1 during active campaign
        vm.prank(advertiser);
        adConversion.disableConversionConfig(campaign, 1);

        // Verify config 1 is now disabled
        assertConversionConfig(campaign, 1, false, false, "https://campaign.example.com/offchain-config");

        // Config count should remain the same
        assertConversionConfigCount(campaign, 3);

        // Calculate expected totals
        uint256 totalAttributionAmount = attributionAmount * 3;
        uint256 totalFeeAmount = (totalAttributionAmount * feeBps) / adConversion.MAX_BPS();
        uint256 totalPayoutAmount = totalAttributionAmount - totalFeeAmount; // Only payouts are sent immediately
        uint256 expectedCampaignBalance = campaignFunding - totalPayoutAmount; // Fees stay in campaign until distributed

        // Verify fee allocation and balance
        assertAllocatedFee(campaign, address(tokenA), attributionProvider, totalFeeAmount);
        assertTokenBalance(address(tokenA), campaign, expectedCampaignBalance);

        // Finalize campaign
        finalizeCampaign(campaign, attributionProvider);

        // Verify config state persists after finalization
        assertConversionConfigCount(campaign, 3);
        assertConversionConfig(campaign, 1, false, false, "https://campaign.example.com/offchain-config"); // Still disabled
        assertConversionConfig(campaign, 2, true, true, "https://campaign.example.com/onchain-config"); // Still active
        assertConversionConfig(campaign, 3, true, true, "https://new-config.example.com/metadata"); // Still active

        // Final invariant check
        assertCampaignInvariants(campaign, address(tokenA));
    }

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
    ) public {
        // Constrain inputs
        vm.assume(advertiser != address(0) && attributionProvider != address(0));
        vm.assume(advertiser != attributionProvider);
        campaignFunding = bound(campaignFunding, MIN_CAMPAIGN_FUNDING, MAX_CAMPAIGN_FUNDING);
        attributionAmount = bound(attributionAmount, MIN_ATTRIBUTION_AMOUNT, campaignFunding / 3);
        feeBps = uint16(bound(feeBps, MIN_FEE_BPS, adConversion.MAX_BPS()));

        // Create campaign
        address campaign = createCampaign(
            advertiser,
            attributionProvider,
            new string[](0), // No allowlist
            _createDefaultConfigs(),
            DEFAULT_ATTRIBUTION_WINDOW,
            feeBps
        );

        // Fund and activate campaign
        fundCampaign(campaign, address(tokenA), campaignFunding);
        activateCampaign(campaign, attributionProvider);

        // Record initial attribution provider balance
        uint256 providerBalanceBefore = tokenA.balanceOf(attributionProvider);

        // Process multiple attributions to accumulate fees
        uint256 totalAttributionAmount = 0;
        uint256 totalFeeAmount = 0;

        for (uint256 i = 0; i < 3; i++) {
            AdConversion.Attribution memory attribution = createOffchainAttribution(
                REF_CODE_1,
                publisherPayout1,
                attributionAmount
            );
            attribution.conversion.eventId = bytes16(uint128(block.timestamp + i));

            processAttribution(campaign, address(tokenA), attribution, attributionProvider);

            uint256 feeAmount = (attributionAmount * feeBps) / adConversion.MAX_BPS();
            totalAttributionAmount += attributionAmount;
            totalFeeAmount += feeAmount;
        }

        // Verify fee accumulation
        assertAllocatedFee(campaign, address(tokenA), attributionProvider, totalFeeAmount);

        // Finalize campaign
        finalizeCampaign(campaign, attributionProvider);

        // Distribute fees
        vm.prank(attributionProvider);
        flywheel.distributeFees(campaign, address(tokenA), abi.encode(attributionProvider));

        // Verify fee distribution
        assertTokenBalance(address(tokenA), attributionProvider, providerBalanceBefore + totalFeeAmount);

        // No more fees should be allocated after distribution
        assertAllocatedFee(campaign, address(tokenA), attributionProvider, 0);

        // Verify remaining campaign balance
        uint256 expectedRemainingBalance = campaignFunding - totalAttributionAmount;
        assertTokenBalance(address(tokenA), campaign, expectedRemainingBalance);

        // Advertiser can withdraw remaining funds (if any)
        uint256 advertiserBalanceBefore = tokenA.balanceOf(advertiser);
        uint256 remainingBalance = tokenA.balanceOf(campaign);

        if (remainingBalance > 0) {
            vm.prank(advertiser);
            flywheel.withdrawFunds(campaign, address(tokenA), abi.encode(advertiser, remainingBalance));
        }

        // Verify fund withdrawal
        assertTokenBalance(address(tokenA), advertiser, advertiserBalanceBefore + expectedRemainingBalance);
        assertTokenBalance(address(tokenA), campaign, 0);

        // Verify campaign completed lifecycle
        assertCampaignCompletedLifecycle(campaign, address(tokenA), attributionProvider);

        // Final invariant check
        assertCampaignInvariants(campaign, address(tokenA));
    }

    // ========================================
    // MULTI-TOKEN INTEGRATION TESTS
    // ========================================

    /// @dev Campaign with multiple token types - using fixed values for stability
    function test_integration_multiTokenCampaign() public {
        address advertiser = advertiser1;
        address attributionProvider = attributionProvider1;
        address publisher = publisherPayout1;
        address token1 = address(tokenA);
        address token2 = address(tokenB);
        uint256 funding1 = 50 ether;
        uint256 funding2 = 30 ether;
        uint256 attribution1 = 5 ether;
        uint256 attribution2 = 3 ether;
        uint16 feeBps = 500; // 5% fees

        // Use our test tokens (tokenA and tokenB)
        address tokenAddr1 = address(tokenA);
        address tokenAddr2 = address(tokenB);

        // Create campaign
        address campaign = createCampaign(
            advertiser,
            attributionProvider,
            new string[](0), // No allowlist
            _createDefaultConfigs(),
            DEFAULT_ATTRIBUTION_WINDOW,
            feeBps
        );

        // Fund campaign with both tokens
        fundCampaign(campaign, tokenAddr1, funding1);
        fundCampaign(campaign, tokenAddr2, funding2);

        // Verify funding
        assertTokenBalance(tokenAddr1, campaign, funding1);
        assertTokenBalance(tokenAddr2, campaign, funding2);

        // Activate campaign
        activateCampaign(campaign, attributionProvider);

        // Record initial balances
        uint256 publisher1BalanceBefore = tokenA.balanceOf(publisherPayout1);
        uint256 publisher2BalanceBefore = tokenB.balanceOf(publisherPayout1);
        uint256 provider1BalanceBefore = tokenA.balanceOf(attributionProvider);
        uint256 provider2BalanceBefore = tokenB.balanceOf(attributionProvider);

        // Process attribution for token1
        AdConversion.Attribution memory attribution_token1 = createOffchainAttribution(
            REF_CODE_1,
            publisherPayout1,
            attribution1
        );
        processAttribution(campaign, tokenAddr1, attribution_token1, attributionProvider);

        // Process attribution for token2
        AdConversion.Attribution memory attribution_token2 = createOffchainAttribution(
            REF_CODE_1,
            publisherPayout1,
            attribution2
        );
        attribution_token2.conversion.eventId = bytes16(uint128(block.timestamp + 1)); // Different event ID
        processAttribution(campaign, tokenAddr2, attribution_token2, attributionProvider);

        // Calculate expected amounts for each token
        uint256 fee1 = (attribution1 * feeBps) / adConversion.MAX_BPS();
        uint256 payout1 = attribution1 - fee1;
        uint256 fee2 = (attribution2 * feeBps) / adConversion.MAX_BPS();
        uint256 payout2 = attribution2 - fee2;

        // Verify payouts
        assertTokenBalance(tokenAddr1, publisherPayout1, publisher1BalanceBefore + payout1);
        assertTokenBalance(tokenAddr2, publisherPayout1, publisher2BalanceBefore + payout2);

        // Verify fee allocations
        assertAllocatedFee(campaign, tokenAddr1, attributionProvider, fee1);
        assertAllocatedFee(campaign, tokenAddr2, attributionProvider, fee2);

        // Verify campaign balances (only payouts are sent, fees stay in campaign)
        assertTokenBalance(tokenAddr1, campaign, funding1 - payout1);
        assertTokenBalance(tokenAddr2, campaign, funding2 - payout2);

        // Finalize campaign
        finalizeCampaign(campaign, attributionProvider);

        // Distribute fees for both tokens
        vm.startPrank(attributionProvider);
        flywheel.distributeFees(campaign, tokenAddr1, abi.encode(attributionProvider));
        flywheel.distributeFees(campaign, tokenAddr2, abi.encode(attributionProvider));
        vm.stopPrank();

        // Verify fee distributions
        assertTokenBalance(tokenAddr1, attributionProvider, provider1BalanceBefore + fee1);
        assertTokenBalance(tokenAddr2, attributionProvider, provider2BalanceBefore + fee2);

        // Withdraw remaining funds for both tokens
        uint256 advertiser1BalanceBefore = tokenA.balanceOf(advertiser);
        uint256 advertiser2BalanceBefore = tokenB.balanceOf(advertiser);

        uint256 remaining1 = tokenA.balanceOf(campaign);
        uint256 remaining2 = tokenB.balanceOf(campaign);
        vm.startPrank(advertiser);
        if (remaining1 > 0) {
            flywheel.withdrawFunds(campaign, tokenAddr1, abi.encode(advertiser, remaining1));
        }
        if (remaining2 > 0) {
            flywheel.withdrawFunds(campaign, tokenAddr2, abi.encode(advertiser, remaining2));
        }
        vm.stopPrank();

        // Verify final fund withdrawals
        assertTokenBalance(tokenAddr1, advertiser, advertiser1BalanceBefore + (funding1 - attribution1));
        assertTokenBalance(tokenAddr2, advertiser, advertiser2BalanceBefore + (funding2 - attribution2));

        // Campaigns should be empty
        assertTokenBalance(tokenAddr1, campaign, 0);
        assertTokenBalance(tokenAddr2, campaign, 0);

        // Final invariant checks for both tokens
        assertCampaignInvariants(campaign, tokenAddr1);
        assertCampaignInvariants(campaign, tokenAddr2);
    }

    // ========================================
    // SECURITY INTEGRATION TESTS
    // ========================================

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
    ) public {
        // Constrain inputs
        vm.assume(advertiser != address(0) && attributionProvider != address(0));
        vm.assume(advertiser != attributionProvider);
        campaignFunding = bound(campaignFunding, MIN_CAMPAIGN_FUNDING, MAX_CAMPAIGN_FUNDING);
        attributionAmount = bound(attributionAmount, MIN_ATTRIBUTION_AMOUNT, campaignFunding / 2);
        feeBps = uint16(bound(feeBps, MIN_FEE_BPS, adConversion.MAX_BPS()));

        // Constrain attribution window to valid range (1-180 days)
        uint48 maxDays = MAX_ATTRIBUTION_WINDOW / 86400; // 180 days
        uint48 numDays = uint48(bound(attributionWindow, 1, maxDays));
        attributionWindow = numDays * 86400; // Convert to seconds

        // Create campaign with specific attribution window
        address campaign = createCampaign(
            advertiser,
            attributionProvider,
            new string[](0), // No allowlist
            _createDefaultConfigs(),
            attributionWindow,
            feeBps
        );

        // Fund and activate campaign
        fundCampaign(campaign, address(tokenA), campaignFunding);
        activateCampaign(campaign, attributionProvider);

        // Process attribution
        AdConversion.Attribution memory attribution = createOffchainAttribution(
            REF_CODE_1,
            publisherPayout1,
            attributionAmount
        );
        processAttribution(campaign, address(tokenA), attribution, attributionProvider);

        // Advertiser moves campaign to FINALIZING
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.FINALIZING);

        // Time passes but not enough for attribution window to expire
        uint256 partialTime = attributionWindow / 2;
        vm.warp(block.timestamp + partialTime);

        // Advertiser should NOT be able to finalize before attribution window expires
        vm.expectRevert(AdConversion.Unauthorized.selector);
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");

        // Attribution provider should still be able to finalize (bypass allowed)
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.FINALIZED);

        // Verify campaign completed correctly despite bypass
        assertCampaignInvariants(campaign, address(tokenA));
    }

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
    ) public {
        // Constrain inputs
        vm.assume(advertiser != address(0) && attributionProvider != address(0) && maliciousActor != address(0));
        vm.assume(advertiser != attributionProvider);
        vm.assume(maliciousActor != advertiser && maliciousActor != attributionProvider);
        campaignFunding = bound(campaignFunding, MIN_CAMPAIGN_FUNDING, MAX_CAMPAIGN_FUNDING);
        feeBps = uint16(bound(feeBps, MIN_FEE_BPS, adConversion.MAX_BPS()));

        // Create campaign
        address campaign = createCampaign(
            advertiser,
            attributionProvider,
            new string[](0), // No allowlist
            _createDefaultConfigs(),
            DEFAULT_ATTRIBUTION_WINDOW,
            feeBps
        );

        // Fund and activate campaign
        fundCampaign(campaign, address(tokenA), campaignFunding);
        activateCampaign(campaign, attributionProvider);

        // Malicious actor should NOT be able to pause the campaign
        // AdConversion hook doesn't support pause functionality, so this should revert
        vm.expectRevert();
        vm.prank(maliciousActor);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.INACTIVE, "malicious pause");

        // Campaign should still be active
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.ACTIVE);

        // Process normal attribution to show campaign still works (use small amount to avoid solvency issues)
        uint256 attributionAmount = campaignFunding / 10; // Use smaller amount to ensure solvency
        AdConversion.Attribution memory attribution = createOffchainAttribution(
            REF_CODE_1,
            publisherPayout1,
            attributionAmount
        );
        processAttribution(campaign, address(tokenA), attribution, attributionProvider);

        // Verify attribution was processed successfully
        uint256 expectedFee = (attributionAmount * feeBps) / adConversion.MAX_BPS();
        assertAllocatedFee(campaign, address(tokenA), attributionProvider, expectedFee);

        // Malicious actor should NOT be able to finalize campaign
        vm.expectRevert();
        vm.prank(maliciousActor);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "malicious finalize");

        // Campaign should still be active
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.ACTIVE);

        // Legitimate finalization should still work
        finalizeCampaign(campaign, attributionProvider);
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.FINALIZED);

        // Distribute fees first to avoid solvency issues
        vm.prank(attributionProvider);
        flywheel.distributeFees(campaign, address(tokenA), abi.encode(attributionProvider));

        // Malicious actor should NOT be able to withdraw funds
        vm.expectRevert();
        vm.prank(maliciousActor);
        flywheel.withdrawFunds(campaign, address(tokenA), "");

        // Only advertiser should be able to withdraw remaining funds (if any)
        uint256 advertiserBalanceBefore = tokenA.balanceOf(advertiser);
        uint256 remainingBalance = tokenA.balanceOf(campaign);

        if (remainingBalance > 0) {
            vm.prank(advertiser);
            flywheel.withdrawFunds(campaign, address(tokenA), abi.encode(advertiser, remainingBalance));
        }

        // Verify funds went to correct recipient
        uint256 expectedWithdrawal = campaignFunding - attributionAmount;
        assertTokenBalance(address(tokenA), advertiser, advertiserBalanceBefore + expectedWithdrawal);

        // Final invariant check
        assertCampaignInvariants(campaign, address(tokenA));
    }

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
    ) public {
        // Constrain inputs
        vm.assume(advertiser != address(0) && attributionProvider != address(0));
        vm.assume(advertiser != attributionProvider);
        campaignFunding = bound(campaignFunding, MIN_CAMPAIGN_FUNDING, MAX_CAMPAIGN_FUNDING);
        attributionAmount = bound(attributionAmount, MIN_ATTRIBUTION_AMOUNT, campaignFunding / 2);
        feeBps = uint16(bound(feeBps, MIN_FEE_BPS, adConversion.MAX_BPS()));

        // Create campaign with initial metadata
        address campaign = createCampaignWithURI(
            advertiser,
            attributionProvider,
            new string[](0), // No allowlist
            _createDefaultConfigs(),
            DEFAULT_ATTRIBUTION_WINDOW,
            feeBps,
            "https://initial.example.com/metadata"
        );

        // Verify initial metadata (URI = prefix + campaign address)
        string memory initialExpectedURI = string.concat("https://initial.example.com/metadata", LibString.toHexStringChecksummed(campaign));
        assertCampaignURI(campaign, initialExpectedURI);

        // Test metadata update during INACTIVE phase
        vm.prank(advertiser);
        flywheel.updateMetadata(campaign, bytes(newMetadata));

        // Note: AdConversion hook only provides authorization for metadata updates
        // The actual metadata update logic is handled by Flywheel, not the hook
        // So the hook just validates the caller is authorized

        // Fund campaign
        fundCampaign(campaign, address(tokenA), campaignFunding);

        // Test metadata update during INACTIVE phase (still before activation)
        vm.prank(attributionProvider);
        flywheel.updateMetadata(campaign, "attribution provider metadata");

        // Activate campaign
        activateCampaign(campaign, attributionProvider);

        // Test metadata update during ACTIVE phase
        vm.prank(advertiser);
        flywheel.updateMetadata(campaign, "active phase metadata");

        // Process attribution
        AdConversion.Attribution memory attribution = createOffchainAttribution(
            REF_CODE_1,
            publisherPayout1,
            attributionAmount
        );
        processAttribution(campaign, address(tokenA), attribution, attributionProvider);

        // Test metadata update during ACTIVE phase with ongoing attributions
        vm.prank(attributionProvider);
        flywheel.updateMetadata(campaign, "mid-campaign update");

        // Move to FINALIZING
        vm.prank(advertiser);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZING, "");

        // Test metadata update during FINALIZING phase
        vm.prank(advertiser);
        flywheel.updateMetadata(campaign, "finalizing phase metadata");

        // Finalize campaign
        vm.prank(attributionProvider);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");

        // Test that metadata updates are blocked in FINALIZED phase
        vm.expectRevert();
        vm.prank(advertiser);
        flywheel.updateMetadata(campaign, "should fail in finalized");

        // Test unauthorized metadata updates are blocked
        vm.expectRevert();
        vm.prank(publisher);
        flywheel.updateMetadata(campaign, "unauthorized update");

        // Verify campaign state is still consistent
        assertCampaignStatus(campaign, Flywheel.CampaignStatus.FINALIZED);

        // Calculate expected fee
        uint256 expectedFee = (attributionAmount * feeBps) / adConversion.MAX_BPS();
        assertAllocatedFee(campaign, address(tokenA), attributionProvider, expectedFee);

        // Final invariant check
        assertCampaignInvariants(campaign, address(tokenA));
    }
}

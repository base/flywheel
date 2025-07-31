// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {AdvertisementConversion} from "../../src/hooks/AdvertisementConversion.sol";
import {Flywheel} from "../../src/Flywheel.sol";
import {FlywheelTestHelpers} from "./FlywheelTestHelpers.sol";

/// @notice Common test helpers for AdvertisementConversion hook testing
abstract contract AdvertisementConversionTestHelpers is FlywheelTestHelpers {
    AdvertisementConversion public hook;

    // Common event IDs for testing
    bytes16 public constant TEST_EVENT_ID_1 = bytes16(0x1234567890abcdef1234567890abcdef);
    bytes16 public constant TEST_EVENT_ID_2 = bytes16(0xabcdef1234567890abcdef1234567890);
    bytes16 public constant OFAC_EVENT_ID = bytes16(uint128(999));

    // Common test values
    string public constant TEST_CLICK_ID_1 = "click_123";
    string public constant TEST_CLICK_ID_2 = "click_456";
    string public constant OFAC_CLICK_ID = "ofac_sanctioned_funds";
    address public constant BURN_ADDRESS = address(0xdead);

    /// @notice Sets up complete AdvertisementConversion test environment with default registry
    function _setupAdvertisementConversionTest() internal {
        _setupFlywheelInfrastructure();
        _registerDefaultPublishers();

        // Deploy AdvertisementConversion hook
        hook = new AdvertisementConversion(address(flywheel), OWNER, address(referralCodeRegistry));
    }

    /// @notice Sets up complete AdvertisementConversion test environment with custom registry
    function _setupAdvertisementConversionTest(address publisherRegistryAddress) internal {
        _setupFlywheelInfrastructure();
        _registerDefaultPublishers();

        // Deploy AdvertisementConversion hook
        hook = new AdvertisementConversion(address(flywheel), OWNER, publisherRegistryAddress);
    }

    /// @notice Creates basic conversion configs for testing
    function _createBasicConversionConfigs()
        internal
        pure
        returns (AdvertisementConversion.ConversionConfigInput[] memory)
    {
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](2);

        configs[0] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: false,
            conversionMetadataUrl: "https://example.com/offchain"
        });

        configs[1] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: true,
            conversionMetadataUrl: "https://example.com/onchain"
        });

        return configs;
    }

    /// @notice Creates a campaign with basic conversion configs
    function _createBasicCampaign(uint256 nonce) internal returns (address) {
        AdvertisementConversion.ConversionConfigInput[] memory configs = _createBasicConversionConfigs();
        string[] memory allowedRefCodes = new string[](0);

        bytes memory hookData =
            abi.encode(ATTRIBUTION_PROVIDER, ADVERTISER, "https://example.com/campaign", allowedRefCodes, configs);

        return flywheel.createCampaign(address(hook), nonce, hookData);
    }

    /// @notice Creates a campaign with allowlist enabled
    function _createCampaignWithAllowlist(uint256 nonce, string[] memory allowedRefCodes) internal returns (address) {
        AdvertisementConversion.ConversionConfigInput[] memory configs = _createBasicConversionConfigs();

        bytes memory hookData =
            abi.encode(ATTRIBUTION_PROVIDER, ADVERTISER, "https://example.com/campaign", allowedRefCodes, configs);

        return flywheel.createCampaign(address(hook), nonce, hookData);
    }

    /// @notice Sets attribution provider fee for the hook
    function _setAttributionProviderFee(uint16 feeBps) internal {
        vm.prank(ATTRIBUTION_PROVIDER);
        hook.setAttributionProviderFee(feeBps);
    }

    /// @notice Creates an offchain attribution with default values
    function _createOffchainAttribution(string memory publisherRefCode, uint256 payoutAmount, address payoutRecipient)
        internal
        view
        returns (AdvertisementConversion.Attribution[] memory)
    {
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: TEST_EVENT_ID_1,
                clickId: TEST_CLICK_ID_1,
                conversionConfigId: 1, // Offchain config
                publisherRefCode: publisherRefCode,
                timestamp: uint32(block.timestamp),
                payoutRecipient: payoutRecipient,
                payoutAmount: payoutAmount
            }),
            logBytes: "" // Empty for offchain
        });

        return attributions;
    }

    /// @notice Creates an onchain attribution with default values
    function _createOnchainAttribution(string memory publisherRefCode, uint256 payoutAmount, address payoutRecipient)
        internal
        view
        returns (AdvertisementConversion.Attribution[] memory)
    {
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

        AdvertisementConversion.Log memory log = AdvertisementConversion.Log({
            chainId: block.chainid,
            transactionHash: keccak256("test_transaction"),
            index: 0
        });

        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: TEST_EVENT_ID_2,
                clickId: TEST_CLICK_ID_2,
                conversionConfigId: 2, // Onchain config
                publisherRefCode: publisherRefCode,
                timestamp: uint32(block.timestamp),
                payoutRecipient: payoutRecipient,
                payoutAmount: payoutAmount
            }),
            logBytes: abi.encode(log)
        });

        return attributions;
    }

    /// @notice Creates OFAC funds re-routing attribution
    function _createOfacReroutingAttribution(uint256 amount)
        internal
        view
        returns (AdvertisementConversion.Attribution[] memory)
    {
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);

        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: OFAC_EVENT_ID,
                clickId: OFAC_CLICK_ID,
                conversionConfigId: 0, // No config - unregistered conversion
                publisherRefCode: "", // No publisher
                timestamp: uint32(block.timestamp),
                payoutRecipient: BURN_ADDRESS,
                payoutAmount: amount
            }),
            logBytes: "" // Offchain event
        });

        return attributions;
    }

    /// @notice Processes attribution and returns payouts/fees
    function _processAttribution(address campaign, AdvertisementConversion.Attribution[] memory attributions)
        internal
        returns (Flywheel.Payout[] memory payouts, uint256 fee)
    {
        bytes memory attributionData = abi.encode(attributions);

        vm.prank(ATTRIBUTION_PROVIDER);
        (payouts, fee) = hook.onReward(ATTRIBUTION_PROVIDER, campaign, address(token), attributionData);

        return (payouts, fee);
    }

    /// @notice Processes attribution through Flywheel reward function
    function _processAttributionThroughFlywheel(
        address campaign,
        AdvertisementConversion.Attribution[] memory attributions
    ) internal {
        bytes memory attributionData = abi.encode(attributions);

        vm.prank(ATTRIBUTION_PROVIDER);
        flywheel.reward(campaign, address(token), attributionData);
    }

    /// @notice Updates conversion config metadata
    function _updateConversionConfigMetadata(address campaign, uint256 configId, address caller) internal {
        vm.prank(caller);
        hook.updateConversionConfigMetadata(campaign, uint8(configId));
    }

    /// @notice Adds publisher to campaign allowlist
    function _addPublisherToAllowlist(address campaign, string memory refCode, address caller) internal {
        vm.prank(caller);
        hook.addAllowedPublisherRefCode(campaign, refCode);
    }

    /// @notice Asserts conversion config properties
    function _assertConversionConfig(
        address campaign,
        uint256 configId,
        bool expectedIsActive,
        bool expectedIsEventOnchain,
        string memory expectedMetadataUrl
    ) internal view {
        AdvertisementConversion.ConversionConfig memory config = hook.getConversionConfig(campaign, uint8(configId));

        assertEq(config.isActive, expectedIsActive);
        assertEq(config.isEventOnchain, expectedIsEventOnchain);
        assertEq(config.conversionMetadataUrl, expectedMetadataUrl);
    }

    /// @notice Asserts publisher is allowed in campaign
    function _assertPublisherAllowed(address campaign, string memory refCode, bool expected) internal view {
        assertEq(hook.isPublisherAllowed(campaign, refCode), expected);
    }

    /// @notice Runs complete offchain attribution test
    function _runOffchainAttributionTest(
        address campaign,
        string memory publisherRefCode,
        uint256 payoutAmount,
        uint16 feeBps
    ) internal {
        // Setup
        _setAttributionProviderFee(feeBps);
        _fundCampaign(campaign, INITIAL_TOKEN_BALANCE);
        _activateCampaign(campaign);

        // Create and process attribution
        AdvertisementConversion.Attribution[] memory attributions =
            _createOffchainAttribution(publisherRefCode, payoutAmount, address(0));

        _processAttributionThroughFlywheel(campaign, attributions);

        // Calculate expected values
        uint256 expectedFee = _calculateFee(payoutAmount, feeBps);
        uint256 expectedPayout = payoutAmount - expectedFee;

        // Get payout recipient (publisher payout address or payoutRecipient)
        address expectedRecipient;
        if (bytes(publisherRefCode).length > 0) {
            if (keccak256(bytes(publisherRefCode)) == keccak256(bytes(DEFAULT_REF_CODE_1))) {
                expectedRecipient = PUBLISHER_1_PAYOUT;
            } else if (keccak256(bytes(publisherRefCode)) == keccak256(bytes(DEFAULT_REF_CODE_2))) {
                expectedRecipient = PUBLISHER_2_PAYOUT;
            }
        }

        // Verify results
        if (expectedRecipient != address(0)) {
            _assertTokenBalance(expectedRecipient, expectedPayout);
        }
        _assertFeeAllocation(campaign, ATTRIBUTION_PROVIDER, expectedFee);
    }

    /// @notice Runs complete onchain attribution test
    function _runOnchainAttributionTest(
        address campaign,
        string memory publisherRefCode,
        uint256 payoutAmount,
        uint16 feeBps
    ) internal {
        // Setup
        _setAttributionProviderFee(feeBps);
        _fundCampaign(campaign, INITIAL_TOKEN_BALANCE);
        _activateCampaign(campaign);

        // Create and process attribution
        AdvertisementConversion.Attribution[] memory attributions =
            _createOnchainAttribution(publisherRefCode, payoutAmount, address(0));

        _processAttributionThroughFlywheel(campaign, attributions);

        // Calculate expected values
        uint256 expectedFee = _calculateFee(payoutAmount, feeBps);
        uint256 expectedPayout = payoutAmount - expectedFee;

        // Get payout recipient
        address expectedRecipient;
        if (bytes(publisherRefCode).length > 0) {
            if (keccak256(bytes(publisherRefCode)) == keccak256(bytes(DEFAULT_REF_CODE_1))) {
                expectedRecipient = PUBLISHER_1_PAYOUT;
            } else if (keccak256(bytes(publisherRefCode)) == keccak256(bytes(DEFAULT_REF_CODE_2))) {
                expectedRecipient = PUBLISHER_2_PAYOUT;
            }
        }

        // Verify results
        if (expectedRecipient != address(0)) {
            _assertTokenBalance(expectedRecipient, expectedPayout);
        }
        _assertFeeAllocation(campaign, ATTRIBUTION_PROVIDER, expectedFee);
    }

    /// @notice Runs OFAC re-routing test scenario
    function _runOfacReroutingTest(address campaign, uint256 amount) internal {
        // Setup - no fee for burn transaction
        _setAttributionProviderFee(0);
        _fundCampaign(campaign, amount);
        _activateCampaign(campaign);

        // Create and process OFAC rerouting attribution
        AdvertisementConversion.Attribution[] memory attributions = _createOfacReroutingAttribution(amount);

        // Expect event emission
        vm.expectEmit(true, false, false, true);
        emit AdvertisementConversion.OffchainConversionProcessed(campaign, attributions[0].conversion);

        _processAttributionThroughFlywheel(campaign, attributions);

        // Verify funds were sent to burn address
        _assertTokenBalance(BURN_ADDRESS, amount);
        _assertFeeAllocation(campaign, ATTRIBUTION_PROVIDER, 0);
    }
}

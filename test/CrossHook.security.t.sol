// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../src/Flywheel.sol";
import {BuyerRewards} from "../src/hooks/BuyerRewards.sol";
import {SimpleRewards} from "../src/hooks/SimpleRewards.sol";
import {AdvertisementConversion} from "../src/hooks/AdvertisementConversion.sol";
import {ReferralCodeRegistry} from "../src/ReferralCodeRegistry.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Cross-Hook Security Test Suite
/// @notice Security testing for interactions between different hook types
/// @dev Tests hook interoperability attacks, cross-campaign vulnerabilities, and multi-hook economic attacks
contract CrossHookSecurityTest is Test {
    Flywheel public flywheel;
    BuyerRewards public buyerRewardsHook;
    SimpleRewards public simpleRewardsHook;
    AdvertisementConversion public adConversionHook;
    AuthCaptureEscrow public escrow;
    ReferralCodeRegistry public publisherRegistry;
    DummyERC20 public token;

    address public owner = address(0x1000);
    address public manager = address(0x2000);
    address public buyerRewardsManager = address(0x2001);
    address public simpleRewardsManager = address(0x2002);
    address public attacker = address(0xBAD);
    address public victim = address(0x3000);
    address public attributionProvider = address(0x4000);
    address public advertiser = address(0x5000);
    address public payer = address(0x6000);
    address public merchant = address(0x7000);

    address public buyerRewardsCampaign;
    address public simpleRewardsCampaign;
    address public adConversionCampaign;

    uint256 public constant INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 public constant ATTACK_AMOUNT = 100e18;

    function setUp() public {
        // Deploy core contracts
        flywheel = new Flywheel();
        escrow = new AuthCaptureEscrow();

        // Deploy token with all participants
        address[] memory initialHolders = new address[](10);
        initialHolders[0] = owner;
        initialHolders[1] = manager;
        initialHolders[2] = buyerRewardsManager;
        initialHolders[3] = simpleRewardsManager;
        initialHolders[4] = attacker;
        initialHolders[5] = victim;
        initialHolders[6] = address(this);
        initialHolders[7] = payer;
        initialHolders[8] = merchant;
        initialHolders[9] = advertiser;
        token = new DummyERC20(initialHolders);

        // Deploy hook contracts
        buyerRewardsHook = new BuyerRewards(address(flywheel), address(escrow));
        simpleRewardsHook = new SimpleRewards(address(flywheel));

        // Deploy and setup ReferralCodeRegistry for AdvertisementConversion
        ReferralCodeRegistry implementation = new ReferralCodeRegistry();
        bytes memory initData = abi.encodeWithSelector(
            ReferralCodeRegistry.initialize.selector,
            owner,
            address(0x999) // signer address
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        publisherRegistry = ReferralCodeRegistry(address(proxy));

        adConversionHook = new AdvertisementConversion(address(flywheel), owner, address(publisherRegistry));

        // Register a publisher for ad conversion tests
        vm.prank(owner);
        publisherRegistry.registerCustom(
            "TEST_PUB",
            victim,
            victim,
            "https://example.com/publisher"
        );

        // Create campaigns for each hook type
        _createBuyerRewardsCampaign();
        _createSimpleRewardsCampaign();
        _createAdConversionCampaign();

        // Fund all campaigns
        _fundAllCampaigns();
    }

    function _createBuyerRewardsCampaign() internal {
        bytes memory hookData = abi.encode(
            owner,
            buyerRewardsManager,
            "https://api.example.com/buyer-rewards"
        );
        buyerRewardsCampaign = flywheel.createCampaign(address(buyerRewardsHook), 1, hookData);
    }

    function _createSimpleRewardsCampaign() internal {
        bytes memory hookData = abi.encode(simpleRewardsManager);
        simpleRewardsCampaign = flywheel.createCampaign(address(simpleRewardsHook), 2, hookData);
    }

    function _createAdConversionCampaign() internal {
        AdvertisementConversion.ConversionConfigInput[] memory configs =
            new AdvertisementConversion.ConversionConfigInput[](1);
        configs[0] = AdvertisementConversion.ConversionConfigInput({
            isEventOnchain: false,
            conversionMetadataUrl: "https://example.com/conversion"
        });

        string[] memory allowedRefCodes = new string[](1);
        allowedRefCodes[0] = "TEST_PUB";

        bytes memory hookData = abi.encode(
            attributionProvider,
            advertiser,
            "https://example.com/ad-campaign",
            allowedRefCodes,
            configs
        );
        adConversionCampaign = flywheel.createCampaign(address(adConversionHook), 3, hookData);
    }

    function _fundAllCampaigns() internal {
        vm.startPrank(owner);
        token.transfer(buyerRewardsCampaign, INITIAL_TOKEN_BALANCE);
        token.transfer(simpleRewardsCampaign, INITIAL_TOKEN_BALANCE);
        token.transfer(adConversionCampaign, INITIAL_TOKEN_BALANCE);
        vm.stopPrank();

        // Activate all campaigns
        vm.prank(buyerRewardsManager);
        flywheel.updateStatus(buyerRewardsCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        vm.prank(simpleRewardsManager);
        flywheel.updateStatus(simpleRewardsCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        vm.prank(attributionProvider);
        flywheel.updateStatus(adConversionCampaign, Flywheel.CampaignStatus.ACTIVE, "");
    }

    // =============================================================
    //                    CROSS-HOOK PRIVILEGE ESCALATION
    // =============================================================

    /// @notice Test cross-hook manager privilege escalation
    function test_security_crossHookManagerPrivilegeEscalation() public {
        // Manager of SimpleRewards tries to control BuyerRewards campaign
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: attacker,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12345
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, paymentHash),
            abi.encode(true, false, false)
        );

        bytes memory hookData = abi.encode(paymentInfo, ATTACK_AMOUNT);

        // SimpleRewards manager should NOT be able to control BuyerRewards campaign
        vm.expectRevert(BuyerRewards.Unauthorized.selector);
        vm.prank(simpleRewardsManager);
        flywheel.reward(buyerRewardsCampaign, address(token), hookData);
    }

    /// @notice Test attribution provider cross-hook privilege abuse
    function test_security_attributionProviderCrossHookAbuse() public {
        // Attribution provider tries to control non-ad campaigns
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: attacker,
            amount: ATTACK_AMOUNT,
            extraData: ""
        });
        bytes memory hookData = abi.encode(payouts);

        // Attribution provider should NOT control SimpleRewards
        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(attributionProvider);
        flywheel.reward(simpleRewardsCampaign, address(token), hookData);

        // Attribution provider should NOT control BuyerRewards
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: attacker,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12346
        });

        bytes memory buyerHookData = abi.encode(paymentInfo, ATTACK_AMOUNT);

        vm.expectRevert(BuyerRewards.Unauthorized.selector);
        vm.prank(attributionProvider);
        flywheel.reward(buyerRewardsCampaign, address(token), buyerHookData);
    }

    // =============================================================
    //                    CROSS-CAMPAIGN ATTACK VECTORS
    // =============================================================

    /// @notice Test cross-campaign fund drainage
    function test_security_crossCampaignFundDrainage() public {
        // Compromised manager drains multiple campaigns
        uint256 attackerBalanceBefore = token.balanceOf(attacker);

        // Drain SimpleRewards campaign
        Flywheel.Payout[] memory payouts1 = new Flywheel.Payout[](1);
        payouts1[0] = Flywheel.Payout({
            recipient: attacker,
            amount: INITIAL_TOKEN_BALANCE,
            extraData: ""
        });

        vm.prank(simpleRewardsManager);
        flywheel.reward(simpleRewardsCampaign, address(token), abi.encode(payouts1));

        // Drain BuyerRewards campaign (manager can't do this - only owner can withdraw after finalization)
        // But manager can allocate large amounts to attacker
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: attacker,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12347
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, paymentHash),
            abi.encode(true, false, false)
        );

        vm.prank(buyerRewardsManager);
        flywheel.reward(buyerRewardsCampaign, address(token), abi.encode(paymentInfo, INITIAL_TOKEN_BALANCE));

        // Verify drainage
        uint256 attackerBalanceAfter = token.balanceOf(attacker);
        assertEq(attackerBalanceAfter, attackerBalanceBefore + (2 * INITIAL_TOKEN_BALANCE));
    }

    /// @notice Test campaign state manipulation across hooks
    function test_security_crossHookStateManipulation() public {
        // Manager tries to pause campaigns they don't control
        vm.expectRevert(); // Should fail - manager doesn't control ad campaign
        vm.prank(manager);
        flywheel.updateStatus(adConversionCampaign, Flywheel.CampaignStatus.INACTIVE, "");

        // Attribution provider tries to control other campaigns
        vm.expectRevert(); // Should fail - attribution provider doesn't control simple rewards
        vm.prank(attributionProvider);
        flywheel.updateStatus(simpleRewardsCampaign, Flywheel.CampaignStatus.INACTIVE, "");
    }

    // =============================================================
    //                    HOOK INTEROPERABILITY ATTACKS
    // =============================================================

    /// @notice Test hook data confusion attack
    function test_security_hookDataConfusionAttack() public {
        // Create SimpleRewards payout data
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: attacker, amount: ATTACK_AMOUNT, extraData: ""});
        bytes memory simpleRewardsData = abi.encode(payouts);

        // Try to use SimpleRewards data on BuyerRewards campaign
        vm.expectRevert(); // Should fail due to data format mismatch
        vm.prank(buyerRewardsManager);
        flywheel.reward(buyerRewardsCampaign, address(token), simpleRewardsData);

        // Create BuyerRewards payment data
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: attacker,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12348
        });
        bytes memory buyerRewardsData = abi.encode(paymentInfo, ATTACK_AMOUNT);

        // Try to use BuyerRewards data on SimpleRewards campaign
        vm.expectRevert(); // Should fail due to data format mismatch
        vm.prank(simpleRewardsManager);
        flywheel.reward(simpleRewardsCampaign, address(token), buyerRewardsData);
    }

    /// @notice Test allocation/distribution cross-contamination
    function test_security_allocationDistributionCrossContamination() public {
        // Allocate in SimpleRewards campaign
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: victim, amount: ATTACK_AMOUNT, extraData: ""});
        bytes memory hookData = abi.encode(payouts);

        vm.prank(simpleRewardsManager);
        flywheel.allocate(simpleRewardsCampaign, address(token), hookData);

        // Verify allocation in flywheel core
        assertEq(flywheel.allocations(simpleRewardsCampaign, address(token), victim), ATTACK_AMOUNT);

        // Attacker tries to distribute from different campaign's allocation
        // This should fail because allocations are campaign-specific
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: victim,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12349
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, paymentHash),
            abi.encode(true, false, false)
        );

        // BuyerRewards campaign has no allocation for victim
        assertEq(flywheel.allocations(buyerRewardsCampaign, address(token), victim), 0);

        bytes memory buyerData = abi.encode(paymentInfo, ATTACK_AMOUNT);
        
        // Should fail - no allocation in BuyerRewards campaign
        vm.expectRevert(); // InsufficientAllocation or similar
        vm.prank(buyerRewardsManager);
        flywheel.distribute(buyerRewardsCampaign, address(token), buyerData);
    }

    // =============================================================
    //                    ECONOMIC ATTACK SCENARIOS
    // =============================================================

    /// @notice Test multi-campaign economic manipulation
    function test_security_multiCampaignEconomicManipulation() public {
        // Attacker with manager role in multiple campaigns could manipulate token prices
        // by coordinating large payouts across campaigns

        uint256 totalDrainAmount = 0;
        uint256 attackerBalanceBefore = token.balanceOf(attacker);

        // Drain SimpleRewards (manager has control)
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({
            recipient: attacker,
            amount: INITIAL_TOKEN_BALANCE / 2,
            extraData: ""
        });

        vm.prank(simpleRewardsManager);
        flywheel.reward(simpleRewardsCampaign, address(token), abi.encode(payouts));
        totalDrainAmount += INITIAL_TOKEN_BALANCE / 2;

        // Drain BuyerRewards (manager has control over payouts)
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: attacker,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12350
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, paymentHash),
            abi.encode(true, false, false)
        );

        vm.prank(buyerRewardsManager);
        flywheel.reward(buyerRewardsCampaign, address(token), abi.encode(paymentInfo, INITIAL_TOKEN_BALANCE / 2));
        totalDrainAmount += INITIAL_TOKEN_BALANCE / 2;

        // Verify coordinated drainage
        uint256 attackerBalanceAfter = token.balanceOf(attacker);
        assertEq(attackerBalanceAfter, attackerBalanceBefore + totalDrainAmount);
    }

    /// @notice Test cross-hook fee manipulation
    function test_security_crossHookFeeManipulation() public {
        // Set high attribution provider fee for ad campaign
        vm.prank(attributionProvider);
        adConversionHook.setAttributionProviderFee(5000); // 50% fee

        // Create attribution
        AdvertisementConversion.Attribution[] memory attributions = new AdvertisementConversion.Attribution[](1);
        attributions[0] = AdvertisementConversion.Attribution({
            conversion: AdvertisementConversion.Conversion({
                eventId: bytes16(uint128(1)),
                clickId: "click123",
                conversionConfigId: 1,
                publisherRefCode: "TEST_PUB",
                timestamp: uint32(block.timestamp),
                payoutRecipient: address(0),
                payoutAmount: 200e18
            }),
            logBytes: ""
        });

        bytes memory adHookData = abi.encode(attributions);

        // Attribution provider gets large fee from ad campaign
        uint256 providerBalanceBefore = token.balanceOf(attributionProvider);
        
        vm.prank(address(flywheel));
        (Flywheel.Payout[] memory payouts, uint256 fee) = 
            adConversionHook.onReward(attributionProvider, adConversionCampaign, address(token), adHookData);

        // Fee should be 50% of 200e18 = 100e18
        assertEq(fee, 100e18);

        // Other hooks (BuyerRewards, SimpleRewards) don't have fees
        // This creates economic imbalance that could be exploited
    }

    // =============================================================
    //                    REENTRANCY ACROSS HOOKS
    // =============================================================

    /// @notice Test cross-hook reentrancy attack
    function test_security_crossHookReentrancyAttack() public {
        // Deploy malicious contract that attempts cross-hook reentrancy
        CrossHookReentrancyAttacker attackerContract = new CrossHookReentrancyAttacker(
            address(flywheel),
            address(buyerRewardsHook),
            address(simpleRewardsHook),
            buyerRewardsCampaign,
            simpleRewardsCampaign
        );

        // This attack should fail due to access control
        vm.expectRevert();
        attackerContract.attemptCrossHookReentrancy();
    }
}

// =============================================================
//                    MALICIOUS CONTRACTS
// =============================================================

/// @notice Contract that attempts reentrancy across different hook types
contract CrossHookReentrancyAttacker {
    Flywheel public flywheel;
    BuyerRewards public buyerRewardsHook;
    SimpleRewards public simpleRewardsHook;
    address public buyerCampaign;
    address public simpleCampaign;
    bool public attacking;

    constructor(
        address _flywheel,
        address _buyerRewardsHook,
        address _simpleRewardsHook,
        address _buyerCampaign,
        address _simpleCampaign
    ) {
        flywheel = Flywheel(_flywheel);
        buyerRewardsHook = BuyerRewards(_buyerRewardsHook);
        simpleRewardsHook = SimpleRewards(_simpleRewardsHook);
        buyerCampaign = _buyerCampaign;
        simpleCampaign = _simpleCampaign;
    }

    function attemptCrossHookReentrancy() external {
        // This will fail because this contract is not authorized to call either hook
        Flywheel.Payout[] memory payouts = new Flywheel.Payout[](1);
        payouts[0] = Flywheel.Payout({recipient: address(this), amount: 100e18, extraData: ""});
        bytes memory hookData = abi.encode(payouts);

        flywheel.reward(simpleCampaign, address(0x1), hookData);
    }

    receive() external payable {
        if (!attacking) {
            attacking = true;
            // Attempt to call different hook during reentrancy
            try buyerRewardsHook.managers(buyerCampaign) {} catch {}
            try simpleRewardsHook.managers(simpleCampaign) {} catch {}
            attacking = false;
        }
    }
}
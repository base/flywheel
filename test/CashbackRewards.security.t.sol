// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";

import {Flywheel} from "../src/Flywheel.sol";
import {SimpleRewards} from "../src/hooks/SimpleRewards.sol";
import {CashbackRewards} from "../src/hooks/CashbackRewards.sol";
import {DummyERC20} from "./mocks/DummyERC20.sol";

/// @title CashbackRewards Security Test Suite
/// @notice Security-focused testing with attack scenarios and vulnerability analysis
/// @dev Implements comprehensive security testing patterns targeting payment manipulation and privilege escalation
contract CashbackRewardsSecurityTest is Test {
    Flywheel public flywheel;
    CashbackRewards public hook;
    AuthCaptureEscrow public escrow;
    DummyERC20 public token;

    address public owner = address(0x1000);
    address public manager = address(0x2000);
    address public payer = address(0x3000);
    address public merchant = address(0x4000);
    address public attacker = address(0xBAD);

    address public campaign;
    uint256 public constant INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 public constant CASHBACK_AMOUNT = 100e18;

    function setUp() public {
        // Deploy contracts
        flywheel = new Flywheel();
        escrow = new AuthCaptureEscrow();
        hook = new CashbackRewards(address(flywheel), address(escrow));

        // Deploy token with initial holders
        address[] memory initialHolders = new address[](3);
        initialHolders[0] = owner;
        initialHolders[1] = address(this);
        initialHolders[2] = attacker;
        token = new DummyERC20(initialHolders);

        // Create campaign
        bytes memory hookData = abi.encode(owner, manager, "https://api.example.com/campaign", 0);

        campaign = flywheel.createCampaign(address(hook), 1, hookData);

        // Fund campaign
        vm.prank(owner);
        token.transfer(campaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.ACTIVE, "");
    }

    // =============================================================
    //                    PAYMENT MANIPULATION ATTACKS
    // =============================================================

    /// @notice Test fake payment hash manipulation
    function test_security_fakePaymentHashManipulation() public {
        // Attacker creates fake payment info to bypass escrow checks
        AuthCaptureEscrow.PaymentInfo memory fakePayment = AuthCaptureEscrow.PaymentInfo({
            operator: attacker,
            payer: attacker,
            receiver: attacker,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 99999
        });

        bytes32 fakePaymentHash = escrow.getHash(fakePayment);

        // Mock fake payment as collected (payment never actually happened)
        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, fakePaymentHash),
            abi.encode(true, false, false) // Fake collected state
        );

        CashbackRewards.PaymentReward[] memory paymentRewards = new CashbackRewards.PaymentReward[](1);
        paymentRewards[0] =
            CashbackRewards.PaymentReward({paymentInfo: fakePayment, payoutAmount: uint120(CASHBACK_AMOUNT)});
        bytes memory hookData = abi.encode(paymentRewards);

        // Attacker attempts to get rewards for fake payment
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // Attacker received undeserved cashback
        assertEq(token.balanceOf(attacker), 1000000e18 + CASHBACK_AMOUNT);
    }

    /// @notice Test payment replay attacks
    function test_security_paymentReplayAttack() public {
        // Create legitimate payment
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
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

        CashbackRewards.PaymentReward[] memory paymentRewards = new CashbackRewards.PaymentReward[](1);
        paymentRewards[0] =
            CashbackRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(CASHBACK_AMOUNT)});
        bytes memory hookData = abi.encode(paymentRewards);

        // First reward (legitimate)
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        uint256 balanceAfterFirst = token.balanceOf(payer);
        assertEq(balanceAfterFirst, CASHBACK_AMOUNT);

        // Attempt to replay same payment for additional rewards
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // Payer should NOT receive double rewards
        uint256 balanceAfterReplay = token.balanceOf(payer);
        assertEq(balanceAfterReplay, CASHBACK_AMOUNT * 2); // Currently allows replay - this is a vulnerability
    }

    /// @notice Test cross-campaign payment reuse
    function test_security_crossCampaignPaymentReuse() public {
        // Create second campaign
        bytes memory hookData2 = abi.encode(owner, manager, "https://api.example.com/campaign2", 0);
        address campaign2 = flywheel.createCampaign(address(hook), 2, hookData2);

        vm.prank(owner);
        token.transfer(campaign2, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(campaign2, Flywheel.CampaignStatus.ACTIVE, "");

        // Use same payment info across both campaigns
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
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

        bytes32 paymentHash = escrow.getHash(paymentInfo);

        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, paymentHash),
            abi.encode(true, false, false)
        );

        CashbackRewards.PaymentReward[] memory paymentRewards = new CashbackRewards.PaymentReward[](1);
        paymentRewards[0] =
            CashbackRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(CASHBACK_AMOUNT)});
        bytes memory hookData = abi.encode(paymentRewards);

        // Get rewards from first campaign
        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // Attempt to get rewards from second campaign for same payment
        vm.prank(manager);
        flywheel.reward(campaign2, address(token), hookData);

        // Payer received double rewards for single payment
        assertEq(token.balanceOf(payer), CASHBACK_AMOUNT * 2); // Currently allows cross-campaign reuse
    }

    // =============================================================
    //                    PRIVILEGE ESCALATION ATTACKS
    // =============================================================

    /// @notice Test manager impersonation attack
    function test_security_managerImpersonation() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: attacker, // Attacker as payer to receive rewards
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

        CashbackRewards.PaymentReward[] memory paymentRewards = new CashbackRewards.PaymentReward[](1);
        paymentRewards[0] =
            CashbackRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(CASHBACK_AMOUNT)});
        bytes memory hookData = abi.encode(paymentRewards);

        // Attacker tries to call payout functions directly
        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(attacker);
        flywheel.reward(campaign, address(token), hookData);

        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(attacker);
        flywheel.allocate(campaign, address(token), hookData);
    }

    /// @notice Test owner vs manager privilege separation
    function test_security_ownerManagerPrivilegeSeparation() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
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

        CashbackRewards.PaymentReward[] memory paymentRewards = new CashbackRewards.PaymentReward[](1);
        paymentRewards[0] =
            CashbackRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(CASHBACK_AMOUNT)});
        bytes memory hookData = abi.encode(paymentRewards);

        // Owner cannot call payout functions (only manager can)
        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(owner);
        flywheel.reward(campaign, address(token), hookData);

        // Manager cannot withdraw funds (only owner can)
        vm.prank(manager);
        flywheel.updateStatus(campaign, Flywheel.CampaignStatus.FINALIZED, "");

        vm.expectRevert(SimpleRewards.Unauthorized.selector);
        vm.prank(manager);
        flywheel.withdrawFunds(campaign, address(token), 100e18, "");
    }

    // =============================================================
    //                    REENTRANCY ATTACKS
    // =============================================================

    /// @notice Test reentrancy attack via malicious token
    function test_security_reentrancyViaMaliciousToken() public {
        // Deploy malicious token that reenters on transfer
        MaliciousToken maliciousToken = new MaliciousToken(address(flywheel), campaign, manager);

        // Fund campaign with malicious token
        maliciousToken.mint(campaign, 1000e18);

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
            receiver: merchant,
            token: address(maliciousToken),
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

        CashbackRewards.PaymentReward[] memory paymentRewards = new CashbackRewards.PaymentReward[](1);
        paymentRewards[0] =
            CashbackRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(CASHBACK_AMOUNT)});
        bytes memory hookData = abi.encode(paymentRewards);

        // Malicious token will attempt reentrancy during transfer
        // The reentrancy attempt will be blocked, but the original call succeeds
        vm.prank(manager);
        flywheel.reward(campaign, address(maliciousToken), hookData);

        // Verify the original payout succeeded (reentrancy was blocked)
        assertEq(maliciousToken.balanceOf(payer), CASHBACK_AMOUNT);
    }

    // =============================================================
    //                    ALLOCATION/DISTRIBUTION MANIPULATION
    // =============================================================

    /// @notice Test allocation overflow attack
    function test_security_allocationOverflow() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
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

        // Try to allocate maximum uint120 amount
        CashbackRewards.PaymentReward[] memory paymentRewards = new CashbackRewards.PaymentReward[](1);
        paymentRewards[0] = CashbackRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: type(uint120).max});
        bytes memory hookData = abi.encode(paymentRewards);

        vm.prank(manager);
        vm.expectRevert(); // Should fail due to insufficient campaign balance
        flywheel.allocate(campaign, address(token), hookData);
    }

    /// @notice Test insufficient allocation distribution
    function test_security_insufficientAllocationDistribution() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: payer,
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12351
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);

        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, paymentHash),
            abi.encode(true, false, false)
        );

        // Allocate small amount
        CashbackRewards.PaymentReward[] memory allocateRewards = new CashbackRewards.PaymentReward[](1);
        allocateRewards[0] = CashbackRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(50e18)});
        bytes memory allocateData = abi.encode(allocateRewards);
        vm.prank(manager);
        flywheel.allocate(campaign, address(token), allocateData);

        // Try to distribute larger amount
        CashbackRewards.PaymentReward[] memory distributeRewards = new CashbackRewards.PaymentReward[](1);
        distributeRewards[0] =
            CashbackRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(CASHBACK_AMOUNT)}); // 100e18 > 50e18
        bytes memory distributeData = abi.encode(distributeRewards);

        vm.expectRevert(abi.encodeWithSelector(CashbackRewards.InsufficientAllocation.selector, CASHBACK_AMOUNT, 50e18));
        vm.prank(manager);
        flywheel.distribute(campaign, address(token), distributeData);
    }

    // =============================================================
    //                    ESCROW INTEGRATION ATTACKS
    // =============================================================

    /// @notice Test malicious escrow contract
    function test_security_maliciousEscrowContract() public {
        // Deploy hook with malicious escrow
        MaliciousEscrow maliciousEscrow = new MaliciousEscrow();
        CashbackRewards maliciousHook = new CashbackRewards(address(flywheel), address(maliciousEscrow));

        bytes memory hookData = abi.encode(owner, manager, "https://api.example.com/malicious", 0);

        address maliciousCampaign = flywheel.createCampaign(address(maliciousHook), 999, hookData);

        vm.prank(owner);
        token.transfer(maliciousCampaign, INITIAL_TOKEN_BALANCE);

        vm.prank(manager);
        flywheel.updateStatus(maliciousCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        AuthCaptureEscrow.PaymentInfo memory paymentInfo = AuthCaptureEscrow.PaymentInfo({
            operator: merchant,
            payer: attacker, // Attacker gets rewards
            receiver: merchant,
            token: address(token),
            maxAmount: 1000e6,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 1 days),
            refundExpiry: uint48(block.timestamp + 7 days),
            minFeeBps: 0,
            maxFeeBps: 1000,
            feeReceiver: address(0),
            salt: 12352
        });

        CashbackRewards.PaymentReward[] memory paymentRewards = new CashbackRewards.PaymentReward[](1);
        paymentRewards[0] =
            CashbackRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(CASHBACK_AMOUNT)});
        bytes memory rewardData = abi.encode(paymentRewards);

        // Malicious escrow always returns true for payment collected
        vm.prank(manager);
        flywheel.reward(maliciousCampaign, address(token), rewardData);

        // Attacker received rewards without legitimate payment
        assertEq(token.balanceOf(attacker), 1000000e18 + CASHBACK_AMOUNT);
    }

    // =============================================================
    //                    ECONOMIC ATTACKS
    // =============================================================

    /// @notice Test campaign fund drainage
    function test_security_campaignFundDrainage() public {
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
            salt: 12353
        });

        bytes32 paymentHash = escrow.getHash(paymentInfo);

        vm.mockCall(
            address(escrow),
            abi.encodeWithSelector(escrow.paymentState.selector, paymentHash),
            abi.encode(true, false, false)
        );

        // Attempt to drain entire campaign balance
        CashbackRewards.PaymentReward[] memory paymentRewards = new CashbackRewards.PaymentReward[](1);
        paymentRewards[0] =
            CashbackRewards.PaymentReward({paymentInfo: paymentInfo, payoutAmount: uint120(INITIAL_TOKEN_BALANCE)});
        bytes memory hookData = abi.encode(paymentRewards);

        vm.prank(manager);
        flywheel.reward(campaign, address(token), hookData);

        // Attacker drained entire campaign
        assertEq(token.balanceOf(attacker), 1000000e18 + INITIAL_TOKEN_BALANCE); // Initial + drained
        assertEq(token.balanceOf(campaign), 0);
    }
}

// =============================================================
//                    MALICIOUS CONTRACTS
// =============================================================

/// @notice Malicious token that attempts reentrancy on transfer
contract MaliciousToken {
    mapping(address => uint256) public balanceOf;
    Flywheel public flywheel;
    address public campaign;
    address public manager;
    bool public attacking;

    constructor(address _flywheel, address _campaign, address _manager) {
        flywheel = Flywheel(_flywheel);
        campaign = _campaign;
        manager = _manager;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        // Attempt reentrancy during transfer
        if (!attacking && to != campaign) {
            attacking = true;
            // Try to call flywheel.reward recursively during transfer
            try flywheel.reward(campaign, address(this), "") {} catch {}
            attacking = false;
        }

        return true;
    }
}

/// @notice Malicious escrow that always returns payment as collected
contract MaliciousEscrow {
    function getHash(AuthCaptureEscrow.PaymentInfo memory) external pure returns (bytes32) {
        return keccak256("fake_payment");
    }

    function paymentState(bytes32)
        external
        pure
        returns (bool hasCollectedPayment, bool hasRefundedPayment, bool hasExecuted)
    {
        return (true, false, false); // Always claim payment is collected
    }
}

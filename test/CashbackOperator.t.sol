// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC3009Token} from "commerce-payments/../test/mocks/MockERC3009Token.sol";
import {IERC3009} from "commerce-payments/interfaces/IERC3009.sol";

import {AuthCaptureEscrow} from "commerce-payments/AuthCaptureEscrow.sol";
import {ERC3009PaymentCollector} from "commerce-payments/collectors/ERC3009PaymentCollector.sol";
import {OperatorRefundCollector} from "commerce-payments/collectors/OperatorRefundCollector.sol";

import {Flywheel} from "../src/Flywheel.sol";
import {SimpleRewards} from "../src/hooks/SimpleRewards.sol";
import {CashbackOperator} from "../src/CashbackOperator.sol";

contract CashbackOperatorTest is Test {
    // Core contracts
    AuthCaptureEscrow public escrow;
    Flywheel public flywheel;
    SimpleRewards public rewardsHook;
    CashbackOperator public cashbackOperator;

    // Token and collectors
    MockERC3009Token public usdc;
    ERC3009PaymentCollector public paymentCollector;
    OperatorRefundCollector public refundCollector;

    // Test accounts
    address public operator;
    address public merchant;
    address public payer;
    address public feeReceiver;

    // Test constants
    uint256 public constant CASHBACK_BPS = 100; // 1%
    uint120 public constant PAYMENT_AMOUNT = 100e6; // $100 USDC
    uint256 public constant EXPECTED_CASHBACK = 1e6; // $1 USDC (1% of $100)
    uint16 public constant FEE_BPS = 0; // 0%

    uint256 private constant OPERATOR_PK = uint256(keccak256("operator"));
    uint256 private constant PAYER_PK = uint256(keccak256("payer"));

    // For ERC3009 signatures
    address public multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
    bytes32 constant _RECEIVE_WITH_AUTHORIZATION_TYPEHASH =
        0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8;

    event CashbackAllocated(address indexed payer, uint256 amount);
    event CashbackDistributed(address indexed payer, uint256 amount);

    function setUp() public {
        // Set up Multicall3 (needed for ERC3009PaymentCollector)
        vm.etch(
            multicall3,
            hex"6080604052600436106100f35760003560e01c80634d2301cc1161008a578063a8b0574e11610059578063a8b0574e1461025a578063bce38bd714610275578063c3077fa914610288578063ee82ac5e1461029b57600080fd5b80634d2301cc146101ec57806372425d9d1461022157806382ad56cb1461023457806386d516e81461024757600080fd5b80633408e470116100c65780633408e47014610191578063399542e9146101a45780633e64a696146101c657806342cbb15c146101d957600080fd5b80630f28c97d146100f8578063174dea711461011a578063252dba421461013a57806327e86d6e1461015b575b600080fd5b34801561010457600080fd5b50425b6040519081526020015b60405180910390f35b61012d610128366004610a85565b6102ba565b6040516101119190610bbe565b61014d610148366004610a85565b6104ef565b604051610111929190610bd8565b34801561016757600080fd5b50437fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0140610107565b34801561019d57600080fd5b5046610107565b6101b76101b2366004610c60565b610690565b60405161011193929190610cba565b3480156101d257600080fd5b5048610107565b3480156101e557600080fd5b5043610107565b3480156101f857600080fd5b50610107610207366004610ce2565b73ffffffffffffffffffffffffffffffffffffffff163190565b34801561022d57600080fd5b5044610107565b61012d610242366004610a85565b6106ab565b34801561025357600080fd5b5045610107565b34801561026657600080fd5b50604051418152602001610111565b61012d610283366004610c60565b61085a565b6101b7610296366004610a85565b610a1a565b3480156102a757600080fd5b506101076102b6366004610d18565b4090565b60606000828067ffffffffffffffff8111156102d8576102d8610d31565b60405190808252806020026020018201604052801561031e57816020015b6040805180820190915260008152606060208201528152602001906001900390816102f65790505b5092503660005b8281101561047757600085828151811061034157610341610d60565b6020026020010151905087878381811061035d5761035d610d60565b905060200281019061036f9190610d8f565b6040810135958601959093506103886020850185610ce2565b73ffffffffffffffffffffffffffffffffffffffff16816103ac6060870187610dcd565b6040516103ba929190610e32565b60006040518083038185875af1925050503d80600081146103f7576040519150601f19603f3d011682016040523d82523d6000602084013e6103fc565b606091505b50602080850191909152901515808452908501351761046d577f08c379a000000000000000000000000000000000000000000000000000000000600052602060045260176024527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060445260846000fd5b5050600101610325565b508234146104e6576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601a60248201527f4d756c746963616c6c333a2076616c7565206d69736d6174636800000000000060448201526064015b60405180910390fd5b50505092915050565b436060828067ffffffffffffffff81111561050c5761050c610d31565b60405190808252806020026020018201604052801561053f57816020015b606081526020019060019003908161052a5790505b5091503660005b8281101561068657600087878381811061056257610562610d60565b90506020028101906105749190610e42565b92506105836020840184610ce2565b73ffffffffffffffffffffffffffffffffffffffff166105a66020850185610dcd565b6040516105b4929190610e32565b6000604051808303816000865af19150503d80600081146105f1576040519150601f19603f3d011682016040523d82523d6000602084013e6105f6565b606091505b5086848151811061060957610609610d60565b602090810291909101015290508061067d576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601760248201527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060448201526064016104dd565b50600101610546565b5050509250929050565b43804060606106a086868661085a565b905093509350939050565b6060818067ffffffffffffffff8111156106c7576106c7610d31565b60405190808252806020026020018201604052801561070d57816020015b6040805180820190915260008152606060208201528152602001906001900390816106e55790505b5091503660005b828110156104e657600084828151811061073057610730610d60565b6020026020010151905086868381811061074c5761074c610d60565b905060200281019061075e9190610e76565b925061076d6020840184610ce2565b73ffffffffffffffffffffffffffffffffffffffff166107906040850185610dcd565b60405161079e929190610e32565b6000604051808303816000865af19150503d80600081146107db576040519150601f19603f3d011682016040523d82523d6000602084013e6107e0565b606091505b506020808401919091529015158083529084013517610851577f08c379a000000000000000000000000000000000000000000000000000000000600052602060045260176024527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060445260646000fd5b50600101610714565b6060818067ffffffffffffffff81111561087657610876610d31565b6040519080825280602002602001820160405280156108bc57816020015b6040805180820190915260008152606060208201528152602001906001900390816108945790505b5091503660005b82811015610a105760008482815181106108df576108df610d60565b602002602001015190508686838181106108fb576108fb610d60565b905060200281019061090d9190610e42565b925061091c6020840184610ce2565b73ffffffffffffffffffffffffffffffffffffffff1661093f6020850185610dcd565b60405161094d929190610e32565b6000604051808303816000865af19150503d806000811461098a576040519150601f19603f3d011682016040523d82523d6000602084013e61098f565b606091505b506020830152151581528715610a07578051610a07576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601760248201527f4d756c746963616c6c333a2063616c6c206661696c656400000000000000000060448201526064016104dd565b506001016108c3565b5050509392505050565b6000806060610a2b60018686610690565b919790965090945092505050565b60008083601f840112610a4b57600080fd5b50813567ffffffffffffffff811115610a6357600080fd5b6020830191508360208260051b8501011115610a7e57600080fd5b9250929050565b60008060208385031215610a9857600080fd5b823567ffffffffffffffff811115610aaf57600080fd5b610abb85828601610a39565b90969095509350505050565b6000815180845260005b81811015610aed57602081850181015186830182015201610ad1565b81811115610aff576000602083870101525b50601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0169290920160200192915050565b600082825180855260208086019550808260051b84010181860160005b84811015610bb1578583037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe001895281518051151584528401516040858501819052610b9d81860183610ac7565b9a86019a9450505090830190600101610b4f565b5090979650505050505050565b602081526000610bd16020830184610b32565b9392505050565b600060408201848352602060408185015281855180845260608601915060608160051b870101935082870160005b82811015610c52577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa0888703018452610c40868351610ac7565b95509284019290840190600101610c06565b509398975050505050505050565b600080600060408486031215610c7557600080fd5b83358015158114610c8557600080fd5b9250602084013567ffffffffffffffff811115610ca157600080fd5b610cad86828701610a39565b9497909650939450505050565b838152826020820152606060408201526000610cd96060830184610b32565b95945050505050565b600060208284031215610cf457600080fd5b813573ffffffffffffffffffffffffffffffffffffffff81168114610bd157600080fd5b600060208284031215610d2a57600080fd5b5035919050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b600082357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff81833603018112610dc357600080fd5b9190910192915050565b60008083357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1843603018112610e0257600080fd5b83018035915067ffffffffffffffff821115610e1d57600080fd5b602001915036819003821315610a7e57600080fd5b8183823760009101908152919050565b600082357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc1833603018112610dc357600080fd5b600082357fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa1833603018112610dc357600080fdfea2646970667358221220bb2b5c71a328032f97c676ae39a1ec2148d3e5d6f73d95e9b17910152d61f16264736f6c634300080c0033"
        );

        // Create test accounts
        operator = vm.addr(OPERATOR_PK);
        payer = vm.addr(PAYER_PK);
        merchant = makeAddr("merchant");
        feeReceiver = makeAddr("feeReceiver");

        vm.label(operator, "operator");
        vm.label(merchant, "merchant");
        vm.label(payer, "payer");
        vm.label(feeReceiver, "feeReceiver");

        // Deploy mock ERC3009 USDC token
        usdc = new MockERC3009Token("USD Coin", "USDC", 6);

        // Mint tokens to payer for payments
        usdc.mint(payer, 10_000e6); // $10,000 USDC

        // Deploy AuthCaptureEscrow
        escrow = new AuthCaptureEscrow();

        // Deploy token collectors
        paymentCollector = new ERC3009PaymentCollector(address(escrow), multicall3);
        refundCollector = new OperatorRefundCollector(address(escrow));

        // Deploy Flywheel infrastructure
        flywheel = new Flywheel();
        rewardsHook = new SimpleRewards(address(flywheel));

        // Deploy CashbackOperator
        cashbackOperator = new CashbackOperator(
            CASHBACK_BPS,
            address(escrow),
            address(flywheel),
            address(rewardsHook),
            operator // owner
        );

        // Fund the cashback campaign with USDC for rewards
        usdc.mint(cashbackOperator.cashbackCampaign(), 1_000e6); // $1,000 for cashback

        // Fund the CashbackOperator contract for refunds
        usdc.mint(address(cashbackOperator), 1_000e6); // Fund the contract itself

        // Approve the refund collector to spend tokens from the CashbackOperator
        vm.startPrank(operator);
        cashbackOperator.approveToken(address(usdc), address(refundCollector), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Helper to create a standard PaymentInfo struct
    function _createPaymentInfo() internal view returns (AuthCaptureEscrow.PaymentInfo memory) {
        return AuthCaptureEscrow.PaymentInfo({
            operator: address(cashbackOperator), // CashbackOperator acts as the operator
            payer: payer,
            receiver: merchant,
            token: address(usdc),
            maxAmount: PAYMENT_AMOUNT,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 2 hours),
            refundExpiry: uint48(block.timestamp + 3 hours),
            minFeeBps: FEE_BPS,
            maxFeeBps: FEE_BPS,
            feeReceiver: feeReceiver,
            salt: 0
        });
    }

    /// @notice Helper to create a PaymentInfo struct with a specific salt
    function _createPaymentInfoWithSalt(string memory salt)
        internal
        view
        returns (AuthCaptureEscrow.PaymentInfo memory)
    {
        return AuthCaptureEscrow.PaymentInfo({
            operator: address(cashbackOperator), // CashbackOperator acts as the operator
            payer: payer,
            receiver: merchant,
            token: address(usdc),
            maxAmount: PAYMENT_AMOUNT,
            preApprovalExpiry: uint48(block.timestamp + 1 hours),
            authorizationExpiry: uint48(block.timestamp + 2 hours),
            refundExpiry: uint48(block.timestamp + 3 hours),
            minFeeBps: FEE_BPS,
            maxFeeBps: FEE_BPS,
            feeReceiver: feeReceiver,
            salt: uint256(keccak256(abi.encode(salt)))
        });
    }

    /// @notice Helper to get current balances
    function _getBalances()
        internal
        view
        returns (uint256 payerUSDC, uint256 merchantUSDC, uint256 payerAllocation, uint256 campaignUSDC)
    {
        payerUSDC = usdc.balanceOf(payer);
        merchantUSDC = usdc.balanceOf(merchant);
        payerAllocation = flywheel.allocations(cashbackOperator.cashbackCampaign(), address(usdc), payer);
        campaignUSDC = usdc.balanceOf(cashbackOperator.cashbackCampaign());
    }

    /// @notice Sign ERC3009 receiveWithAuthorization struct
    function _signERC3009ReceiveWithAuthorizationStruct(
        AuthCaptureEscrow.PaymentInfo memory paymentInfo,
        uint256 signerPk
    ) internal view returns (bytes memory) {
        bytes32 nonce = _getHashPayerAgnostic(paymentInfo);

        bytes32 digest = _getERC3009Digest(
            paymentInfo.token,
            paymentInfo.payer,
            address(paymentCollector),
            paymentInfo.maxAmount,
            0,
            paymentInfo.preApprovalExpiry,
            nonce
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @notice Get ERC3009 digest for signing
    function _getERC3009Digest(
        address token,
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce
    ) internal view returns (bytes32) {
        bytes32 structHash =
            keccak256(abi.encode(_RECEIVE_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce));
        return keccak256(abi.encodePacked("\x19\x01", IERC3009(token).DOMAIN_SEPARATOR(), structHash));
    }

    /// @notice Get hash without payer for nonce generation
    function _getHashPayerAgnostic(AuthCaptureEscrow.PaymentInfo memory paymentInfo) internal view returns (bytes32) {
        address _payer = paymentInfo.payer;
        paymentInfo.payer = address(0);
        bytes32 hash = escrow.getHash(paymentInfo);
        paymentInfo.payer = _payer;
        return hash;
    }

    /// @notice Test the complete happy path: authorize → capture → receive cashback
    function test_happyPath_authorizeAndCapture() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = _createPaymentInfo();

        // Record initial balances
        (uint256 initialPayerUSDC, uint256 initialMerchantUSDC, uint256 initialAllocation, uint256 initialCampaignUSDC)
        = _getBalances();

        // Generate ERC3009 signature for authorization
        bytes memory signature = _signERC3009ReceiveWithAuthorizationStruct(paymentInfo, PAYER_PK);

        // Step 1: Payer authorizes payment with cashback allocation
        vm.prank(address(cashbackOperator));
        cashbackOperator.authorize(
            paymentInfo,
            PAYMENT_AMOUNT,
            address(paymentCollector),
            signature // ERC3009 signature as collector data
        );

        // Verify authorization state
        (
            uint256 afterAuthPayerUSDC,
            uint256 afterAuthMerchantUSDC,
            uint256 afterAuthAllocation,
            uint256 afterAuthCampaignUSDC
        ) = _getBalances();

        // Payer should have lost $100 (now in escrow)
        assertEq(afterAuthPayerUSDC, initialPayerUSDC - PAYMENT_AMOUNT, "Payer USDC should decrease by payment amount");

        // Merchant shouldn't receive anything yet
        assertEq(afterAuthMerchantUSDC, initialMerchantUSDC, "Merchant should not receive payment during authorization");

        // Payer should have $1 allocated for cashback
        assertEq(afterAuthAllocation, initialAllocation + EXPECTED_CASHBACK, "Payer should have cashback allocated");

        // Campaign balance should be unchanged (allocation doesn't move tokens)
        assertEq(afterAuthCampaignUSDC, initialCampaignUSDC, "Campaign balance unchanged during allocation");

        // Verify payment allocation tracking
        bytes32 paymentHash = escrow.getHash(paymentInfo);
        assertEq(
            cashbackOperator.paymentAllocations(paymentHash), EXPECTED_CASHBACK, "Payment allocation should be tracked"
        );

        // Step 2: Merchant captures payment and distributes cashback
        vm.prank(address(cashbackOperator));
        cashbackOperator.capture(paymentInfo, PAYMENT_AMOUNT, FEE_BPS, feeReceiver);

        // Verify final state
        (uint256 finalPayerUSDC, uint256 finalMerchantUSDC, uint256 finalAllocation, uint256 finalCampaignUSDC) =
            _getBalances();

        // Payer should have received $1 cashback
        assertEq(finalPayerUSDC, afterAuthPayerUSDC + EXPECTED_CASHBACK, "Payer should receive cashback");

        // Merchant should receive full payment amount
        uint256 expectedMerchantAmount = PAYMENT_AMOUNT - (PAYMENT_AMOUNT * FEE_BPS / 10000);
        assertEq(
            finalMerchantUSDC, initialMerchantUSDC + expectedMerchantAmount, "Merchant should receive payment minus fee"
        );

        // Payer allocation should be back to initial (distributed)
        assertEq(finalAllocation, initialAllocation, "Payer allocation should be cleared after distribution");

        // Campaign should have lost the cashback amount
        assertEq(finalCampaignUSDC, initialCampaignUSDC - EXPECTED_CASHBACK, "Campaign should have disbursed cashback");

        // Payment allocation tracking should be cleared
        assertEq(cashbackOperator.paymentAllocations(paymentHash), 0, "Payment allocation tracking should be cleared");

        // Verify fee receiver got the fee
        uint256 expectedFee = PAYMENT_AMOUNT * FEE_BPS / 10000;
        assertEq(usdc.balanceOf(feeReceiver), expectedFee, "Fee receiver should get the fee");
    }

    /// @notice Test the immediate charge flow (charge + reward in one step)
    function test_happyPath_immediateCharge() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = _createPaymentInfo();

        // Record initial balances
        (uint256 initialPayerUSDC, uint256 initialMerchantUSDC,, uint256 initialCampaignUSDC) = _getBalances();

        // Generate ERC3009 signature for authorization
        bytes memory signature = _signERC3009ReceiveWithAuthorizationStruct(paymentInfo, PAYER_PK);

        // Step 1: Immediate charge with cashback reward
        vm.prank(address(cashbackOperator));
        cashbackOperator.charge(
            paymentInfo,
            PAYMENT_AMOUNT,
            address(paymentCollector),
            signature, // ERC3009 signature as collector data
            FEE_BPS,
            feeReceiver
        );

        // Verify final state (everything happens atomically)
        (uint256 finalPayerUSDC, uint256 finalMerchantUSDC,, uint256 finalCampaignUSDC) = _getBalances();

        // Payer should have lost $100 but gained $1 cashback (net -$99)
        assertEq(
            finalPayerUSDC, initialPayerUSDC - PAYMENT_AMOUNT + EXPECTED_CASHBACK, "Payer should pay minus cashback"
        );

        // Merchant should receive payment minus fee
        uint256 expectedMerchantAmount = PAYMENT_AMOUNT - (PAYMENT_AMOUNT * FEE_BPS / 10000);
        assertEq(
            finalMerchantUSDC, initialMerchantUSDC + expectedMerchantAmount, "Merchant should receive payment minus fee"
        );

        // Campaign should have lost the cashback amount
        assertEq(finalCampaignUSDC, initialCampaignUSDC - EXPECTED_CASHBACK, "Campaign should have disbursed cashback");

        // No allocation tracking for immediate rewards
        bytes32 paymentHash = escrow.getHash(paymentInfo);
        assertEq(cashbackOperator.paymentAllocations(paymentHash), 0, "No allocation tracking for immediate rewards");
    }

    /// @notice Test voiding a payment deallocates cashback
    function test_voidPayment_deallocatesCashback() public {
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = _createPaymentInfo();

        // Generate ERC3009 signature for authorization
        bytes memory signature = _signERC3009ReceiveWithAuthorizationStruct(paymentInfo, PAYER_PK);

        // Step 1: Authorize payment
        vm.prank(address(cashbackOperator));
        cashbackOperator.authorize(paymentInfo, PAYMENT_AMOUNT, address(paymentCollector), signature);

        // Verify allocation exists
        uint256 allocation = flywheel.allocations(cashbackOperator.cashbackCampaign(), address(usdc), payer);
        assertEq(allocation, EXPECTED_CASHBACK, "Cashback should be allocated");

        bytes32 paymentHash = escrow.getHash(paymentInfo);
        assertEq(
            cashbackOperator.paymentAllocations(paymentHash), EXPECTED_CASHBACK, "Payment allocation should be tracked"
        );

        // Step 2: Void the payment
        vm.prank(address(cashbackOperator));
        cashbackOperator.void(paymentInfo);

        // Verify allocation is cleared
        uint256 finalAllocation = flywheel.allocations(cashbackOperator.cashbackCampaign(), address(usdc), payer);
        assertEq(finalAllocation, 0, "Cashback allocation should be cleared after void");

        // Payment allocation tracking should be cleared
        assertEq(
            cashbackOperator.paymentAllocations(paymentHash),
            0,
            "Payment allocation tracking should be cleared after void"
        );

        // Payer should get their money back
        assertEq(usdc.balanceOf(payer), 10_000e6, "Payer should get full refund after void");
    }

    /// @notice Test multiple payments for same payer
    function test_multiplePayments_independentAllocations() public {
        // Create two different payments
        AuthCaptureEscrow.PaymentInfo memory payment1 = _createPaymentInfo();

        AuthCaptureEscrow.PaymentInfo memory payment2 = _createPaymentInfo();
        payment2.salt = uint256(keccak256(abi.encode("payment2")));

        // Generate signatures for both payments
        bytes memory signature1 = _signERC3009ReceiveWithAuthorizationStruct(payment1, PAYER_PK);
        bytes memory signature2 = _signERC3009ReceiveWithAuthorizationStruct(payment2, PAYER_PK);

        // Authorize both payments
        vm.startPrank(address(cashbackOperator));

        cashbackOperator.authorize(payment1, PAYMENT_AMOUNT, address(paymentCollector), signature1);
        cashbackOperator.authorize(payment2, PAYMENT_AMOUNT, address(paymentCollector), signature2);

        vm.stopPrank();

        // Payer should have $2 total allocated (2 × $1)
        uint256 totalAllocation = flywheel.allocations(cashbackOperator.cashbackCampaign(), address(usdc), payer);
        assertEq(totalAllocation, EXPECTED_CASHBACK * 2, "Payer should have 2x cashback allocated");

        // Each payment should track its own allocation
        bytes32 payment1Hash = escrow.getHash(payment1);
        bytes32 payment2Hash = escrow.getHash(payment2);
        assertEq(
            cashbackOperator.paymentAllocations(payment1Hash),
            EXPECTED_CASHBACK,
            "Payment 1 should track its allocation"
        );
        assertEq(
            cashbackOperator.paymentAllocations(payment2Hash),
            EXPECTED_CASHBACK,
            "Payment 2 should track its allocation"
        );

        // Capture only payment1
        vm.prank(address(cashbackOperator));
        cashbackOperator.capture(payment1, PAYMENT_AMOUNT, FEE_BPS, feeReceiver);

        // Payer should now have $1 allocated (payment2 only)
        uint256 remainingAllocation = flywheel.allocations(cashbackOperator.cashbackCampaign(), address(usdc), payer);
        assertEq(
            remainingAllocation, EXPECTED_CASHBACK, "Payer should have 1x cashback allocated after payment1 capture"
        );

        // Payment1 tracking should be cleared, payment2 should remain
        assertEq(
            cashbackOperator.paymentAllocations(payment1Hash), 0, "Payment 1 allocation tracking should be cleared"
        );
        assertEq(
            cashbackOperator.paymentAllocations(payment2Hash),
            EXPECTED_CASHBACK,
            "Payment 2 allocation tracking should remain"
        );
    }

    /// @notice Test refund flow - capture then refund should deallocate cashback
    function test_refundFlow_deallocatesCashback() public {
        // Create payment and capture it first
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = _createPaymentInfoWithSalt("refund_test");
        bytes memory signature = _signERC3009ReceiveWithAuthorizationStruct(paymentInfo, PAYER_PK);

        // Step 1: Authorize and capture payment
        vm.startPrank(address(cashbackOperator));
        cashbackOperator.authorize(paymentInfo, PAYMENT_AMOUNT, address(paymentCollector), signature);
        cashbackOperator.capture(paymentInfo, PAYMENT_AMOUNT, FEE_BPS, feeReceiver);
        vm.stopPrank();

        // Verify cashback was distributed
        uint256 payerBalanceAfterCapture = usdc.balanceOf(payer);
        assertEq(
            payerBalanceAfterCapture,
            10_000e6 - PAYMENT_AMOUNT + EXPECTED_CASHBACK,
            "Payer should have received cashback"
        );

        // Verify no allocation remains (distributed, not allocated)
        uint256 allocationAfterCapture = flywheel.allocations(cashbackOperator.cashbackCampaign(), address(usdc), payer);
        assertEq(allocationAfterCapture, 0, "Should have no allocation after distribution");

        // Step 2: Refund the payment
        vm.startPrank(address(cashbackOperator));
        cashbackOperator.refund(paymentInfo, PAYMENT_AMOUNT, address(refundCollector), "");
        vm.stopPrank();

        // Verify payer has their original funds back
        uint256 payerBalanceAfterRefund = usdc.balanceOf(payer);
        assertEq(payerBalanceAfterRefund, 10_000e6, "Payer should have orignal funds but not more");

        // Verify merchant balance is unchanged (they do not provide the liquidity for the refund)
        uint256 merchantBalanceAfterRefund = usdc.balanceOf(merchant);
        assertEq(merchantBalanceAfterRefund, PAYMENT_AMOUNT, "Merchant should retain full payment for now");

        // Verify operator contract balance decreased by actual refunded amount
        uint256 expectedRefundAmount = PAYMENT_AMOUNT - (PAYMENT_AMOUNT * CASHBACK_BPS) / 10000;
        uint256 operatorBalanceAfterRefund = usdc.balanceOf(address(cashbackOperator));
        assertEq(
            operatorBalanceAfterRefund,
            1_000e6 - expectedRefundAmount,
            "Operator should be less the actual refund amount"
        );
    }

    /// @notice Test direct reclaim cleanup - when user bypasses CashbackOperator
    function test_directReclaim_cleanupOrphanedAllocation() public {
        // Create payment and authorize (but don't capture)
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = _createPaymentInfoWithSalt("reclaim_test");
        bytes memory signature = _signERC3009ReceiveWithAuthorizationStruct(paymentInfo, PAYER_PK);

        // Step 1: Authorize payment (allocates cashback)
        vm.startPrank(address(cashbackOperator));
        cashbackOperator.authorize(paymentInfo, PAYMENT_AMOUNT, address(paymentCollector), signature);
        vm.stopPrank();

        // Verify cashback was allocated
        uint256 allocationAfterAuth = flywheel.allocations(cashbackOperator.cashbackCampaign(), address(usdc), payer);
        assertEq(allocationAfterAuth, EXPECTED_CASHBACK, "Payer should have cashback allocated");

        bytes32 paymentHash = escrow.getHash(paymentInfo);
        uint256 trackedAllocation = cashbackOperator.paymentAllocations(paymentHash);
        assertEq(trackedAllocation, EXPECTED_CASHBACK, "Should track the allocation amount");

        // Step 2: Fast forward past authorization expiry
        vm.warp(block.timestamp + 3 hours); // Past authorizationExpiry

        // Step 3: Payer directly reclaims from AuthCaptureEscrow (bypassing CashbackOperator)
        vm.startPrank(payer);
        escrow.reclaim(paymentInfo);
        vm.stopPrank();

        // Verify payer got their funds back
        uint256 payerBalanceAfterReclaim = usdc.balanceOf(payer);
        assertEq(payerBalanceAfterReclaim, 10_000e6, "Payer should have original balance back");

        // But allocation is still there (orphaned)
        uint256 allocationAfterReclaim = flywheel.allocations(cashbackOperator.cashbackCampaign(), address(usdc), payer);
        assertEq(allocationAfterReclaim, EXPECTED_CASHBACK, "Allocation should still exist (orphaned)");

        // Step 4: Clean up the orphaned allocation
        cashbackOperator.cleanupOrphanedAllocation(paymentInfo);

        // Verify allocation was deallocated
        uint256 allocationAfterCleanup = flywheel.allocations(cashbackOperator.cashbackCampaign(), address(usdc), payer);
        assertEq(allocationAfterCleanup, 0, "Allocation should be cleaned up");

        // Verify tracking was cleared
        uint256 trackedAllocationAfterCleanup = cashbackOperator.paymentAllocations(paymentHash);
        assertEq(trackedAllocationAfterCleanup, 0, "Payment allocation tracking should be cleared");

        // Verify campaign balance is restored
        uint256 campaignBalanceAfterCleanup = usdc.balanceOf(cashbackOperator.cashbackCampaign());
        assertEq(campaignBalanceAfterCleanup, 1_000e6, "Campaign should have funds returned");
    }

    /// @notice Test cleanup fails if payment wasn't actually reclaimed
    function test_cleanupOrphanedAllocation_revertsIfNotReclaimed() public {
        // Create and authorize a payment
        AuthCaptureEscrow.PaymentInfo memory paymentInfo = _createPaymentInfoWithSalt("cleanup_revert_test");
        bytes memory signature = _signERC3009ReceiveWithAuthorizationStruct(paymentInfo, PAYER_PK);

        vm.startPrank(address(cashbackOperator));
        cashbackOperator.authorize(paymentInfo, PAYMENT_AMOUNT, address(paymentCollector), signature);
        vm.stopPrank();

        // Try to cleanup without reclaiming first - should revert
        vm.expectRevert(CashbackOperator.PaymentNotReclaimed.selector);
        cashbackOperator.cleanupOrphanedAllocation(paymentInfo);
    }
}

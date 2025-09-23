// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {MockERC3009Token} from "../../../lib/commerce-payments/test/mocks/MockERC3009Token.sol";

import {BridgeRewards} from "../../../src/hooks/BridgeRewards.sol";
import {BuilderCodes} from "../../../src/BuilderCodes.sol";
import {Flywheel} from "../../../src/Flywheel.sol";
import {Constants} from "../../../src/Constants.sol";

contract BridgeRewardsTest is Test {
    Flywheel public flywheel;
    BridgeRewards public bridgeRewards;
    BuilderCodes public builderCodes;
    MockERC3009Token public usdc;

    address public bridgeRewardsCampaign;
    address public owner = address(0x1);
    address public user = address(0x2);
    address public builder = address(0x3);
    address public builderPayout = address(0x4);

    bytes32 public constant TEST_CODE = bytes32("testcode");
    string public constant TEST_CODE_STRING = "testcode";
    string public constant CAMPAIGN_URI = "https://example.com/campaign/metadata";

    function setUp() public virtual {
        // Deploy Flywheel
        flywheel = new Flywheel();

        // Deploy and initialize BuilderCodes
        BuilderCodes impl = new BuilderCodes();
        bytes memory initData = abi.encodeWithSelector(
            BuilderCodes.initialize.selector,
            owner,
            owner, // registrar
            "" // empty baseURI
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        builderCodes = BuilderCodes(address(proxy));

        // Deploy BridgeRewards
        bridgeRewards = new BridgeRewards(address(flywheel), address(builderCodes), CAMPAIGN_URI);

        // Deploy mock USDC
        usdc = new MockERC3009Token("USD Coin", "USDC", 6);

        // Register a test builder code
        vm.startPrank(owner);
        builderCodes.register(TEST_CODE_STRING, builder, builderPayout);
        vm.stopPrank();

        // Create campaign
        bridgeRewardsCampaign = flywheel.createCampaign(address(bridgeRewards), 0, "");

        // Activate the campaign since BridgeRewards only allows ACTIVE status
        flywheel.updateStatus(bridgeRewardsCampaign, Flywheel.CampaignStatus.ACTIVE, "");

        vm.label(bridgeRewardsCampaign, "BridgeRewardsCampaign");
        vm.label(address(flywheel), "Flywheel");
        vm.label(address(bridgeRewards), "BridgeRewards");
        vm.label(address(builderCodes), "BuilderCodes");
        vm.label(address(usdc), "USDC");
        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(builder, "Builder");
        vm.label(builderPayout, "BuilderPayout");
    }

    function test_onCreateCampaign_revert_invalidNonce() public {
        // Should revert with non-zero nonce
        vm.expectRevert(BridgeRewards.InvalidCampaignInitialization.selector);
        flywheel.createCampaign(address(bridgeRewards), 1, "");
    }

    function test_onCreateCampaign_revert_invalidHookData() public {
        // Should revert with non-empty hook data
        vm.expectRevert(BridgeRewards.InvalidCampaignInitialization.selector);
        flywheel.createCampaign(address(bridgeRewards), 0, "invalid");
    }

    function test_onSend_revert_zeroBalance() public {
        // Prepare hook data
        bytes memory hookData = abi.encode(user, TEST_CODE, uint16(100)); // 1% fee

        // Should revert when campaign has zero balance
        vm.expectRevert(abi.encodeWithSelector(BridgeRewards.ZeroAmount.selector));
        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);
    }

    function test_onSend_success() public {
        // Fund the campaign
        uint256 campaignBalance = 100e6; // 100 USDC
        usdc.mint(bridgeRewardsCampaign, campaignBalance);

        // Prepare hook data with 1% fee
        uint16 feeBps = 100; // 1%
        bytes memory hookData = abi.encode(user, TEST_CODE, feeBps);

        uint256 feeAmount = (campaignBalance * feeBps) / 10000;
        uint256 userAmount = campaignBalance - feeAmount;

        // Record balances before
        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 builderPayoutBalanceBefore = usdc.balanceOf(builderPayout);

        // Execute send
        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);

        // Check final balances
        assertEq(usdc.balanceOf(user), userBalanceBefore + userAmount, "User should receive balance minus fee");
        assertEq(usdc.balanceOf(builderPayout), builderPayoutBalanceBefore + feeAmount, "Builder should receive fee");
        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Campaign should be empty");
    }

    function test_onSend_success_no_fee() public {
        // Fund the campaign
        uint256 campaignBalance = 100e6; // 100 USDC
        usdc.mint(bridgeRewardsCampaign, campaignBalance);

        // Prepare hook data with 0% fee
        uint16 feeBps = 0;
        bytes memory hookData = abi.encode(user, TEST_CODE, feeBps);

        // Record balances before
        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 builderPayoutBalanceBefore = usdc.balanceOf(builderPayout);

        // Execute send
        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);

        // Check final balances
        assertEq(usdc.balanceOf(user), userBalanceBefore + campaignBalance, "User should receive full balance");
        assertEq(usdc.balanceOf(builderPayout), builderPayoutBalanceBefore, "Builder should receive no fee");
        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Campaign should be empty");
    }

    function test_onSend_success_builderCodeNotRegistered() public {
        // Fund the campaign
        uint256 campaignBalance = 100e6; // 100 USDC
        usdc.mint(bridgeRewardsCampaign, campaignBalance);

        // Prepare hook data with 1% fee
        uint16 feeBps = 100; // 1%
        bytes32 unregisteredCode = bytes32("unregistered");
        bytes memory hookData = abi.encode(user, unregisteredCode, feeBps);

        // Record balances before
        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 builderPayoutBalanceBefore = usdc.balanceOf(builderPayout);

        // Execute send
        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);

        // Check final balances
        assertEq(usdc.balanceOf(user), userBalanceBefore + campaignBalance, "User should receive full balance");
        assertEq(usdc.balanceOf(builderPayout), builderPayoutBalanceBefore, "Builder should receive no fee");
        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Campaign should be empty");
    }

    function test_onSend_success_feeBasisPointsTooHigh() public {
        // Fund the campaign
        uint256 campaignBalance = 100e6; // 100 USDC
        usdc.mint(bridgeRewardsCampaign, campaignBalance);

        // Use fee higher than maximum (2%)
        uint16 feeBps = uint16(bridgeRewards.MAX_FEE_BASIS_POINTS() + 1);
        bytes memory hookData = abi.encode(user, TEST_CODE, feeBps);

        uint256 feeAmount = (campaignBalance * bridgeRewards.MAX_FEE_BASIS_POINTS()) / 10000;
        uint256 userAmount = campaignBalance - feeAmount;

        // Record balances before
        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 builderPayoutBalanceBefore = usdc.balanceOf(builderPayout);

        // Execute send
        flywheel.send(bridgeRewardsCampaign, address(usdc), hookData);

        // Check final balances
        assertEq(usdc.balanceOf(user), userBalanceBefore + userAmount, "User should receive balance minus fee");
        assertEq(usdc.balanceOf(builderPayout), builderPayoutBalanceBefore + feeAmount, "Builder should receive fee");
        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Campaign should be empty");
    }

    function test_onWithdrawFunds_success() public {
        // Fund the campaign
        uint256 campaignBalance = 100e6; // 100 USDC
        usdc.mint(bridgeRewardsCampaign, campaignBalance);

        // Prepare withdrawal hook data
        Flywheel.Payout memory payout = Flywheel.Payout({recipient: user, amount: campaignBalance, extraData: ""});
        bytes memory hookData = abi.encode(payout);

        // Record balances before
        uint256 userBalanceBefore = usdc.balanceOf(user);

        // Execute withdrawal
        flywheel.withdrawFunds(bridgeRewardsCampaign, address(usdc), hookData);

        // Check final balances
        assertEq(usdc.balanceOf(user), userBalanceBefore + campaignBalance, "User should receive withdrawn amount");
        assertEq(usdc.balanceOf(bridgeRewardsCampaign), 0, "Campaign should be empty");
    }

    function test_onUpdateStatus_revert_newStatusNotActive() public {
        // Try to set status to something other than ACTIVE
        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        flywheel.updateStatus(bridgeRewardsCampaign, Flywheel.CampaignStatus.FINALIZED, "");

        vm.expectRevert(Flywheel.InvalidCampaignStatus.selector);
        flywheel.updateStatus(bridgeRewardsCampaign, Flywheel.CampaignStatus.FINALIZING, "");
    }

    function test_onUpdateStatus_success() public {
        // The setUp already created a campaign and activated it successfully
        // So we just need to verify that this transition worked
        Flywheel.CampaignStatus status = flywheel.campaignStatus(bridgeRewardsCampaign);
        assertEq(uint256(status), uint256(Flywheel.CampaignStatus.ACTIVE), "Campaign should be active");
    }

    function test_onUpdateMetadata_success() public {
        // Anyone should be able to update metadata (no access control)
        vm.prank(user);
        flywheel.updateMetadata(bridgeRewardsCampaign, "");

        // Should not revert - the hook allows anyone to trigger metadata updates
        // This is useful for refreshing cached metadata even though the URI is fixed
    }

    // =============================================================
    //                    NATIVE TOKEN TESTS
    // =============================================================

    function test_send_nativeToken_succeeds() public {
        // Fund campaign with native token
        vm.deal(bridgeRewardsCampaign, 1 ether);

        // Prepare hook data (user, code, fee)
        uint16 feeBps = 100; // 1%
        bytes memory hookData = abi.encode(user, TEST_CODE, feeBps);

        // Expected amounts based on contract logic
        uint256 startingBalance = bridgeRewardsCampaign.balance; // 1 ether
        uint256 expectedFee = (startingBalance * feeBps) / 10000;
        uint256 expectedUser = startingBalance - expectedFee;

        uint256 userBefore = user.balance;
        uint256 builderBefore = builderPayout.balance;

        flywheel.send(bridgeRewardsCampaign, Constants.NATIVE_TOKEN, hookData);

        assertEq(user.balance, userBefore + expectedUser, "User should receive balance minus fee");
        assertEq(builderPayout.balance, builderBefore + expectedFee, "Builder should receive fee");
        assertEq(bridgeRewardsCampaign.balance, 0, "Campaign should be empty");
    }

    function test_withdraw_nativeToken_succeeds() public {
        // Fund campaign with native token
        vm.deal(bridgeRewardsCampaign, 1 ether);

        // Prepare withdrawal hook data
        Flywheel.Payout memory payout = Flywheel.Payout({recipient: user, amount: 1 ether, extraData: ""});
        bytes memory hookData = abi.encode(payout);

        // Execute withdraw; assert balances updated
        uint256 beforeUser = user.balance;
        flywheel.withdrawFunds(bridgeRewardsCampaign, Constants.NATIVE_TOKEN, hookData);
        assertEq(user.balance, beforeUser + 1 ether);
        assertEq(bridgeRewardsCampaign.balance, 0);
    }
}

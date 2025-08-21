// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {Flywheel} from "../src/Flywheel.sol";
import {CampaignHooks} from "../src/CampaignHooks.sol";

/// @notice Test implementation of CampaignHooks for testing the abstract base contract
contract TestCampaignHooks is CampaignHooks {
    constructor(address flywheel_) CampaignHooks(flywheel_) {}

    /// @notice Override onCreateCampaign to make it testable
    function onCreateCampaign(address campaign, bytes calldata hookData) external override onlyFlywheel {
        // Simple implementation for testing
    }
}

/// @notice Test contract for CampaignHooks abstract base contract
contract CampaignHooksTest is Test {
    Flywheel public flywheel;
    TestCampaignHooks public hooks;

    address public flywheelOwner;
    address public campaign;
    address public user;
    address public token;

    function setUp() public {
        flywheelOwner = makeAddr("flywheelOwner");
        campaign = makeAddr("campaign");
        user = makeAddr("user");
        token = makeAddr("token");

        // Deploy flywheel
        vm.prank(flywheelOwner);
        flywheel = new Flywheel();

        // Deploy test hooks contract
        hooks = new TestCampaignHooks(address(flywheel));
    }

    /// @notice Test constructor sets flywheel correctly
    function test_constructor_setsFlywheel() public view {
        assertEq(address(hooks.flywheel()), address(flywheel));
    }

    /// @notice Test onCreateCampaign can be called by flywheel
    function test_onCreateCampaign_calledByFlywheel() public {
        bytes memory hookData = abi.encode(user);

        vm.prank(address(flywheel));
        hooks.onCreateCampaign(campaign, hookData);
        // Should not revert
    }

    /// @notice Test onCreateCampaign reverts when not called by flywheel
    function test_onCreateCampaign_revertsWhenNotFlywheel() public {
        bytes memory hookData = abi.encode(user);

        vm.prank(user);
        vm.expectRevert();
        hooks.onCreateCampaign(campaign, hookData);
    }

    /// @notice Test onUpdateMetadata reverts with Unsupported
    function test_onUpdateMetadata_revertsUnsupported() public {
        bytes memory hookData = abi.encode("metadata");

        vm.prank(address(flywheel));
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onUpdateMetadata(user, campaign, hookData);
    }

    /// @notice Test onUpdateMetadata reverts when not called by flywheel
    function test_onUpdateMetadata_revertsWhenNotFlywheel() public {
        bytes memory hookData = abi.encode("metadata");

        vm.prank(user);
        vm.expectRevert();
        hooks.onUpdateMetadata(user, campaign, hookData);
    }

    /// @notice Test onUpdateStatus reverts with Unsupported
    function test_onUpdateStatus_revertsUnsupported() public {
        bytes memory hookData = "";

        vm.prank(address(flywheel));
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onUpdateStatus(
            user, campaign, Flywheel.CampaignStatus.ACTIVE, Flywheel.CampaignStatus.FINALIZED, hookData
        );
    }

    /// @notice Test onUpdateStatus reverts when not called by flywheel
    function test_onUpdateStatus_revertsWhenNotFlywheel() public {
        bytes memory hookData = "";

        vm.prank(user);
        vm.expectRevert();
        hooks.onUpdateStatus(
            user, campaign, Flywheel.CampaignStatus.ACTIVE, Flywheel.CampaignStatus.FINALIZED, hookData
        );
    }

    /// @notice Test onReward reverts with Unsupported
    function test_onReward_revertsUnsupported() public {
        bytes memory hookData = "";

        vm.prank(address(flywheel));
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onReward(user, campaign, token, hookData);
    }

    /// @notice Test onReward reverts when not called by flywheel
    function test_onReward_revertsWhenNotFlywheel() public {
        bytes memory hookData = "";

        vm.prank(user);
        vm.expectRevert();
        hooks.onReward(user, campaign, token, hookData);
    }

    /// @notice Test onAllocate reverts with Unsupported
    function test_onAllocate_revertsUnsupported() public {
        bytes memory hookData = "";

        vm.prank(address(flywheel));
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onAllocate(user, campaign, token, hookData);
    }

    /// @notice Test onAllocate reverts when not called by flywheel
    function test_onAllocate_revertsWhenNotFlywheel() public {
        bytes memory hookData = "";

        vm.prank(user);
        vm.expectRevert();
        hooks.onAllocate(user, campaign, token, hookData);
    }

    /// @notice Test onDeallocate reverts with Unsupported
    function test_onDeallocate_revertsUnsupported() public {
        bytes memory hookData = "";

        vm.prank(address(flywheel));
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onDeallocate(user, campaign, token, hookData);
    }

    /// @notice Test onDeallocate reverts when not called by flywheel
    function test_onDeallocate_revertsWhenNotFlywheel() public {
        bytes memory hookData = "";

        vm.prank(user);
        vm.expectRevert();
        hooks.onDeallocate(user, campaign, token, hookData);
    }

    /// @notice Test onDistribute reverts with Unsupported
    function test_onDistribute_revertsUnsupported() public {
        bytes memory hookData = "";

        vm.prank(address(flywheel));
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onDistribute(user, campaign, token, hookData);
    }

    /// @notice Test onDistribute reverts when not called by flywheel
    function test_onDistribute_revertsWhenNotFlywheel() public {
        bytes memory hookData = "";

        vm.prank(user);
        vm.expectRevert();
        hooks.onDistribute(user, campaign, token, hookData);
    }

    /// @notice Test onWithdrawFunds reverts with Unsupported
    function test_onWithdrawFunds_revertsUnsupported() public {
        bytes memory hookData = "";
        uint256 amount = 1000;

        vm.prank(address(flywheel));
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onWithdrawFunds(user, campaign, token, user, amount, hookData);
    }

    /// @notice Test onWithdrawFunds reverts when not called by flywheel
    function test_onWithdrawFunds_revertsWhenNotFlywheel() public {
        bytes memory hookData = "";
        uint256 amount = 1000;

        vm.prank(user);
        vm.expectRevert();
        hooks.onWithdrawFunds(user, campaign, token, user, amount, hookData);
    }

    /// @notice Test campaignURI reverts with Unsupported
    function test_campaignURI_revertsUnsupported() public {
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.campaignURI(campaign);
    }

    /// @notice Test onlyFlywheel modifier with different addresses
    function test_onlyFlywheel_modifier() public {
        address notFlywheel = makeAddr("notFlywheel");
        bytes memory hookData = abi.encode(user);

        // Should work with flywheel address
        vm.prank(address(flywheel));
        hooks.onCreateCampaign(campaign, hookData);

        // Should revert with non-flywheel address
        vm.prank(notFlywheel);
        vm.expectRevert();
        hooks.onCreateCampaign(campaign, hookData);

        // Should revert with zero address
        vm.prank(address(0));
        vm.expectRevert();
        hooks.onCreateCampaign(campaign, hookData);
    }

    /// @notice Test constructor with zero address
    function test_constructor_withZeroAddress() public {
        // Should be able to create with zero address (no validation in constructor)
        TestCampaignHooks hooksWithZero = new TestCampaignHooks(address(0));
        assertEq(address(hooksWithZero.flywheel()), address(0));
    }

    /// @notice Test multiple hook function calls in sequence
    function test_multipleHookCalls_sequence() public {
        bytes memory hookData = abi.encode(user);

        vm.startPrank(address(flywheel));

        // onCreateCampaign should work
        hooks.onCreateCampaign(campaign, hookData);

        // All other functions should revert with Unsupported
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onUpdateMetadata(user, campaign, hookData);

        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onUpdateStatus(
            user, campaign, Flywheel.CampaignStatus.ACTIVE, Flywheel.CampaignStatus.FINALIZED, hookData
        );

        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onReward(user, campaign, token, hookData);

        vm.stopPrank();
    }

    /// @notice Test hook functions with empty hook data
    function test_hookFunctions_withEmptyData() public {
        bytes memory emptyData = "";

        vm.startPrank(address(flywheel));

        // onCreateCampaign with empty data should work
        hooks.onCreateCampaign(campaign, emptyData);

        // Other functions should still revert with Unsupported
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onUpdateMetadata(user, campaign, emptyData);

        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onReward(user, campaign, token, emptyData);

        vm.stopPrank();
    }

    /// @notice Test hook functions with malformed hook data
    function test_hookFunctions_withMalformedData() public {
        bytes memory malformedData = abi.encode("malformed", 123, true);

        vm.startPrank(address(flywheel));

        // onCreateCampaign should work even with malformed data
        hooks.onCreateCampaign(campaign, malformedData);

        // Other functions should revert with Unsupported (not because of data)
        vm.expectRevert(CampaignHooks.Unsupported.selector);
        hooks.onUpdateMetadata(user, campaign, malformedData);

        vm.stopPrank();
    }
}

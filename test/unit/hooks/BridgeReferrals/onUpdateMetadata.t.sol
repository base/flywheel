// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {LibString} from "solady/utils/LibString.sol";

import {BridgeReferrals, BridgeReferralsTest} from "../../../lib/BridgeReferralsTest.sol";

contract OnUpdateMetadataTest is BridgeReferralsTest {
    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Accepts metadata update from any sender (no access restrictions)
    /// @param randomCaller Random caller address
    function test_revert_unauthorized(address randomCaller) public {
        vm.assume(randomCaller != address(0));
        vm.assume(randomCaller != bridgeReferrals.METADATA_MANAGER());

        vm.prank(randomCaller);
        vm.expectRevert(BridgeReferrals.Unauthorized.selector);
        flywheel.updateMetadata(bridgeReferralsCampaign, "some metadata");
    }

    function test_success_updatesUriPrefix(string memory newUriPrefix) public {
        vm.assume(bytes(newUriPrefix).length > 0);
        vm.prank(bridgeReferrals.METADATA_MANAGER());
        flywheel.updateMetadata(bridgeReferralsCampaign, bytes(newUriPrefix));
        assertEq(bridgeReferrals.uriPrefix(), newUriPrefix, "Uri prefix should be updated");
        assertEq(
            flywheel.campaignURI(bridgeReferralsCampaign),
            string.concat(newUriPrefix, LibString.toHexStringChecksummed(bridgeReferralsCampaign)),
            "Campaign URI should be updated"
        );
    }

    function test_success_noUriPrefixChange() public {
        string memory oldUriPrefix = bridgeReferrals.uriPrefix();
        vm.prank(bridgeReferrals.METADATA_MANAGER());
        flywheel.updateMetadata(bridgeReferralsCampaign, "");
        assertEq(bridgeReferrals.uriPrefix(), oldUriPrefix, "Uri prefix should not change");
        assertEq(
            flywheel.campaignURI(bridgeReferralsCampaign),
            string.concat(oldUriPrefix, LibString.toHexStringChecksummed(bridgeReferralsCampaign)),
            "Campaign URI should not change"
        );
    }
}

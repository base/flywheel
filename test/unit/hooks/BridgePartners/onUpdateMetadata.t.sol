// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {LibString} from "solady/utils/LibString.sol";

import {BridgePartners, BridgePartnersTest} from "../../../lib/BridgePartnersTest.sol";

contract OnUpdateMetadataTest is BridgePartnersTest {
    // ========================================
    // SUCCESS CASES
    // ========================================

    /// @dev Accepts metadata update from any sender (no access restrictions)
    /// @param randomCaller Random caller address
    function test_revert_unauthorized(address randomCaller) public {
        vm.assume(randomCaller != address(0));
        vm.assume(randomCaller != bridgePartners.METADATA_MANAGER());

        vm.prank(randomCaller);
        vm.expectRevert(BridgePartners.Unauthorized.selector);
        flywheel.updateMetadata(bridgePartnersCampaign, "some metadata");
    }

    function test_success_updatesUriPrefix(string memory newUriPrefix) public {
        vm.assume(bytes(newUriPrefix).length > 0);
        vm.prank(bridgePartners.METADATA_MANAGER());
        flywheel.updateMetadata(bridgePartnersCampaign, bytes(newUriPrefix));
        assertEq(bridgePartners.uriPrefix(), newUriPrefix, "Uri prefix should be updated");
        assertEq(
            flywheel.campaignURI(bridgePartnersCampaign),
            string.concat(newUriPrefix, LibString.toHexStringChecksummed(bridgePartnersCampaign)),
            "Campaign URI should be updated"
        );
    }

    function test_success_noUriPrefixChange() public {
        string memory oldUriPrefix = bridgePartners.uriPrefix();
        vm.prank(bridgePartners.METADATA_MANAGER());
        flywheel.updateMetadata(bridgePartnersCampaign, "");
        assertEq(bridgePartners.uriPrefix(), oldUriPrefix, "Uri prefix should not change");
        assertEq(
            flywheel.campaignURI(bridgePartnersCampaign),
            string.concat(oldUriPrefix, LibString.toHexStringChecksummed(bridgePartnersCampaign)),
            "Campaign URI should not change"
        );
    }
}

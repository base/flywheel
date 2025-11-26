// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeReferralsTest} from "../../../lib/BridgeReferralsTest.sol";

contract ConstructorTest is BridgeReferralsTest {
    /// @dev Sets flywheel address correctly
    function test_setsFlywheel() public {
        assertEq(address(bridgeReferrals.FLYWHEEL()), address(flywheel));
    }

    /// @dev Sets builderCodes address correctly
    function test_setsBuilderCodes() public {
        assertEq(address(bridgeReferrals.BUILDER_CODES()), address(builderCodes));
    }

    /// @dev Sets uriPrefix correctly
    function test_setsUriPrefix() public {
        assertEq(bridgeReferrals.uriPrefix(), CAMPAIGN_URI);
    }

    /// @dev Sets maxFeeBasisPoints correctly
    function test_setsMaxFeeBasisPoints() public {
        assertEq(bridgeReferrals.MAX_FEE_BASIS_POINTS(), MAX_FEE_BASIS_POINTS);
    }

    /// @dev Sets metadataManager correctly
    function test_setsMetadataManager() public {
        assertEq(address(bridgeReferrals.METADATA_MANAGER()), address(owner));
    }
}

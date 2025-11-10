// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgePartnersTest} from "../../../lib/BridgePartnersTest.sol";

contract ConstructorTest is BridgePartnersTest {
    /// @dev Sets flywheel address correctly
    function test_setsFlywheel() public {
        assertEq(address(bridgePartners.FLYWHEEL()), address(flywheel));
    }

    /// @dev Sets builderCodes address correctly
    function test_setsBuilderCodes() public {
        assertEq(address(bridgePartners.BUILDER_CODES()), address(builderCodes));
    }

    /// @dev Sets metadataURI correctly
    function test_setsMetadataURI() public {
        assertEq(bridgePartners.uriPrefix(), CAMPAIGN_URI);
    }

    /// @dev Sets maxFeeBasisPoints correctly
    function test_setsMaxFeeBasisPoints() public {
        assertEq(bridgePartners.MAX_FEE_BASIS_POINTS(), MAX_FEE_BASIS_POINTS);
    }
}

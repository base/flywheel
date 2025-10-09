// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract ConstructorTest is BridgeRewardsTest {
    /// @dev Sets flywheel address correctly
    function test_setsFlywheel() public {
        assertEq(address(bridgeRewards.FLYWHEEL()), address(flywheel));
    }

    /// @dev Sets builderCodes address correctly
    function test_setsBuilderCodes() public {
        assertEq(address(bridgeRewards.BUILDER_CODES()), address(builderCodes));
    }

    /// @dev Sets metadataURI correctly
    function test_setsMetadataURI() public {
        assertEq(bridgeRewards.uriPrefix(), CAMPAIGN_URI);
    }

    /// @dev Sets maxFeeBasisPoints correctly
    function test_setsMaxFeeBasisPoints() public {
        assertEq(bridgeRewards.MAX_FEE_BASIS_POINTS(), MAX_FEE_BASIS_POINTS);
    }
}

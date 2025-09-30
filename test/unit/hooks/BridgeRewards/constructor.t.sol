// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BridgeRewardsTest} from "../../../lib/BridgeRewardsTest.sol";

contract ConstructorTest is BridgeRewardsTest {
    /// @dev Sets flywheel address correctly
    function test_constructor_setsFlywheel() public {}

    /// @dev Sets builderCodes address correctly
    function test_constructor_setsBuilderCodes() public {}

    /// @dev Sets metadataURI correctly
    function test_constructor_setsMetadataURI() public {}

    /// @dev Sets maxFeeBasisPoints correctly
    function test_constructor_setsMaxFeeBasisPoints() public {}
}

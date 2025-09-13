// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesCommon} from "../../common/BuilderCodesCommon.sol";

/// @notice Tests for BuilderCodes.updatePayoutAddress
contract UpdatePayoutAddressTest is BuilderCodesCommon {
    /**
     * updatePayoutAddress reverts
     */
    function test_updatePayoutAddress_revert_invalidCode(address payoutAddress) public {}

    function test_updatePayoutAddress_revert_codeNotRegistered(address payoutAddress) public {}

    function test_updatePayoutAddress_revert_zeroPayoutAddress() public {}

    /**
     * updatePayoutAddress success conditions
     */
    function test_updatePayoutAddress_success_payoutAddressUpdated(address payoutAddress) public {}

    /**
     * updatePayoutAddress event emission
     */
    function test_updatePayoutAddress_success_emitsPayoutAddressUpdated(address payoutAddress) public {}
}

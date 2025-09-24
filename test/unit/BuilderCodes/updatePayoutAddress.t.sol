// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {BuilderCodesTest} from "../../lib/BuilderCodesTest.sol";

/// @notice Unit tests for BuilderCodes.updatePayoutAddress
contract UpdatePayoutAddressTest is BuilderCodesTest {
    /// @notice Test that updatePayoutAddress reverts when called with an invalid code
    ///
    /// @param payoutAddress The payout address to test
    function test_updatePayoutAddress_revert_invalidCode(address payoutAddress) public {}

    /// @notice Test that updatePayoutAddress reverts when the code is not registered
    ///
    /// @param payoutAddress The payout address to test
    function test_updatePayoutAddress_revert_codeNotRegistered(address payoutAddress) public {}

    /// @notice Test that updatePayoutAddress reverts when the payout address is zero address
    function test_updatePayoutAddress_revert_zeroPayoutAddress() public {}

    /// @notice Test that updatePayoutAddress successfully updates the payout address
    ///
    /// @param payoutAddress The payout address to test
    function test_updatePayoutAddress_success_payoutAddressUpdated(address payoutAddress) public {}

    /// @notice Test that updatePayoutAddress allows new owner to update the payout address
    ///
    /// @param payoutAddress The payout address to test
    /// @param newOwner The new owner address
    function test_updatePayoutAddress_success_newOwnerCanUpdate(address payoutAddress, address newOwner) public {}

    /// @notice Test that updatePayoutAddress emits the PayoutAddressUpdated event
    ///
    /// @param payoutAddress The payout address to test
    function test_updatePayoutAddress_success_emitsPayoutAddressUpdated(address payoutAddress) public {}
}

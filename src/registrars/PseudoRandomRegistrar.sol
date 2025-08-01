// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {ReferralCodes} from "../ReferralCodes.sol";

/// @notice Pseudo-random registrar for referral codes
///
/// @dev Generates unique referral codes using a pseudo-random algorithm
///
/// @author Coinbase
contract PseudoRandomRegistrar {
    /// @notice Default length of new permissionless referral codes
    uint256 public constant REF_CODE_LENGTH = 8;

    /// @notice Referral codes contract
    ReferralCodes public immutable codes;

    /// @notice Nonce for generating unique referral codes
    uint256 public nonce;

    /// @notice Constructor for PseudoRandomRegistrar
    ///
    /// @param codes_ Address of the ReferralCodes contract
    constructor(address codes_) {
        codes = ReferralCodes(codes_);
    }

    /// @notice Registers a new referral code in the system
    ///
    /// @param payoutAddress Default payout address for all chains
    function register(address payoutAddress) external returns (string memory code) {
        // Generate unique referral code by looping until we find an unused one
        do {
            code = computeCode(++nonce);
        } while (codes.isRegistered(code));

        codes.register(code, msg.sender, payoutAddress);
    }

    /// @notice Generates a unique code for a referral code
    ///
    /// @param nonceValue Nonce value to generate a code from
    ///
    /// @return code Referral code for the referral code
    function computeCode(uint256 nonceValue) public view returns (string memory code) {
        bytes32 hash = keccak256(abi.encodePacked(nonceValue, block.timestamp));
        bytes memory alphabet = "0123456789abcdefghijklmnopqrstuvwxyz";
        bytes memory codeBytes = new bytes(REF_CODE_LENGTH);

        // Use all 32 bytes of the hash to generate the code
        uint256 hashNum = uint256(hash);
        for (uint256 i; i < REF_CODE_LENGTH; i++) {
            // Use division instead of byte indexing to better distribute values
            codeBytes[i] = alphabet[hashNum % 36];
            hashNum = hashNum / 36;
        }

        return string(codeBytes);
    }
}

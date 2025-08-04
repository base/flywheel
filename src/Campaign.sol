// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Campaign
///
/// @notice Holds funds for a single campaign
///
/// @dev Deployed on demand by protocol via clones
contract Campaign {
    /// @notice Address that created this token store
    address public immutable flywheel;

    /// @notice Call sender is not flywheel
    error OnlyFlywheel();

    /// @notice Constructor
    constructor() {
        flywheel = msg.sender;
    }

    /// @notice Send tokens to a recipient, called by escrow during capture/refund
    ///
    /// @param token The token being received
    /// @param recipient Address to receive the tokens
    /// @param amount Amount of tokens to receive
    ///
    /// @return success True if the transfer was successful
    function sendTokens(address token, address recipient, uint256 amount) external returns (bool) {
        if (msg.sender != flywheel) revert OnlyFlywheel();
        SafeERC20.safeTransfer(IERC20(token), recipient, amount);
        return true;
    }
}

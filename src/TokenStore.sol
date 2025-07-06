// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title TokenStore
///
/// @notice Holds funds for attributions on a single campaign
///
/// @dev Deployed on demand by protocol via CREATE clones
contract TokenStore {
  /// @notice Address that created this token store
  address public immutable owner;

  /// @notice Call sender is not owner
  error OnlyOwner();

  /// @notice Constructor
  constructor() {
    owner = msg.sender;
  }

  /// @notice Send tokens to a recipient, called by escrow during capture/refund
  ///
  /// @param token The token being received
  /// @param recipient Address to receive the tokens
  /// @param amount Amount of tokens to receive
  ///
  /// @return success True if the transfer was successful
  function sendTokens(address token, address recipient, uint256 amount) external returns (bool) {
    if (msg.sender != owner) revert OnlyOwner();
    SafeERC20.safeTransfer(IERC20(token), recipient, amount);
    return true;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Flywheel} from "./Flywheel.sol";
import {Constants} from "./Constants.sol";

/// @title Campaign
///
/// @notice Holds funds for a single campaign
///
/// @dev Deployed on demand by protocol via clones
contract Campaign {
    /// @notice Address that created this token store
    address public immutable FLYWHEEL;

    /// @notice Emitted when the contract URI is updated
    event ContractURIUpdated();

    /// @notice Call sender is not flywheel
    error OnlyFlywheel();

    /// @notice Constructor
    constructor() {
        FLYWHEEL = msg.sender;
    }

    /// @notice Allow receiving native token
    receive() external payable {}

    /// @notice Send tokens to a recipient, called by escrow during capture/refund
    ///
    /// @param token The token being received
    /// @param recipient Address to receive the tokens
    /// @param amount Amount of tokens to receive
    ///
    /// @return success True if the transfer was successful
    function sendTokens(address token, address recipient, uint256 amount) external returns (bool success) {
        if (msg.sender != FLYWHEEL) revert OnlyFlywheel();
        if (token == Constants.NATIVE_TOKEN) {
            (success,) = payable(recipient).call{value: amount}("");
        } else {
            success = SafeERC20.trySafeTransfer(IERC20(token), recipient, amount);
        }
    }

    /// @notice Updates the metadata for the contract
    function updateContractURI() external {
        if (msg.sender != FLYWHEEL) revert OnlyFlywheel();
        emit ContractURIUpdated();
    }

    /// @notice Returns the URI for the contract
    ///
    /// @return uri The URI for the contract
    function contractURI() external view returns (string memory uri) {
        return Flywheel(FLYWHEEL).campaignURI(address(this));
    }
}

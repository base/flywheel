// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

using SafeERC20 for IERC20;

event NativePaymentReceived(address from, uint256 amount);

event AccidentalTokenWithdrawn(address token, address to, uint256 amount);

error OnlyAccidentalToken();
error OnlyParent();
error OnlyAdvertiser();
error TransferFailed();
/// @notice Manages balance and payments for individual advertising campaigns
/// @dev Handles both native crypto and ERC20 token payments

contract CampaignBalance {
  /// @notice Address of the FlywheelCampaigns contract that created this instance
  address public immutable parentAddress;

  /// @notice Unique identifier of the campaign this contract manages
  uint256 public immutable campaignId;

  /// @notice Address of the payment token (address(0) for native crypto)
  address public immutable tokenAddress;

  address public immutable advertiserAddress;

  /// @notice Creates a new CampaignBalance instance
  /// @param _campaignId Unique identifier for the campaign
  /// @param _tokenAddress Address of payment token (address(0) for native crypto)
  /// owner in this case is the FlywheelCampaigns contract that will never change
  constructor(uint256 _campaignId, address _tokenAddress, address _advertiserAddress) {
    campaignId = _campaignId;
    tokenAddress = _tokenAddress;
    parentAddress = msg.sender;
    advertiserAddress = _advertiserAddress;
  }

  modifier onlyParent() {
    if (msg.sender != parentAddress) {
      revert OnlyParent();
    }
    _;
  }

  modifier onlyAdvertiser() {
    if (msg.sender != advertiserAddress) {
      revert OnlyAdvertiser();
    }
    _;
  }

  /// @notice Gets the current balance of the campaign
  /// @return Current balance in payment token or native crypto
  function getBalance() external view returns (uint256) {
    if (tokenAddress == address(0)) {
      return address(this).balance;
    }
    return IERC20(tokenAddress).balanceOf(address(this));
  }

  /// @notice Claims rewards for a recipient
  /// @param _amount Amount to claim
  /// @param _to Address to receive the rewards
  /// @dev Can only be called by the owner (FlywheelCampaigns contract)
  function sendPayment(uint256 _amount, address _to) external onlyParent {
    if (tokenAddress == address(0)) {
      (bool success, ) = _to.call{ value: _amount }("");
      if (!success) {
        revert TransferFailed();
      }
    } else {
      IERC20(tokenAddress).safeTransfer(_to, _amount);
    }
  }

  /// @notice Fallback function to receive native crypto
  /// @dev This is the fallback function for receiving ETH payments in case someone accidentally adds calldata to the transaction
  fallback() external payable {
    emit NativePaymentReceived(msg.sender, msg.value);
  }

  /// @notice Receive function to accept native crypto payments
  /// @dev This is the standard way to receive ETH payments for CampaignBalance
  receive() external payable {
    emit NativePaymentReceived(msg.sender, msg.value);
  }

  /// @notice Withdraws accidentally sent tokens that aren't the campaign's payment token
  /// @param _token Address of token to withdraw (or address(0) for native crypto)
  /// @param _to Address to send the tokens to
  /// @dev Can only be called by parent contract
  function withdrawAccidentalTokens(address _token, address _to) external onlyAdvertiser {
    // revert if trying to withdraw the campaign's payment token
    if (_token == tokenAddress) {
      revert OnlyAccidentalToken();
    }

    if (_token == address(0)) {
      uint256 amount = address(this).balance;
      if (amount != 0) {
        (bool success, ) = _to.call{ value: amount }("");
        if (!success) {
          revert TransferFailed();
        }
        emit AccidentalTokenWithdrawn(_token, _to, amount);
      }
    } else {
      uint256 amount = IERC20(_token).balanceOf(address(this));
      if (amount != 0) {
        IERC20(_token).safeTransfer(_to, amount);
        emit AccidentalTokenWithdrawn(_token, _to, amount);
      }
    }
  }
}

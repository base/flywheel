pragma solidity 0.8.29;

import "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";

import { CampaignBalance, NativePaymentReceived, OnlyAccidentalToken, AccidentalTokenWithdrawn, OnlyParent, OnlyAdvertiser, TransferFailed } from "../../src/archive/CampaignBalance.sol";
import { DummyERC20 } from "../../src/archive/test/DummyERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// Helper contract that rejects ETH transfers to test TransferFailed cases
contract RejectETH {
  // This contract will revert on receive/fallback to simulate failed ETH transfers
  receive() external payable {
    revert("ETH rejected");
  }

  fallback() external payable {
    revert("ETH rejected");
  }
}

contract CampaignBalanceTest is Test {
  CampaignBalance campaignBalance;
  DummyERC20 dummyToken;
  RejectETH rejectETH;
  uint256 campaignId = 1;

  address private owner = address(this);
  address private treasury = address(0x3);
  address private manager = address(0x4);
  address private advertiser = address(0x5);

  function setUp() public {
    vm.startPrank(owner);
    address[] memory initialHolders = new address[](2);
    initialHolders[0] = owner;
    initialHolders[1] = advertiser;
    dummyToken = new DummyERC20(initialHolders);
    rejectETH = new RejectETH();

    vm.stopPrank();
  }

  // Utility function to create and fund a campaign
  function test_addERC20FundsAndClaimRewards() public {
    vm.startPrank(owner);
    campaignBalance = new CampaignBalance(campaignId, address(dummyToken), advertiser);

    address toAddress = address(0x334433);

    uint256 fundAmount = 5 * 10 ** 18; // 5 tokens
    uint256 claimAmount = 3 * 10 ** 18; // 3 tokens
    uint16 protocolFee = 0; // 1 token

    // transfer ERC20 funds to the campaign balance
    dummyToken.transfer(address(campaignBalance), fundAmount);

    // claim rewards of 3 tokens
    campaignBalance.sendPayment(claimAmount, toAddress);

    // check the manager balance
    uint256 toAddressBalance = dummyToken.balanceOf(toAddress);
    assertEq(toAddressBalance, claimAmount, "Manager should have 3 tokens");

    uint256 campaignBalanceBalance = dummyToken.balanceOf(address(campaignBalance));
    assertEq(campaignBalanceBalance, fundAmount - claimAmount, "Campaign balance should have 2 tokens");

    // getBalance should also be 2 tokens
    uint256 campaignBalanceBalance2 = campaignBalance.getBalance();
    assertEq(campaignBalanceBalance2, fundAmount - claimAmount, "Campaign balance should have 2 tokens");

    vm.stopPrank();
  }

  // Utility function to create and fund a campaign
  function test_addNativeEthFundsAndClaimRewards() public {
    address nativeEth = address(0);
    vm.startPrank(owner);
    campaignBalance = new CampaignBalance(campaignId, nativeEth, advertiser);

    address toAddress = address(0x334433);

    uint256 fundAmount = 5 * 10 ** 18; // 5 eth
    uint256 claimAmount = 3 * 10 ** 18; // 3 eth
    uint16 protocolFee = 0;

    // fund native ether
    vm.deal(address(campaignBalance), fundAmount);

    // claim rewards of 3 tokens
    campaignBalance.sendPayment(claimAmount, toAddress);

    // check the manager balance
    uint256 toAddressBalance = address(toAddress).balance;
    assertEq(toAddressBalance, claimAmount, "Manager should have 3 eth");

    uint256 campaignBalanceBalance = address(campaignBalance).balance;
    assertEq(campaignBalanceBalance, fundAmount - claimAmount, "Campaign balance should have 2 eth");

    uint256 campaignBalanceBalance2 = campaignBalance.getBalance();
    assertEq(campaignBalanceBalance2, fundAmount - claimAmount, "Campaign balance should have 2 eth");

    vm.stopPrank();
  }

  // send native payment to the campaign balance & check that the event is emitted
  function test_sendNativePaymentToCampaignBalance() public {
    vm.startPrank(owner);
    campaignBalance = new CampaignBalance(campaignId, address(0), advertiser);

    // Fund the sender first
    vm.deal(owner, 1.25 ether);

    // Get initial balance
    uint256 initialBalance = address(campaignBalance).balance;

    vm.expectEmit(true, true, false, true);
    emit NativePaymentReceived(owner, 1.25 ether);

    // Actually send ETH to trigger the receive/fallback function
    (bool success, ) = address(campaignBalance).call{ value: 1.25 ether }("");
    require(success, "ETH transfer failed");

    // Verify the balance increased
    assertEq(address(campaignBalance).balance, initialBalance + 1.25 ether, "Balance should increase");

    vm.stopPrank();
  }

  // Test fallback function with calldata
  function test_fallbackFunctionWithCalldata() public {
    vm.startPrank(owner);
    campaignBalance = new CampaignBalance(campaignId, address(0), advertiser);

    // Fund the sender first
    vm.deal(owner, 1 ether);

    // Get initial balance
    uint256 initialBalance = address(campaignBalance).balance;

    vm.expectEmit(true, true, false, true);
    emit NativePaymentReceived(owner, 1 ether);

    // Send ETH with calldata to trigger fallback function
    (bool success, ) = address(campaignBalance).call{ value: 1 ether }("0x1234");
    require(success, "ETH transfer failed");

    // Verify the balance increased
    assertEq(address(campaignBalance).balance, initialBalance + 1 ether, "Balance should increase");

    vm.stopPrank();
  }

  // Test sendPayment failure when ETH transfer fails
  function test_sendPayment_TransferFailed() public {
    vm.startPrank(owner);
    campaignBalance = new CampaignBalance(campaignId, address(0), advertiser);

    // Fund the campaign with ETH
    vm.deal(address(campaignBalance), 1 ether);

    // Try to send payment to a contract that rejects ETH
    vm.expectRevert(TransferFailed.selector);
    campaignBalance.sendPayment(0.5 ether, address(rejectETH));

    vm.stopPrank();
  }

  // Test withdrawAccidentalTokens failure when ETH transfer fails
  function test_withdrawAccidentalTokens_TransferFailed() public {
    vm.startPrank(owner);
    // Create campaign with ERC20 token so we can withdraw ETH as "accidental"
    campaignBalance = new CampaignBalance(campaignId, address(dummyToken), advertiser);

    // Fund with ETH (accidental since campaign uses ERC20)
    vm.deal(address(campaignBalance), 1 ether);
    vm.stopPrank();

    // Try to withdraw as advertiser to a contract that rejects ETH
    vm.startPrank(advertiser);
    vm.expectRevert(TransferFailed.selector);
    campaignBalance.withdrawAccidentalTokens(address(0), address(rejectETH));
    vm.stopPrank();
  }

  // Test that advertiser cannot withdraw campaign's token
  function test_cannotWithdrawCampaignToken() public {
    vm.startPrank(owner);
    campaignBalance = new CampaignBalance(campaignId, address(dummyToken), advertiser);

    // Fund the campaign
    dummyToken.transfer(address(campaignBalance), 5 * 10 ** 18);
    vm.stopPrank();

    // Try to withdraw as advertiser
    vm.startPrank(advertiser);
    vm.expectRevert(OnlyAccidentalToken.selector);
    campaignBalance.withdrawAccidentalTokens(address(dummyToken), advertiser);
    vm.stopPrank();
  }

  // Test successful withdrawal of native ETH by advertiser
  function test_withdrawNativeEth() public {
    address nativeEth = address(0);
    vm.startPrank(owner);
    campaignBalance = new CampaignBalance(campaignId, address(dummyToken), advertiser);

    // Fund with ETH
    vm.deal(address(campaignBalance), 2 ether);
    vm.stopPrank();

    // Withdraw as advertiser
    vm.startPrank(advertiser);
    uint256 balanceBefore = advertiser.balance;

    // Check all parameters of the event (token, to, amount)
    vm.expectEmit(true, true, true, true);
    emit AccidentalTokenWithdrawn(nativeEth, advertiser, 2 ether);

    campaignBalance.withdrawAccidentalTokens(nativeEth, advertiser);

    assertEq(advertiser.balance - balanceBefore, 2 ether, "Should receive 2 ETH");
    assertEq(address(campaignBalance).balance, 0, "Campaign should have 0 ETH");
    vm.stopPrank();
  }

  // Test successful withdrawal of accidental ERC20 token
  function test_withdrawAccidentalERC20() public {
    // First create the campaign
    vm.startPrank(owner);
    campaignBalance = new CampaignBalance(campaignId, address(dummyToken), advertiser);

    // Then create a different token than the campaign token
    address[] memory holders = new address[](1);
    holders[0] = owner;
    DummyERC20 accidentalToken = new DummyERC20(holders);

    // Send accidental tokens to campaign
    uint256 accidentalAmount = 5 * 10 ** 18;
    accidentalToken.transfer(address(campaignBalance), accidentalAmount);
    vm.stopPrank();

    // Withdraw as advertiser
    vm.startPrank(advertiser);

    vm.expectEmit(true, true, false, true);
    emit AccidentalTokenWithdrawn(address(accidentalToken), advertiser, accidentalAmount);

    campaignBalance.withdrawAccidentalTokens(address(accidentalToken), advertiser);

    assertEq(accidentalToken.balanceOf(advertiser), accidentalAmount, "Should receive accidental tokens");
    assertEq(accidentalToken.balanceOf(address(campaignBalance)), 0, "Campaign should have 0 accidental tokens");
    vm.stopPrank();
  }

  // Test that non-advertiser cannot withdraw
  function test_nonAdvertiserCannotWithdraw() public {
    vm.startPrank(owner);
    campaignBalance = new CampaignBalance(campaignId, address(dummyToken), advertiser);

    // Fund with ETH
    vm.deal(address(campaignBalance), 1 ether);
    vm.stopPrank();

    // Try to withdraw as non-advertiser
    vm.startPrank(address(0x1234));
    vm.expectRevert(OnlyAdvertiser.selector);
    campaignBalance.withdrawAccidentalTokens(address(0), address(0x1234));
    vm.stopPrank();
  }

  // Test that non-parent cannot call sendPayment
  function test_nonParentCannotSendPayment() public {
    vm.startPrank(owner);
    campaignBalance = new CampaignBalance(campaignId, address(dummyToken), advertiser);

    // Fund the campaign
    dummyToken.transfer(address(campaignBalance), 5 * 10 ** 18);
    vm.stopPrank();

    // Try to call sendPayment as non-parent address
    vm.startPrank(address(0x1234));
    vm.expectRevert(OnlyParent.selector);
    campaignBalance.sendPayment(1 * 10 ** 18, address(0x5678));
    vm.stopPrank();
  }
}

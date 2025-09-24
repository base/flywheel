// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

contract MockAccount {
    bool public acceptNativeToken;

    constructor(bool acceptNativeToken_) {
        acceptNativeToken = acceptNativeToken_;
    }

    receive() external payable {
        if (!acceptNativeToken) revert("Native token not accepted");
    }

    function setAcceptNativeToken(bool acceptNativeToken_) external {
        acceptNativeToken = acceptNativeToken_;
    }
}

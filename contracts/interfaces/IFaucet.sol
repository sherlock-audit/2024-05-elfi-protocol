// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IFaucet {

    struct RequestTokensParam {
        address account;
        address[] mockTokens;
        uint256[] mintAmounts;
        uint256 ethAmount;
    }

    function requestTokens(RequestTokensParam calldata param) external payable;
    
}

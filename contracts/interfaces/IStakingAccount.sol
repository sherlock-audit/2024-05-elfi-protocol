// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IStakingAccount {
    struct TokenBalance {
        uint256 stakeAmount;
        address[] collateralTokens;
        uint256[] collateralAmounts;
        uint256[] collateralStakeLiability;
    }

    function getAccountPoolBalance(address account, address stakeToken) external view returns (TokenBalance memory);

    function getAccountPoolCollateralAmount(
        address account,
        address stakeToken,
        address collateral
    ) external view returns (uint256);

    function getAccountUsdPoolAmount(address account) external view returns (uint256);
}

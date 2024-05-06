// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IStakingAccount.sol";
import "../storage/StakingAccount.sol";
import "../storage/CommonData.sol";

contract StakingAccountFacet is IStakingAccount {
    using StakingAccount for StakingAccount.Props;

    function getAccountPoolBalance(
        address account,
        address stakeToken
    ) external view override returns (TokenBalance memory) {
        StakingAccount.Props storage stakingAccount = StakingAccount.load(account);
        address[] memory tokens = stakingAccount.getCollateralTokens(stakeToken);
        uint256[] memory amounts = new uint256[](tokens.length);
        uint256[] memory liabilities = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            StakingAccount.CollateralData memory data = stakingAccount.getCollateralToken(stakeToken, tokens[i]);
            amounts[i] = data.amount;
            liabilities[i] = data.stakeLiability;
        }

        return TokenBalance(stakingAccount.stakeTokenBalances[stakeToken].stakeAmount, tokens, amounts, liabilities);
    }

    function getAccountPoolCollateralAmount(
        address account,
        address stakeToken,
        address collateral
    ) external view override returns (uint256) {
        return StakingAccount.load(account).getCollateralToken(stakeToken, collateral).amount;
    }

    function getAccountUsdPoolAmount(address account) external view override returns (uint256) {
        return StakingAccount.load(account).stakeUsdAmount;
    }
}

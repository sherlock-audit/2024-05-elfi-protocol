// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/ISwap.sol";
import "../interfaces/IVault.sol";
import "../process/SwapProcess.sol";
import "../process/AssetsProcess.sol";
import "../storage/RoleAccessControl.sol";
import "../utils/Errors.sol";

contract SwapFacet is ISwap {
    using SafeCast for uint256;
    using Account for Account.Props;

    function swapPortfolioToPayLiability(
        address[] calldata accounts,
        address[][] calldata accountTokens,
        OracleProcess.OracleParam[] calldata oracles
    ) external override {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        OracleProcess.setOraclePrice(oracles);
        for (uint256 i; i < accounts.length; i++) {
            Account.Props storage accountProps = Account.load(accounts[i]);
            accountProps.checkExists();
            for (uint256 j; j < accountTokens[i].length; j++) {
                _swapSingleLiability(accountProps, accountTokens[i][j]);
            }
        }
        OracleProcess.clearOraclePrice();
    }

    function _swapSingleLiability(
        Account.Props storage accountProps,
        address token
    ) internal returns (SwapResult memory) {
        uint256 liability = accountProps.getTokenBalance(token).liability;
        if (liability <= 0) {
            revert Errors.IgnoreSwapWithAccountLiabilityZero();
        }
        address[] memory tokens = accountProps.getSortedTokensByDiscount();
        uint256[] memory amounts = new uint256[](tokens.length);
        uint256[] memory minToAmounts = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            amounts[i] = accountProps.getAvailableTokenAmount(tokens[i]);
            if (amounts[i] == 0) {
                continue;
            }
            uint256 toTokenAmount = CalUtils.tokenToToken(
                amounts[i],
                TokenUtils.decimals(tokens[i]),
                TokenUtils.decimals(token),
                OracleProcess.getLatestUsdUintPrice(tokens[i], true),
                OracleProcess.getLatestUsdUintPrice(token, false)
            );
            toTokenAmount -= CalUtils.mulRate(toTokenAmount, AppTradeConfig.getTradeConfig().swapSlipperTokenFactor);
            minToAmounts[i] = toTokenAmount;
        }
        address portfolioVaultAddress = IVault(address(this)).getPortfolioVaultAddress();
        return
            _swapUserTokens(
                accountProps.owner,
                SwapParams(
                    portfolioVaultAddress,
                    tokens,
                    amounts,
                    minToAmounts,
                    token,
                    portfolioVaultAddress,
                    liability
                )
            );
    }

    function _swapUserTokens(address account, SwapParams memory params) internal returns (SwapResult memory) {
        SwapResult memory swapResult = SwapProcess.swap(params);
        AssetsProcess.UpdateAccountTokenParams memory updateAccountParams;
        updateAccountParams.account = account;
        updateAccountParams.tokens = new address[](swapResult.fromTokens.length + 1);
        updateAccountParams.changedTokenAmounts = new int256[](swapResult.fromTokens.length + 1);
        for (uint256 i; i < swapResult.fromTokens.length; i++) {
            updateAccountParams.tokens[i] = swapResult.fromTokens[i];
            updateAccountParams.changedTokenAmounts[i] = -(swapResult.reduceFromAmounts[i].toInt256());
        }
        updateAccountParams.tokens[swapResult.fromTokens.length] = swapResult.toToken;
        updateAccountParams.changedTokenAmounts[swapResult.fromTokens.length] = swapResult.toTokenAmount.toInt256();
        AssetsProcess.updateAccountToken(updateAccountParams);
        return swapResult;
    }
}

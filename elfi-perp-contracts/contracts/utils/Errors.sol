// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library Errors {
    // common
    error AmountNotMatch(uint256 amount1, uint256 amount2);
    error AmountZeroNotAllowed();
    error PriceIsZero();
    error UnknownError(bytes msg);
    error ExecutionFeeNotEnough();
    error BlockNumberInvalid();
    error MarginModeError();

    // transfer
    error BalanceNotEnough(address account, address token);
    error WithdrawWithNoEnoughAmount();
    error WithdrawRequestNotExists();
    error WithdrawNotAllowed();
    error TransferErrorWithVaultBalanceNotEnough(address vault, address token, address receiver, uint256 amount);
    error IgnoreSwapWithAccountLiabilityZero();

    // market
    error CreateSymbolExists(bytes32 code);
    error CreateStakePoolExists(address stakeToken);
    error SymbolNotExists();
    error SymbolStatusInvalid(bytes32 symbol);
    error StakeTokenInvalid(address stakeToken);
    error PoolNotExists();
    error PoolValueLessThanZero();
    error PoolAmountNotEnough(address stakeToken, address token);
    error PoolUnsettledAmountInvalid();

    // tokens
    error TokenIsNotSupport();
    error TokenIsNotSupportCollateral();
    error OnlyCollateralSupported();
    error OnlyIsolateSupported();
    error OnlyCrossSupported();
    error CollateralUserCapOverflow(address token, uint256 cap);
    error CollateralTotalCapOverflow(address token, uint256 cap);

    // account
    error AccountNotExist();
    error NoNeedToPayLiability();

    // mint
    error MintRequestNotExists();
    error MintTokenInvalid(address stakeToken, address mintToken);
    error MintFailedWithBalanceNotEnough(address account, address baseToken);
    error MintStakeTokenTooSmall(uint256 minStakeAmount, uint256 realStakeAmount);
    error MintWithAmountZero();
    error PoolValueIsZero();
    error MintWithParamError();
    error MintCollateralNotSupport();
    error MintCollateralOverflow();
    error MintCollateralFailedWithPriceCloseToDiscount();

    // redeem
    error RedeemRequestNotExists();
    error RedeemTokenInvalid(address stakeToken, address mintToken);
    error RedeemCollateralNotSupport();
    error RedeemWithAmountEmpty(address account, address stakeToken);
    error RedeemWithAmountNotEnough(address account, address stakeToken);
    error RedeemStakeTokenTooSmall(uint256 redeemAmount);
    error RedeemReduceStakeTokenTooSmall();
    error RedeemWithVaultBalanceNotEnough(address vaultAddr, uint256 amount);

    // orders
    error OrderNotExists(uint256 orderId);
    error LeverageInvalid(bytes32 symbol, uint256 leverage);
    error OrderMarginTooSmall();
    error ReducePositionTooSmall(bytes32 symbol, address account);
    error DecreasePositionNotExists(bytes32 symbol, address account, address marginToken);
    error DecreaseQtyTooBig(bytes32 symbol, address account);
    error DecreaseOrderSideInvalid();
    error TokenInvalid(bytes32 symbol, address token);
    error PlaceOrderWithParamsError();
    error ExecutionFeeLessThanConfigGasFeeLimit();
    error ExecutionPriceInvalid();
    error ChangeCrossModeError(address account);
    error CancelOrderWithLiquidation(bytes32 symbol, address account);
    error OnlyDecreaseOrderSupported();

    // positions
    error PositionTooBig(bytes32 symbol, address account);
    error OnlyOneShortPositionSupport(bytes32 symbol);
    error MaxOILimited(bytes32 symbol, bool isLong);
    error OIRatioLimited();
    error PositionNotExists();
    error UpdatePositionMarginRequestNotExists();
    error AddMarginTooBig();
    error ReduceMarginTooBig();
    error PositionShouldBeLiquidation();
    error UpdateLeverageRequestNotExists();
    error UpdateLeverageWithNoChange();
    error UpdateLeverageError(
        address account,
        bytes32 symbol,
        bool isLong,
        uint256 existsLeverage,
        uint256 newLeverage
    );

    // liquidation
    error LiquidationIgnored(address account);
    error LiquidationErrorWithBankruptcyPriceZero(bytes32 positionKey, int256 bankruptcyMR);
    error CallLiabilityCleanNotExists(uint256 id);

    // fee
    error ClaimRewardsRequestNotExists();
    error ClaimTokenNotSupported();
}

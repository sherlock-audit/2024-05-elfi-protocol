// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../storage/Symbol.sol";
import "../storage/LpPool.sol";
import "../storage/Market.sol";
import "../storage/CommonData.sol";
import "../utils/Errors.sol";
import "../vault/StakeToken.sol";

library MarketFactoryProcess {
    using Market for Market.Props;

    event MarketCreated(bytes32 code, string stakeTokenName, address indexToken, address baseToken, address stakeToken);

    event PoolCreated(string name, address stakeToken);

    event MarketOIUpdateEvent(bytes32 symbol, bool isLong, uint256 openInterest);

    struct CreateMarketParams {
        bytes32 code;
        string stakeTokenName;
        address indexToken;
        address baseToken;
    }

    function createMarket(CreateMarketParams memory params) external returns (address stakeTokenAddr) {
        Symbol.Props storage symbolProps = Symbol.create(params.code);
        if (symbolProps.indexToken != address(0)) {
            revert Errors.CreateSymbolExists(params.code);
        }
        symbolProps.indexToken = params.indexToken;
        symbolProps.baseToken = params.baseToken;
        symbolProps.status = Symbol.Status.OPEN;
        ERC20 baseTokenERC20 = ERC20(params.baseToken);
        bytes32 stakeTokenSalt = keccak256(abi.encode("STAKE_TOKEN", params.stakeTokenName));
        StakeToken stakeToken = new StakeToken{ salt: stakeTokenSalt }(
            params.stakeTokenName,
            baseTokenERC20.decimals(),
            address(this)
        );
        stakeTokenAddr = address(stakeToken);
        symbolProps.stakeToken = stakeTokenAddr;

        LpPool.Props storage pool = LpPool.load(stakeTokenAddr);
        if (pool.stakeToken != address(0)) {
            revert Errors.CreateStakePoolExists(stakeTokenAddr);
        }
        pool.stakeToken = stakeTokenAddr;
        pool.stakeTokenName = params.stakeTokenName;
        pool.baseToken = params.baseToken;
        pool.symbol = params.code;
        CommonData.addSymbol(params.code);
        CommonData.addStakeTokens(stakeTokenAddr);

        Market.Props storage marketProps = Market.load(params.code);
        marketProps.symbol = params.code;
        marketProps.stakeToken = stakeTokenAddr;

        emit MarketCreated(params.code, params.stakeTokenName, params.indexToken, params.baseToken, stakeTokenAddr);
    }

    function createStakeUsdPool(
        string memory stakeTokenName,
        uint8 decimals
    ) external returns (address stakeTokenAddr) {
        if (CommonData.getStakeUsdToken() != address(0)) {
            revert Errors.CreateStakePoolExists(CommonData.getStakeUsdToken());
        }
        bytes32 stakeTokenSalt = keccak256(abi.encode("STAKE_USD_TOKEN", stakeTokenName));
        StakeToken stakeToken = new StakeToken{ salt: stakeTokenSalt }(stakeTokenName, decimals, address(this));
        stakeTokenAddr = address(stakeToken);

        LpPool.Props storage pool = LpPool.load(stakeTokenAddr);
        pool.stakeToken = stakeTokenAddr;

        CommonData.setStakeUsdToken(stakeTokenAddr);
        emit PoolCreated(stakeTokenName, stakeTokenAddr);
    }
}

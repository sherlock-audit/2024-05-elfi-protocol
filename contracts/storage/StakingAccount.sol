// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./LpPool.sol";

library StakingAccount {
    using EnumerableSet for EnumerableSet.AddressSet;
    using LpPool for LpPool.Props;

    struct Props {
        address owner;
        EnumerableSet.AddressSet stakeTokens;
        mapping(address => Balance) stakeTokenBalances;
        mapping(address => FeeRewards) feeRewards;
        uint256 stakeUsdAmount;
    }

    struct FeeRewards {
        uint256 realisedRewardsTokenAmount;
        uint256 openRewardsPerStakeToken;
    }

    struct Balance {
        uint256 stakeAmount;
        EnumerableSet.AddressSet collateralTokens;
        mapping(address => CollateralData) collateralDatas;
    }

    struct CollateralData {
        uint256 amount;
        uint256 stakeLiability;
    }

    event StakingAccountCollateralUpdateEvent(
        address account,
        address stakeToken,
        address collateral,
        uint256 preAmount,
        uint256 preLiability,
        uint256 amount,
        uint256 liability
    );

    event StakingAccountFeeRewardsUpdateEvent(
        address account,
        address stakeToken,
        uint256 realisedRewardsTokenAmount,
        uint256 openRewardsPerStakeToken
    );

    function load(address owner) public pure returns (Props storage self) {
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.StakingAccount", owner));
        assembly {
            self.slot := s
        }
    }

    function loadOrCreate(address owner) public returns (Props storage self) {
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.StakingAccount", owner));
        assembly {
            self.slot := s
        }
        if (self.owner == address(0)) {
            self.owner = owner;
        }
    }

    function addStakeAmount(Props storage self, address stakeToken, uint256 amount) external {
        if (self.stakeTokens.contains(stakeToken)) {
            self.stakeTokenBalances[stakeToken].stakeAmount = self.stakeTokenBalances[stakeToken].stakeAmount + amount;
        } else {
            self.stakeTokens.add(stakeToken);
            self.stakeTokenBalances[stakeToken].stakeAmount = amount;
        }
    }

    function subStakeAmount(Props storage self, address stakeToken, uint256 amount) external {
        require(self.stakeTokenBalances[stakeToken].stakeAmount >= amount, "token amount not enough");
        self.stakeTokenBalances[stakeToken].stakeAmount = self.stakeTokenBalances[stakeToken].stakeAmount - amount;
    }

    function addStakeLiability(
        Props storage self,
        address stakeToken,
        address collateralToken,
        uint256 liability
    ) external {
        if (!self.stakeTokens.contains(stakeToken)) {
            self.stakeTokens.add(stakeToken);
        }
        if (!self.stakeTokenBalances[stakeToken].collateralTokens.contains(collateralToken)) {
            self.stakeTokenBalances[stakeToken].collateralTokens.add(collateralToken);
        }
        CollateralData storage data = self.stakeTokenBalances[stakeToken].collateralDatas[collateralToken];
        uint256 preLiability = data.stakeLiability;
        data.stakeLiability += liability;
        emit StakingAccountCollateralUpdateEvent(
            self.owner,
            stakeToken,
            collateralToken,
            data.amount,
            preLiability,
            data.amount,
            data.stakeLiability
        );
    }

    function subStakeLiability(
        Props storage self,
        address stakeToken,
        address collateralToken,
        uint256 liability
    ) external {
        require(
            self.stakeTokens.contains(stakeToken) &&
                self.stakeTokenBalances[stakeToken].collateralTokens.contains(collateralToken),
            "stake liability not enough"
        );
        require(
            self.stakeTokenBalances[stakeToken].collateralDatas[collateralToken].stakeLiability >= liability,
            "stake liability not enough"
        );
        CollateralData storage data = self.stakeTokenBalances[stakeToken].collateralDatas[collateralToken];
        uint256 preLiability = data.stakeLiability;
        data.stakeLiability -= liability;
        emit StakingAccountCollateralUpdateEvent(
            self.owner,
            stakeToken,
            collateralToken,
            data.amount,
            preLiability,
            data.amount,
            data.stakeLiability
        );
    }

    function addCollateralToken(
        Props storage self,
        address stakeToken,
        address collateralToken,
        uint256 amount
    ) external {
        if (!self.stakeTokens.contains(stakeToken)) {
            self.stakeTokens.add(stakeToken);
        }
        if (!self.stakeTokenBalances[stakeToken].collateralTokens.contains(collateralToken)) {
            self.stakeTokenBalances[stakeToken].collateralTokens.add(collateralToken);
        }
        CollateralData storage data = self.stakeTokenBalances[stakeToken].collateralDatas[collateralToken];
        uint256 preAmount = data.amount;
        data.amount += amount;
        emit StakingAccountCollateralUpdateEvent(
            self.owner,
            stakeToken,
            collateralToken,
            preAmount,
            data.stakeLiability,
            data.amount,
            data.stakeLiability
        );
    }

    function subCollateralToken(
        Props storage self,
        address stakeToken,
        address collateralToken,
        uint256 amount
    ) external {
        require(
            self.stakeTokens.contains(stakeToken) &&
                self.stakeTokenBalances[stakeToken].collateralTokens.contains(collateralToken),
            "stake amount not enough"
        );
        require(
            self.stakeTokenBalances[stakeToken].collateralDatas[collateralToken].amount >= amount,
            "stake amount not enough"
        );
        CollateralData storage data = self.stakeTokenBalances[stakeToken].collateralDatas[collateralToken];
        uint256 preAmount = data.amount;
        data.amount -= amount;
        emit StakingAccountCollateralUpdateEvent(
            self.owner,
            stakeToken,
            collateralToken,
            preAmount,
            data.stakeLiability,
            data.amount,
            data.stakeLiability
        );
    }

    function hasCollateralToken(Props storage self, address stakeToken) external view returns (bool) {
        if (!self.stakeTokens.contains(stakeToken)) {
            return false;
        }
        address[] memory tokens = self.stakeTokenBalances[stakeToken].collateralTokens.values();
        uint256 totalAmount = 0;
        for (uint256 i; i < tokens.length; i++) {
            totalAmount += self.stakeTokenBalances[stakeToken].collateralDatas[tokens[i]].amount;
        }
        return totalAmount > 0;
    }

    function getCollateralTokens(Props storage self, address stakeToken) external view returns (address[] memory) {
        return self.stakeTokenBalances[stakeToken].collateralTokens.values();
    }

    function getCollateralToken(
        Props storage self,
        address stakeToken,
        address collateralToken
    ) external view returns (CollateralData memory) {
        return self.stakeTokenBalances[stakeToken].collateralDatas[collateralToken];
    }

    function addStakeUsdAmount(Props storage self, uint256 amount) external {
        self.stakeUsdAmount = self.stakeUsdAmount + amount;
    }

    function subStakeUsdAmount(Props storage self, uint256 amount) external {
        require(self.stakeUsdAmount >= amount, "usd token amount not enough");
        self.stakeUsdAmount = self.stakeUsdAmount - amount;
    }

    function emitFeeRewardsUpdateEvent(Props storage self, address stakeToken) external {
        emit StakingAccountFeeRewardsUpdateEvent(
            self.owner,
            stakeToken,
            self.feeRewards[stakeToken].realisedRewardsTokenAmount,
            self.feeRewards[stakeToken].openRewardsPerStakeToken
        );
    }

    function getStakeTokens(Props storage self) external view returns (address[] memory) {
        return self.stakeTokens.values();
    }

    function getFeeRewards(Props storage self, address stakeToken) external view returns (FeeRewards storage) {
        return self.feeRewards[stakeToken];
    }
}

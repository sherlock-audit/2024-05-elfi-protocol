// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library InsuranceFund {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using SafeMath for uint256;

    struct Props {
        EnumerableMap.AddressToUintMap funds;
    }

    event FundsUpdateEvent(address stakeToken, address token, uint256 preAmount, uint256 amount);

    function load(address stakeToken) public pure returns (Props storage self) {
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.InsuranceFund", stakeToken));
        assembly {
            self.slot := s
        }
    }

    function addFunds(address stakeToken, address token, uint256 amount) public {
        InsuranceFund.Props storage self = load(stakeToken);
        (bool exists, uint256 preAmount) = self.funds.tryGet(token);
        if (exists) {
            self.funds.set(token, preAmount + amount);
            emit FundsUpdateEvent(stakeToken, token, preAmount, preAmount + amount);
        } else {
            self.funds.set(token, amount);
            emit FundsUpdateEvent(stakeToken, token, 0, amount);
        }
    }

    function getFundsTokens(InsuranceFund.Props storage self) external view returns (address[] memory) {
        return self.funds.keys();
    }

    function getTokenFee(InsuranceFund.Props storage self, address token) external view returns (uint256) {
        (bool exists, uint256 preAmount) = self.funds.tryGet(token);
        return exists ? preAmount : 0;
    }
}

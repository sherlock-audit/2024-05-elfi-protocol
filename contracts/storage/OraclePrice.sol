// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library OraclePrice {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 private constant _ORACLE_PRICE = keccak256(abi.encode("xyz.elfi.storage.OraclePrice"));

    struct Props {
        EnumerableSet.AddressSet tokens;
        mapping(address => Data) tokenPrices;
        mapping(address => Data) preTokenPrices;
        EnumerableSet.Bytes32Set pairs;
        mapping(bytes32 => Data) pairPrices;
    }

    struct Data {
        int256 min;
        int256 max;
    }

    function load() public pure returns (Props storage self) {
        bytes32 s = _ORACLE_PRICE;
        assembly {
            self.slot := s
        }
    }

    function getPrice(Props storage oracle, address token) external view returns (Data memory) {
        return oracle.tokenPrices[token];
    }

    function getPrice(Props storage oracle, address token, address targetToken) external view returns (Data memory) {
        bytes32 pair = keccak256(abi.encode(token, targetToken));
        return oracle.pairPrices[pair];
    }

    function getPrePrice(Props storage oracle, address token) external view returns (Data memory) {
        return oracle.preTokenPrices[token];
    }

    function setPrice(Props storage oracle, address token, Data memory price) public {
        if (!oracle.tokens.contains(token)) {
            oracle.tokens.add(token);
        }
        oracle.tokenPrices[token] = price;
    }

    function setPrice(Props storage oracle, address token, address targetToken, Data memory price) public {
        bytes32 pair = keccak256(abi.encode(token, targetToken));
        if (!oracle.pairs.contains(pair)) {
            oracle.pairs.add(pair);
        }
        oracle.pairPrices[pair] = price;
    }

    function setPrePrice(Props storage oracle, address token, Data calldata price) external {
        if (!oracle.tokens.contains(token)) {
            oracle.tokens.add(token);
        }
        oracle.preTokenPrices[token] = price;
    }

    function clearAllPrice(Props storage oracle) external {
        address[] memory tokenAddrs = oracle.tokens.values();
        for (uint256 i; i < tokenAddrs.length; i++) {
            delete oracle.tokenPrices[tokenAddrs[i]];
            delete oracle.preTokenPrices[tokenAddrs[i]];
            oracle.tokens.remove(tokenAddrs[i]);
        }
    }
}

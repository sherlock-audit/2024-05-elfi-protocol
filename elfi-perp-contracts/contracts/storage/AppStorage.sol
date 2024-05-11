// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library AppStorage {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant COMMON_CONFIG = keccak256(abi.encode("COMMON_CONFIG"));
    bytes32 public constant CHAIN_CONFIG = keccak256(abi.encode("CHAIN_CONFIG"));
    bytes32 public constant STAKE_CONFIG = keccak256(abi.encode("STAKE_CONFIG"));
    bytes32 public constant TRADE_CONFIG = keccak256(abi.encode("TRADE_CONFIG"));
    bytes32 public constant TRADE_TOKEN_CONFIG = keccak256(abi.encode("TRADE_TOKEN_CONFIG"));
    bytes32 public constant USD_POOL_CONFIG = keccak256(abi.encode("USD_POOL_CONFIG"));
    bytes32 public constant LP_POOL_CONFIG = keccak256(abi.encode("LP_POOL_CONFIG"));
    bytes32 public constant SYMBOL_CONFIG = keccak256(abi.encode("SYMBOL_CONFIG"));
    bytes32 public constant VAULT_CONFIG = keccak256(abi.encode("VAULT_CONFIG"));

    bytes32 public constant REFERRAL = keccak256(abi.encode("REFERRAL"));

    struct Props {
        mapping(bytes32 => uint256) uintValues;
        mapping(bytes32 => int256) intValues;
        mapping(bytes32 => address) addressValues;
        mapping(bytes32 => bool) boolValues;
        mapping(bytes32 => string) stringValues;
        mapping(bytes32 => bytes32) bytes32Values;
        mapping(bytes32 => uint256[]) uintArrayValues;
        mapping(bytes32 => int256[]) intArrayValues;
        mapping(bytes32 => address[]) addressArrayValues;
        mapping(bytes32 => bool[]) boolArrayValues;
        mapping(bytes32 => string[]) stringArrayValues;
        mapping(bytes32 => bytes32[]) bytes32ArrayValues;
        mapping(bytes32 => EnumerableSet.AddressSet) addressSets;
        mapping(bytes32 => EnumerableSet.Bytes32Set) bytes32Sets;
        mapping(bytes32 => EnumerableSet.UintSet) uintSets;
    }

    function load() public pure returns (Props storage self) {
        assembly {
            self.slot := 0
        }
    }

    function setUintValue(Props storage self, bytes32 key, uint256 value) external {
        self.uintValues[key] = value;
    }

    function deleteUintValue(Props storage self, bytes32 key) external {
        delete self.uintValues[key];
    }

    function getUintValue(Props storage self, bytes32 key) external view returns (uint256) {
        return self.uintValues[key];
    }

    function setIntValue(Props storage self, bytes32 key, int256 value) external {
        self.intValues[key] = value;
    }

    function deleteIntValue(Props storage self, bytes32 key) external {
        delete self.intValues[key];
    }

    function getIntValue(Props storage self, bytes32 key) external view returns (int256) {
        return self.intValues[key];
    }

    function setAddressValue(Props storage self, bytes32 key, address value) external {
        self.addressValues[key] = value;
    }

    function deleteAddressValue(Props storage self, bytes32 key) external {
        delete self.addressValues[key];
    }

    function getAddressValue(Props storage self, bytes32 key) external view returns (address) {
        return self.addressValues[key];
    }

    function setBoolValue(Props storage self, bytes32 key, bool value) external {
        self.boolValues[key] = value;
    }

    function deleteBoolValue(Props storage self, bytes32 key) external {
        delete self.boolValues[key];
    }

    function getBoolValue(Props storage self, bytes32 key) external view returns (bool) {
        return self.boolValues[key];
    }

    function setAddressArrayValues(Props storage self, bytes32 key, address[] memory values) external {
        self.addressArrayValues[key] = values;
    }

    function getAddressArrayValues(Props storage self, bytes32 key) external view returns (address[] memory) {
        return self.addressArrayValues[key];
    }

    function containsAddress(Props storage self, bytes32 key, address value) external view returns (bool) {
        return self.addressSets[key].contains(value);
    }

    function addAddress(Props storage self, bytes32 key, address value) external {
        self.addressSets[key].add(value);
    }

    function removeAddress(Props storage self, bytes32 key, address value) external {
        self.addressSets[key].remove(value);
    }

    function containsBytes32(Props storage self, bytes32 key, bytes32 value) external view returns (bool) {
        return self.bytes32Sets[key].contains(value);
    }

    function addBytes32(Props storage self, bytes32 key, bytes32 value) external {
        self.bytes32Sets[key].add(value);
    }

    function removeBytes32(Props storage self, bytes32 key, bytes32 value) external {
        self.bytes32Sets[key].remove(value);
    }
}

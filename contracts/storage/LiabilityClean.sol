// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library LiabilityClean {
    using EnumerableSet for EnumerableSet.UintSet;

    struct Props {
        EnumerableSet.UintSet cleanIds;
        mapping(uint256 => LiabilityCleanInfo) cleanInfos;
    }

    struct LiabilityCleanInfo {
        address account;
        uint256 createTime;
        address[] liabilityTokens;
        uint256[] liabilities;
        address[] collaterals;
        uint256[] collateralsAmount;
    }

    event LiabilityCleanEvent(uint256 id, LiabilityCleanInfo info);

    function load() public pure returns (Props storage self) {
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.LiabilityClean"));
        assembly {
            self.slot := s
        }
    }

    function newClean(uint256 cleanId) external returns (LiabilityCleanInfo storage info) {
        Props storage self = load();
        self.cleanIds.add(cleanId);
        return self.cleanInfos[cleanId];
    }

    function addClean(uint256 cleanId, LiabilityCleanInfo memory info) external {
        Props storage self = load();
        self.cleanIds.add(cleanId);
        self.cleanInfos[cleanId] = info;
    }

    function removeClean(uint256 cleanId) external {
        Props storage self = load();
        self.cleanIds.remove(cleanId);
        delete self.cleanInfos[cleanId];
    }

    function getCleanInfo(uint256 id) external view returns (LiabilityCleanInfo memory) {
        Props storage self = load();
        return self.cleanInfos[id];
    }

    function getAllCleanInfo() external view returns (LiabilityCleanInfo[] memory) {
        Props storage self = load();
        uint256[] memory ids = self.cleanIds.values();
        LiabilityCleanInfo[] memory cleanInfos = new LiabilityCleanInfo[](ids.length);
        for (uint256 i; i < ids.length; i++) {
            cleanInfos[i] = self.cleanInfos[ids[i]];
        }
        return cleanInfos;
    }

    function emitCleanInfo(uint256 id, LiabilityCleanInfo storage info) external {
        emit LiabilityCleanEvent(id, info);
    }
}

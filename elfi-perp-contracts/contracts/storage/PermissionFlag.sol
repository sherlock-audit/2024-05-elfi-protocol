// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library PermissionFlag {

    bytes32 public constant ALL_PERMISSION_FLAG = keccak256("ALL_PERMISSION_FLAG");
    bytes32 public constant MINT_PERMISSION_FLAG = keccak256("MINT_PERMISSION_FLAG");
    bytes32 public constant BURN_PERMISSION_FLAG = keccak256("BURN_PERMISSION_FLAG");
    bytes32 public constant DEPOSIT_PERMISSION_FLAG = keccak256("DEPOSIT_PERMISSION_FLAG");
    bytes32 public constant WITHDRAW_PERMISSION_FLAG = keccak256("WITHDRAW_PERMISSION_FLAG");
    bytes32 public constant ORDER_PERMISSION_FLAG = keccak256("ORDER_PERMISSION_FLAG");

    using EnumerableSet for EnumerableSet.AddressSet;

    struct Props {
        EnumerableSet.AddressSet allowSet;
        EnumerableSet.AddressSet denySet;
    }

    error AddressDenied(address to);

    function load(bytes32 featureKey) public pure returns(Props storage self){
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.Permission", featureKey));
        assembly {
            self.slot := s
        }    
    }

    function isAllowed(bytes32 featureKey, address to) external view returns (bool){
        Props storage permission = load(featureKey);
        return permission.allowSet.contains(to);
    }

    function isDenied(bytes32 featureKey, address to) external view returns (bool) {
        Props storage permission = load(featureKey);
        return permission.denySet.contains(to);
    }

    function validDenied(bytes32 featureKey, address to) external view {
        Props storage permission = load(featureKey);
        if(permission.denySet.contains(to)) {
            revert AddressDenied(to);
        }
    }


}
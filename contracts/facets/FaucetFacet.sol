// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IFaucet.sol";
import "../process/VaultProcess.sol";
import "../mock/MockToken.sol";
import "../storage/RoleAccessControl.sol";

contract FaucetFacet is IFaucet {

    function requestTokens(RequestTokensParam calldata param) external payable override {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        for (uint256 i; i < param.mockTokens.length; i++) {
            MockToken(payable(param.mockTokens[i])).mint(param.account, param.mintAmounts[i]);        
        }
        VaultProcess.safeTransferETH(param.account, param.ethAmount);    
    }

}

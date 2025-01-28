// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script,console} from "forge-std/Script.sol";
import {IEUROs} from "../contracts/interfaces/IEUROs.sol";
import {SmartVaultManagerV6} from "../contracts/SmartVaultManagerV6.sol";
import {IRewardGateway} from "../contracts/interfaces/IRewardGateway.sol";

contract Liquidation is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // EUROs
        // uint256 _tokenID;
        // address manager = 0xba169cceCCF7aC51dA223e04654Cf16ef41A68CC;
        // IRewardGateway gateway = IRewardGateway(0xb7ba62932d90C3c7ef841eF4339995eB93299dC9);
        // IEUROs euros = IEUROs(0x643b34980E635719C15a2D4ce69571a258F940E9);
        // euros.grantRole(bytes32(0), manager);
        // gateway.liquidateVault(_tokenID);
        // euros.revokeRole(bytes32(0), manager);

        // USDs
        // uint256 _tokenID;
        // SmartVaultManagerV6 manager = SmartVaultManagerV6(0x496aB4A155C8fE359Cd28d43650fAFA0A35322Fb);
        // manager.liquidateVault(_tokenID);

        vm.stopBroadcast();
    }
}
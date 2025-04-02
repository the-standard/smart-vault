// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script,console} from "forge-std/Script.sol";
import {AutoRedemptionV2} from "../contracts/AutoRedemptionV2.sol";

contract AutoRedemptionV2Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        AutoRedemptionV2 redemption = new AutoRedemptionV2(
            0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C,
            hex"66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000",
            218,
            address(0), // pool
            0, // pool trigger price
            0x496aB4A155C8fE359Cd28d43650fAFA0A35322Fb,
            0x7c153d7561AA059E5313fF09D852BaB299EBaBE5,
            122,
            address(0), // quoter
            address(0) // swap router
        );
        
        

        vm.stopBroadcast();
    }
}
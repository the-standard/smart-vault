// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.21;

// import {Script,console} from "forge-std/Script.sol";
// import {AutoRedemption} from "../contracts/FlattenedAutoRedemption.sol";
// import {SmartVaultManagerV6} from "../contracts/FlattenedSmartVaultManagerV6.sol";
// import {SmartVaultYieldManager} from "../contracts/FlattenedSmartVaultYieldManager.sol";
// import {IUpgradeableProxy,Upgrades,IProxyAdmin} from "../contracts/FlattenedUpgrades.sol";
// import {ProxyAdmin,ITransparentUpgradeableProxy} from "../contracts/FlattenedTransparentUpgradeableProxy.sol";

// contract UpgradeVaultManagerProxy is Script {
//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);

//         // upgrade smart vault manager implementation
//         SmartVaultManagerV6 impl = new SmartVaultManagerV6();
//         ProxyAdmin(0x4118B11f63cAC928380fc59E0969bD7A901Fe1BD).upgradeAndCall(
//             ITransparentUpgradeableProxy(0x496aB4A155C8fE359Cd28d43650fAFA0A35322Fb),
//             address(impl), "");
//         vm.stopBroadcast();
//     }
// }
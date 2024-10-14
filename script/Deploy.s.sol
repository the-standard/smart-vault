// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script,console} from "forge-std/Script.sol";
import {ChainlinkMock} from "../contracts/test_utils/ChainlinkMock.sol";
import {USDsMock} from "../contracts/test_utils/USDsMock.sol";
import {MockNFTMetadataGenerator} from "src/test_utils/MockNFTMetadataGenerator.sol";
import {PriceCalculator} from "../contracts/PriceCalculator.sol";
import {SmartVaultDeployerV4} from "../contracts/SmartVaultDeployerV4.sol";
import {SmartVaultIndex} from "../contracts/SmartVaultIndex.sol";
import {SmartVaultManagerV6} from "../contracts/FlattenedManager.sol";
import {TransparentUpgradeableProxy} from "../contracts/FlattenedProxy.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PriceCalculator calculator = new PriceCalculator(bytes32("ETH"), 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 0xFdB631F5EE196F0ed6FAa767959853A9F217697D);
        SmartVaultDeployerV4 deployer = new SmartVaultDeployerV4(bytes32("ETH"), address(calculator));
        SmartVaultIndex index = new SmartVaultIndex();

        SmartVaultManagerV6 impl = new SmartVaultManagerV6();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl), msg.sender,
            abi.encodeCall(SmartVaultManagerV6.initialize, (
                110000,
                500,
                0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d, // usds
                msg.sender, // protocol
                0x33c5A816382760b6E5fb50d8854a61b3383a32a0, // token manager
                address(deployer),
                address(index), // protocol
                address(0),
                1000
            ))
        );

        index.setVaultManager(address(proxy));

        SmartVaultManagerV6 manager = SmartVaultManagerV6(address(proxy));
        manager.setWethAddress(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        manager.setSwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

        vm.stopBroadcast();
    }
}
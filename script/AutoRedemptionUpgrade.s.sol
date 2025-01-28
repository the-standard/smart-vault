// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script,console} from "forge-std/Script.sol";
import {AutoRedemption} from "../contracts/FlattenedAutoRedemption.sol";
import {SmartVaultManagerV6} from "../contracts/FlattenedSmartVaultManagerV6.sol";
import {SmartVaultYieldManager} from "../contracts/FlattenedSmartVaultYieldManager.sol";
import {IUpgradeableProxy,Upgrades,IProxyAdmin} from "../contracts/FlattenedUpgrades.sol";
import {ProxyAdmin,ITransparentUpgradeableProxy} from "../contracts/FlattenedTransparentUpgradeableProxy.sol";

contract AutoRedemptionUpgrade is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SmartVaultManagerV6 manager = SmartVaultManagerV6(0x496aB4A155C8fE359Cd28d43650fAFA0A35322Fb);

        // deploy auto redemption

        AutoRedemption autoRedemption = new AutoRedemption(
            address(manager),
            0x7c153d7561AA059E5313fF09D852BaB299EBaBE5,
            0x97083E831F8F0638855e2A515c90EdCF158DF238, // functions router
            0x66756e2d617262697472756d2d6d61696e6e65742d3100000000000000000000, // don ID
            0x8DEF4Db6697F4885bA4a3f75e9AdB3cEFCca6D6E, // pool
            0xE592427A0AEce92De3Edee1F18E0157C05861564, // swap router
            0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3, // quoter
            78831000000000000000000, // trigger price <0.99
            38, // subscription id
            manager.totalSupply() // last legacy vault id
        );

        manager.setAutoRedemption(address(autoRedemption));

        // eth
        autoRedemption.setSwapPath(
            address(0),
            abi.encodePacked(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(500),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(3000),0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d),
            abi.encodePacked(0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d,uint24(3000),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(500),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
        );

        // weth
        autoRedemption.setSwapPath(
            0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            abi.encodePacked(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(500),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(3000),0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d),
            abi.encodePacked(0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d,uint24(3000),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(500),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
        );

        // wbtc
        autoRedemption.setSwapPath(
            0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,
            abi.encodePacked(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,uint24(500),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(3000),0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d),
            abi.encodePacked(0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d,uint24(3000),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(500),0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f)
        );

        // arb
        autoRedemption.setSwapPath(
            0x912CE59144191C1204E64559FE8253a0e49E6548,
            abi.encodePacked(0x912CE59144191C1204E64559FE8253a0e49E6548,uint24(500),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(500),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(3000),0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d),
            abi.encodePacked(0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d,uint24(3000),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(500),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(500),0x912CE59144191C1204E64559FE8253a0e49E6548)
        );

        // link
        autoRedemption.setSwapPath(
            0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,
            abi.encodePacked(0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,uint24(3000),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(500),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(3000),0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d),
            abi.encodePacked(0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d,uint24(3000),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(500),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(3000),0xf97f4df75117a78c1A5a0DBb814Af92458539FB4)
        );

        // gmx
        autoRedemption.setSwapPath(
            0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a,
            abi.encodePacked(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a,uint24(10000),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(500),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(3000),0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d),
            abi.encodePacked(0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d,uint24(3000),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(500),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(10000),0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a)
        );

        // rdnt
        autoRedemption.setSwapPath(
            0x3082CC23568eA640225c2467653dB90e9250AaA0,
            abi.encodePacked(0x3082CC23568eA640225c2467653dB90e9250AaA0,uint24(3000),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(500),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(3000),0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d),
            abi.encodePacked(0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d,uint24(3000),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(500),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(3000),0x3082CC23568eA640225c2467653dB90e9250AaA0)
        );

        // sushi
        autoRedemption.setSwapPath(
            0xd4d42F0b6DEF4CE0383636770eF773390d85c61A,
            abi.encodePacked(0xd4d42F0b6DEF4CE0383636770eF773390d85c61A,uint24(3000),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(500),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(3000),0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d),
            abi.encodePacked(0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d,uint24(3000),0xaf88d065e77c8cC2239327C5EDb3A432268e5831,uint24(500),0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,uint24(3000),0xd4d42F0b6DEF4CE0383636770eF773390d85c61A)
        );

        vm.stopBroadcast();
    }
}
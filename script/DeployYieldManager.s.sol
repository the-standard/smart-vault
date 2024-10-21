// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script,console} from "forge-std/Script.sol";
import {SmartVaultYieldManager} from "../contracts/FlattenedYieldManager.sol";
import {SmartVaultManagerV6} from "../contracts/SmartVaultManagerV6.sol";
import {ISmartVault} from "../contracts/interfaces/ISmartVault.sol";

contract DeployYieldManager is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SmartVaultYieldManager yieldManager = new SmartVaultYieldManager(
            0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d, // usds
            0xaf88d065e77c8cC2239327C5EDb3A432268e5831, // usdc
            0x82FcEB07a4D01051519663f6c1c919aF21C27845, // uniproxy
            0x547A116a2622876cE1C8d19d41c683C8f7BeC5c0, // usd hypervisor
            0xE592427A0AEce92De3Edee1F18E0157C05861564 // uniswap router
        );
        SmartVaultManagerV6 manager = SmartVaultManagerV6(0x496aB4A155C8fE359Cd28d43650fAFA0A35322Fb);
        manager.setYieldManager(address(yieldManager));

        // weth
        yieldManager.addHypervisorData(
            0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            0x52ee1FFBA696c5E9b0Bc177A9f8a3098420EA691,
            3000,
            abi.encodePacked(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, uint24(500), 0xaf88d065e77c8cC2239327C5EDb3A432268e5831),
            abi.encodePacked(0xaf88d065e77c8cC2239327C5EDb3A432268e5831, uint24(500), 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
        );
        // wbtc
        yieldManager.addHypervisorData(
            0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,
            0x52ee1FFBA696c5E9b0Bc177A9f8a3098420EA691,
            3000,
            abi.encodePacked(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, uint24(500), 0xaf88d065e77c8cC2239327C5EDb3A432268e5831),
            abi.encodePacked(0xaf88d065e77c8cC2239327C5EDb3A432268e5831, uint24(500), 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f)
        );
        // arb
        yieldManager.addHypervisorData(
            0x912CE59144191C1204E64559FE8253a0e49E6548,
            0x6B7635b7d2E85188dB41C3c05B1efa87B143fcE8,
            10000,
            abi.encodePacked(0x912CE59144191C1204E64559FE8253a0e49E6548, uint24(500), 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, uint24(500), 0xaf88d065e77c8cC2239327C5EDb3A432268e5831),
            abi.encodePacked(0xaf88d065e77c8cC2239327C5EDb3A432268e5831, uint24(500), 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, uint24(500), 0x912CE59144191C1204E64559FE8253a0e49E6548)
        );
        // link
        yieldManager.addHypervisorData(
            0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,
            0xfA392dbefd2d5ec891eF5aEB87397A89843a8260,
            3000,
            abi.encodePacked(0xf97f4df75117a78c1A5a0DBb814Af92458539FB4, uint24(3000), 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, uint24(500), 0xaf88d065e77c8cC2239327C5EDb3A432268e5831),
            abi.encodePacked(0xaf88d065e77c8cC2239327C5EDb3A432268e5831, uint24(500), 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, uint24(3000), 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4)
        );
        // gmx
        yieldManager.addHypervisorData(
            0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a,
            0xF08BDBC590C59cb7B27A8D224E419ef058952b5f,
            3000,
            abi.encodePacked(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a, uint24(10000), 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, uint24(500), 0xaf88d065e77c8cC2239327C5EDb3A432268e5831),
            abi.encodePacked(0xaf88d065e77c8cC2239327C5EDb3A432268e5831, uint24(500), 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, uint24(10000), 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a)
        );
        // rdnt
        yieldManager.addHypervisorData(
            0x3082CC23568eA640225c2467653dB90e9250AaA0,
            0x2BCBDD577616357464CFe307Bc67F9e820A66e80,
            3000,
            abi.encodePacked(0x3082CC23568eA640225c2467653dB90e9250AaA0, uint24(3000), 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, uint24(500), 0xaf88d065e77c8cC2239327C5EDb3A432268e5831),
            abi.encodePacked(0xaf88d065e77c8cC2239327C5EDb3A432268e5831, uint24(500), 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, uint24(3000), 0x3082CC23568eA640225c2467653dB90e9250AaA0)
        );

        vm.stopBroadcast();
    }
}
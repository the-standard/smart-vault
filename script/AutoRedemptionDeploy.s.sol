// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script,console} from "forge-std/Script.sol";
import {AutoRedemption} from "../contracts/AutoRedemption.sol";
import {SmartVaultManagerV6} from "../contracts/SmartVaultManagerV6.sol";

contract AutoRedemptionDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        AutoRedemption redemption = new AutoRedemption(
            0x97083E831F8F0638855e2A515c90EdCF158DF238,
            hex"66756e2d617262697472756d2d6d61696e6e65742d3100000000000000000000",
            38,
            0x8DEF4Db6697F4885bA4a3f75e9AdB3cEFCca6D6E,
            78831026366734648999936,
            0x496aB4A155C8fE359Cd28d43650fAFA0A35322Fb,
            0x7c153d7561AA059E5313fF09D852BaB299EBaBE5,
            122,
            0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3,
            0xE592427A0AEce92De3Edee1F18E0157C05861564
        );
        
        // eth
        redemption.setSwapPath(
            0x0000000000000000000000000000000000000000,
            hex"82af49447d8a07e3bd95bd0d56f35241523fbab10001f4af88d065e77c8cc2239327c5edb3a432268e5831000bb82ea0be86990e8dac0d09e4316bb92086f304622d",
            hex"2ea0be86990e8dac0d09e4316bb92086f304622d000bb8af88d065e77c8cc2239327c5edb3a432268e58310001f482af49447d8a07e3bd95bd0d56f35241523fbab1"
        );
        
        // weth
        redemption.setSwapPath(
            0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            hex"82af49447d8a07e3bd95bd0d56f35241523fbab10001f4af88d065e77c8cc2239327c5edb3a432268e5831000bb82ea0be86990e8dac0d09e4316bb92086f304622d",
            hex"2ea0be86990e8dac0d09e4316bb92086f304622d000bb8af88d065e77c8cc2239327c5edb3a432268e58310001f482af49447d8a07e3bd95bd0d56f35241523fbab1"
        );
        
        // wbtc
        redemption.setSwapPath(
            0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,
            hex"2f2a2543b76a4166549f7aab2e75bef0aefc5b0f0001f4af88d065e77c8cc2239327c5edb3a432268e5831000bb82ea0be86990e8dac0d09e4316bb92086f304622d",
            hex"2ea0be86990e8dac0d09e4316bb92086f304622d000bb8af88d065e77c8cc2239327c5edb3a432268e58310001f42f2a2543b76a4166549f7aab2e75bef0aefc5b0f"
        );
        
        // arb
        redemption.setSwapPath(
            0x912CE59144191C1204E64559FE8253a0e49E6548,
            hex"912ce59144191c1204e64559fe8253a0e49e65480001f482af49447d8a07e3bd95bd0d56f35241523fbab10001f4af88d065e77c8cc2239327c5edb3a432268e5831000bb82ea0be86990e8dac0d09e4316bb92086f304622d",
            hex"2ea0be86990e8dac0d09e4316bb92086f304622d000bb8af88d065e77c8cc2239327c5edb3a432268e58310001f482af49447d8a07e3bd95bd0d56f35241523fbab10001f4912ce59144191c1204e64559fe8253a0e49e6548"
        );
        
        // link
        redemption.setSwapPath(
            0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,
            hex"f97f4df75117a78c1a5a0dbb814af92458539fb4000bb882af49447d8a07e3bd95bd0d56f35241523fbab10001f4af88d065e77c8cc2239327c5edb3a432268e5831000bb82ea0be86990e8dac0d09e4316bb92086f304622d",
            hex"2ea0be86990e8dac0d09e4316bb92086f304622d000bb8af88d065e77c8cc2239327c5edb3a432268e58310001f482af49447d8a07e3bd95bd0d56f35241523fbab1000bb8f97f4df75117a78c1a5a0dbb814af92458539fb4"
        );
        
        // gmx
        redemption.setSwapPath(
            0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a,
            hex"fc5a1a6eb076a2c7ad06ed22c90d7e710e35ad0a00271082af49447d8a07e3bd95bd0d56f35241523fbab10001f4af88d065e77c8cc2239327c5edb3a432268e5831000bb82ea0be86990e8dac0d09e4316bb92086f304622d",
            hex"2ea0be86990e8dac0d09e4316bb92086f304622d000bb8af88d065e77c8cc2239327c5edb3a432268e58310001f482af49447d8a07e3bd95bd0d56f35241523fbab1002710fc5a1a6eb076a2c7ad06ed22c90d7e710e35ad0a"
        );
        
        // usdt
        redemption.setSwapPath(
            0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9,
            abi.encodePacked(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, uint24(100), 0xaf88d065e77c8cC2239327C5EDb3A432268e5831, uint24(3000), 0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d),
            abi.encodePacked(0x2Ea0bE86990E8Dac0D09e4316Bb92086F304622d, uint24(3000), 0xaf88d065e77c8cC2239327C5EDb3A432268e5831, uint24(100), 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9)
        );

        SmartVaultManagerV6(0x496aB4A155C8fE359Cd28d43650fAFA0A35322Fb).setAutoRedemption(address(redemption));

        vm.stopBroadcast();
    }
}
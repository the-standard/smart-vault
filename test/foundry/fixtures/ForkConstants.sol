// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {ISwapRouter} from "src/interfaces/ISwapRouter.sol";
import {IUniProxy} from "src/interfaces/IUniProxy.sol";
import {IClearing} from "src/interfaces/IClearing.sol";
import {IHypervisor} from "src/interfaces/IHypervisor.sol";

// Fork constants
string constant ENV_RPC_URL = "ARBITRUM_RPC_URL";
string constant DEFAULT_RPC_URL = "https://arbitrum.llamarpc.com";

// Token constants
address constant USDC_ADDRESS = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
address constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
address constant WBTC_ADDRESS = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
address constant LINK_ADDRESS = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
address constant ARB_ADDRESS = 0x912CE59144191C1204E64559FE8253a0e49E6548;
address constant GMX_ADDRESS = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
address constant PAXG_ADDRESS = 0xfEb4DfC8C4Cf7Ed305bb08065D08eC6ee6728429;
address constant RDNT_ADDRESS = 0x3082CC23568eA640225c2467653dB90e9250AaA0;
address constant SUSHI_ADDRESS = 0xd4d42F0b6DEF4CE0383636770eF773390d85c61A;

ERC20 constant USDC = ERC20(USDC_ADDRESS);
ERC20 constant WETH = ERC20(WETH_ADDRESS);
ERC20 constant WBTC = ERC20(WBTC_ADDRESS);
ERC20 constant LINK = ERC20(LINK_ADDRESS);
ERC20 constant ARB = ERC20(ARB_ADDRESS);
ERC20 constant GMX = ERC20(GMX_ADDRESS);
ERC20 constant PAXG = ERC20(PAXG_ADDRESS);
ERC20 constant RDNT = ERC20(RDNT_ADDRESS);
ERC20 constant SUSHI = ERC20(SUSHI_ADDRESS);

bytes32 constant USDC_SYMBOL = "USDC";
bytes32 constant WETH_SYMBOL = "WETH";
bytes32 constant WBTC_SYMBOL = "WBTC";
bytes32 constant LINK_SYMBOL = "LINK";
bytes32 constant ARB_SYMBOL = "ARB";
bytes32 constant GMX_SYMBOL = "GMX";
bytes32 constant PAXG_SYMBOL = "PAXG";
bytes32 constant RDNT_SYMBOL = "RDNT";
bytes32 constant SUSHI_SYMBOL = "SUSHI";

address constant USDC_WHALE = 0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7;
address constant WETH_WHALE = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336;
address constant WBTC_WHALE = 0x078f358208685046a11C85e8ad32895DED33A249;
address constant LINK_WHALE = 0x191c10Aa4AF7C30e871E70C95dB0E4eb77237530;
address constant ARB_WHALE = 0xF3FC178157fb3c87548bAA86F9d24BA38E649B58;
address constant GMX_WHALE = 0x908C4D94D34924765f1eDc22A1DD098397c59dD4;
address constant PAXG_WHALE = 0x694321B2f596C0610c03DEac16C7341933Aaa952;
// address constant RDNT_WHALE = ?;
address constant SUSHI_WHALE = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

// Chainlink constants
address constant CL_NATIVE_USD_ADDRESS = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
address constant CL_WBTC_USD_ADDRESS = 0xd0C7101eACbB49F3deCcCc166d238410D6D46d57;
address constant CL_LINK_USD_ADDRESS = 0x86E53CF1B870786351Da77A57575e79CB55812CB;
address constant CL_ARB_USD_ADDRESS = 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6;
address constant CL_GMX_USD_ADDRESS = 0xDB98056FecFff59D032aB628337A4887110df3dB;
address constant CL_PAXG_USD_ADDRESS = 0x2BA975D4D7922cD264267Af16F3bD177F206FE3c;
address constant CL_RDNT_USD_ADDRESS = 0x20d0Fcab0ECFD078B036b6CAf1FaC69A6453b352;
address constant CL_SUSHI_USD_ADDRESS = 0xb2A8BA74cbca38508BA1632761b56C897060147C;

AggregatorV3Interface constant CL_NATIVE_USD = AggregatorV3Interface(CL_NATIVE_USD_ADDRESS);
AggregatorV3Interface constant CL_WBTC_USD = AggregatorV3Interface(CL_WBTC_USD_ADDRESS);
AggregatorV3Interface constant CL_LINK_USD = AggregatorV3Interface(CL_LINK_USD_ADDRESS);
AggregatorV3Interface constant CL_ARB_USD = AggregatorV3Interface(CL_ARB_USD_ADDRESS);
AggregatorV3Interface constant CL_GMX_USD = AggregatorV3Interface(CL_GMX_USD_ADDRESS);
AggregatorV3Interface constant CL_PAXG_USD = AggregatorV3Interface(CL_PAXG_USD_ADDRESS);
AggregatorV3Interface constant CL_RDNT_USD = AggregatorV3Interface(CL_RDNT_USD_ADDRESS);
AggregatorV3Interface constant CL_SUSHI_USD = AggregatorV3Interface(CL_SUSHI_USD_ADDRESS);

// Router constants
address constant UNISWAP_ROUTER_ADDRESS = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant RAMSES_ROUTER_ADDRESS = 0xAA23611badAFB62D37E7295A682D21960ac85A90;

ISwapRouter constant UNISWAP_ROUTER = ISwapRouter(UNISWAP_ROUTER_ADDRESS);
ISwapRouter constant RAMSES_ROUTER = ISwapRouter(RAMSES_ROUTER_ADDRESS);

// Gamma constants
address constant UNI_PROXY_ADDRESS = 0x82FcEB07a4D01051519663f6c1c919aF21C27845;
address constant CLEARING_ADDRESS = 0x80a44ce970D9380bDA7677916B860f37b4ba8Ce2;

IUniProxy constant UNI_PROXY = IUniProxy(UNI_PROXY_ADDRESS);
IClearing constant CLEARING = IClearing(CLEARING_ADDRESS);

// Hypervisor constants
address constant WBTC_HYPERVISOR_ADDRESS = 0x52ee1FFBA696c5E9b0Bc177A9f8a3098420EA691;
address constant LINK_HYPERVISOR_ADDRESS = 0xfA392dbefd2d5ec891eF5aEB87397A89843a8260;
address constant ARB_HYPERVISOR_ADDRESS = 0x330DFC5Bc1a63A1dCf1cD5bc9aD3D5e5E61Bcb6C;
address constant GMX_HYPERVISOR_ADDRESS = 0xF08BDBC590C59cb7B27A8D224E419ef058952b5f;
address constant RDNT_HYPERVISOR_ADDRESS = 0x2BCBDD577616357464CFe307Bc67F9e820A66e80;

IHypervisor constant WBTC_HYPERVISOR = IHypervisor(WBTC_HYPERVISOR_ADDRESS);
IHypervisor constant LINK_HYPERVISOR = IHypervisor(LINK_HYPERVISOR_ADDRESS);
IHypervisor constant ARB_HYPERVISOR = IHypervisor(ARB_HYPERVISOR_ADDRESS);
IHypervisor constant GMX_HYPERVISOR = IHypervisor(GMX_HYPERVISOR_ADDRESS);
IHypervisor constant RDNT_HYPERVISOR = IHypervisor(RDNT_HYPERVISOR_ADDRESS);

// Protocol constants
bytes32 constant NATIVE = "ETH";
uint256 constant COLLATERAL_RATE = 110_000; // 110%
uint256 constant PROTOCOL_FEE_RATE = 500; // 0.5%
uint24 constant UNISWAP_FEE = 500; // 0.05%
uint24 constant RAMSES_FEE = 3000; // 0.3%
uint16 constant VAULT_LIMIT = 10;

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPeripheryImmutableState} from "src/interfaces/IPeripheryImmutableState.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {SmartVaultManagerV6} from "src/SmartVaultManagerV6.sol";
import {TokenManager} from "src/TokenManager.sol";
import {SmartVaultYieldManager} from "src/SmartVaultYieldManager.sol";

import {SmartVaultDeployerV4} from "src/SmartVaultDeployerV4.sol";
import {SmartVaultIndex} from "src/SmartVaultIndex.sol";

import {MockNFTMetadataGenerator} from "src/test_utils/MockNFTMetadataGenerator.sol";

import {USDsMock} from "src/test_utils/USDsMock.sol";

import "./ForkConstants.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;
}

interface IUniswapV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
}

interface IUniProxyOwner {
    function owner() external view returns (address);
    function addPosition(address pos, uint8 version) external;
}

contract ForkFixture is Test {

    uint256 arbFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));

    address VAULT_OWNER = makeAddr("Vault owner");
    address VAULT_MANAGER_OWNER = makeAddr("Vault manager owner");
    address PROTOCOL = makeAddr("Protocol");
    address LIQUIDATOR = makeAddr("Liquidator");

    // Constants
    bytes32 constant NATIVE = "ETH";
    bytes32 constant WBTC = "WBTC";
    bytes32 constant WETH = "WETH";
    uint256 constant COLLATERAL_RATE = 110_000; // 110%
    uint256 constant PROTOCOL_FEE_RATE = 500; // 0.5%
    uint24 constant UNISWAP_FEE = 500; // 0.5%
    uint16 constant VAULT_LIMIT = 10;

    SmartVaultV4 vault;
    SmartVaultManagerV6 smartVaultManager;
    TokenManager tokenManager;
    SmartVaultYieldManager yieldManager;

    address clNativeUsd = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address clWbtcUsd = 0xd0C7101eACbB49F3deCcCc166d238410D6D46d57;

    address uniswapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address ramsesRouter = 0xAA23611badAFB62D37E7295A682D21960ac85A90;
    
    address uniProxy = 0x0A9C566EDA6641A308B4641d9fF99D20Ced50b24;

    address wtbcEthHypervisor = 0x52ee1FFBA696c5E9b0Bc177A9f8a3098420EA691;

    address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    USDsMock usds;

    function setUp() public virtual {
        vm.selectFork(arbFork);
        vm.rollFork(249949040);

        vm.label(clNativeUsd, "Chainlink ETH/USD");
        vm.label(clWbtcUsd, "Chainlink WBTC/USD");
        vm.label(uniswapRouter, "Uniswap Router");
        vm.label(ramsesRouter, "Ramses Router");
        vm.label(wtbcEthHypervisor, "WBTC/ETH Hypervisor");

        vm.label(uniProxy, "UniProxy");

        vm.label(weth, "WETH");
        vm.label(wbtc, "WBTC");
        vm.label(usdc, "USDC");

        usds = new USDsMock();
        tokenManager = new TokenManager(NATIVE, address(clNativeUsd));

        tokenManager.addAcceptedToken(wbtc, clWbtcUsd);
        tokenManager.addAcceptedToken(weth, clNativeUsd);

        smartVaultManager = new SmartVaultManagerV6();
        SmartVaultDeployerV4 smartVaultDeployer = new SmartVaultDeployerV4(NATIVE);
        SmartVaultIndex smartVaultIndex = new SmartVaultIndex();

        MockNFTMetadataGenerator nftMetadataGenerator = new MockNFTMetadataGenerator();

        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.initialize(
            COLLATERAL_RATE,
            PROTOCOL_FEE_RATE,
            address(usds),
            PROTOCOL,
            LIQUIDATOR,
            address(tokenManager),
            address(smartVaultDeployer),
            address(smartVaultIndex),
            address(nftMetadataGenerator),
            // address(yieldManager),
            VAULT_LIMIT
        );
        smartVaultIndex.setVaultManager(address(smartVaultManager));
        usds.grantRole(usds.DEFAULT_ADMIN_ROLE(), address(smartVaultManager));

        IUniswapV3Factory factory = IUniswapV3Factory(IPeripheryImmutableState(ramsesRouter).factory());
        address USDs_USDC_pool = factory.createPool(usdc, address(usds), 500);
        vm.label(USDs_USDC_pool, "USDs/USDC Pool");

        bytes memory constructorParams = abi.encode(USDs_USDC_pool, address(this), "USDs/USDC Hypervisors", "USDSUSDCHypervisor");
        bytes memory bytecodeWithParams = bytes.concat(hypervisorCode, constructorParams);

        address usdsHypervisor;
        assembly {
            usdsHypervisor := create(0, add(bytecodeWithParams, 0x20), mload(bytecodeWithParams))
        }
        vm.assertNotEq(usdsHypervisor, address(0));
        vm.label(usdsHypervisor, "USDs/USDC Hypervisor");

        vm.prank(IUniProxyOwner(uniProxy).owner());
        IUniProxyOwner(uniProxy).addPosition(usdsHypervisor, 1);

        yieldManager = new SmartVaultYieldManager(
            address(usds),
            usdc,
            weth,
            uniProxy,
            ramsesRouter,
            usdsHypervisor,
            uniswapRouter
        );

        yieldManager.addHypervisorData(
            weth,
            wtbcEthHypervisor,
            3000,
            abi.encodePacked(address(weth), uint24(3000), address(usdc)),
            abi.encodePacked(address(usdc), uint24(3000), address(weth))
        );

        yieldManager.addHypervisorData(
            wbtc,
            wtbcEthHypervisor,
            3000,
            abi.encodePacked(address(wbtc), uint24(3000), address(usdc)),
            abi.encodePacked(address(usdc), uint24(3000), address(wbtc))
        );

        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setYieldManager(address(yieldManager));
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setSwapRouter(uniswapRouter);
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setWethAddress(weth);

        vm.prank(VAULT_OWNER);
        (address smartVault, ) = smartVaultManager.mint();
        
        vault = SmartVaultV4(payable(smartVault));
    }
}
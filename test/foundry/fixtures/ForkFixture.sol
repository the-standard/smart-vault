// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {SmartVaultManagerV6} from "src/SmartVaultManagerV6.sol";
import {TokenManager} from "src/TokenManager.sol";
import {SmartVaultYieldManager} from "src/SmartVaultYieldManager.sol";

import {SmartVaultDeployerV4} from "src/SmartVaultDeployerV4.sol";
import {SmartVaultIndex} from "src/SmartVaultIndex.sol";

import {MockNFTMetadataGenerator} from "src/test_utils/MockNFTMetadataGenerator.sol";

import {USDsMock} from "src/test_utils/USDsMock.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;
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
    
    address clNativeUsd = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address clWbtcUsd = 0xd0C7101eACbB49F3deCcCc166d238410D6D46d57;

    address uniswapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    
    address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    USDsMock usds;

    // @note mocking yield manager here
    address yieldManager = makeAddr("Yield Manager");

    function setUp() public virtual {
        vm.selectFork(arbFork);
        vm.rollFork(249949040);

        vm.label(clNativeUsd, "Chainlink ETH/USD");
        vm.label(clWbtcUsd, "Chainlink WBTC/USD");
        vm.label(uniswapRouter, "Uniswap Router");
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

        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setYieldManager(yieldManager);
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setSwapRouter(uniswapRouter);
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setWethAddress(weth);

        vm.prank(VAULT_OWNER);
        (address smartVault, ) = smartVaultManager.mint();
        
        vault = SmartVaultV4(payable(smartVault));
    }
}
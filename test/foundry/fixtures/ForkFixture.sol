// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {SmartVaultManagerV6} from "src/SmartVaultManagerV6.sol";
import {TokenManager} from "src/TokenManager.sol";
import {SmartVaultYieldManager} from "src/SmartVaultYieldManager.sol";
import {SmartVaultDeployerV4} from "src/SmartVaultDeployerV4.sol";
import {SmartVaultIndex} from "src/SmartVaultIndex.sol";

import {MockNFTMetadataGenerator} from "src/test_utils/MockNFTMetadataGenerator.sol";
import {USDsMock} from "src/test_utils/USDsMock.sol";

import {FullMath} from "src/uniswap/FullMath.sol";
import {TickMath} from "src/uniswap/TickMath.sol";
import {LiquidityAmounts} from "src/uniswap/LiquidityAmounts.sol";

import {IPeripheryImmutableState} from "src/interfaces/IPeripheryImmutableState.sol";
import {IUniProxy} from "src/interfaces/IUniProxy.sol";
import {IUniswapV3Pool} from "src/interfaces/IUniswapV3Pool.sol";

import "./ForkConstants.sol";

interface IWETH9 is IERC20 {
    function deposit() external payable;
}

interface IUniswapV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
}

interface IClearing {
    function owner() external view returns (address);
    function addPosition(address pos, uint8 version) external;
    function setTwapCheck(bool check) external;
}

interface HypervisorOwner {
    function rebalance(
        int24 baseLower,
        int24 baseUpper,
        int24 limitLower,
        int24 limitUpper,
        address feeRecipient,
        uint256[4] memory baseFees,
        uint256[4] memory limitFees
    ) external;

    function setWhitelist(address _address) external;
}


contract ForkFixture is Test {

    uint256 arbFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));

    address VAULT_OWNER = makeAddr("Vault owner");
    address VAULT_MANAGER_OWNER = makeAddr("Vault manager owner");
    address PROTOCOL = makeAddr("Protocol");
    address LIQUIDATOR = makeAddr("Liquidator");

    address FEE_RECIPIENT = makeAddr("Fee Recipient");

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

    address USDs_USDC_pool;

    address clNativeUsd = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address clWbtcUsd = 0xd0C7101eACbB49F3deCcCc166d238410D6D46d57;

    address uniswapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address ramsesRouter = 0xAA23611badAFB62D37E7295A682D21960ac85A90;
    
    address uniProxy = 0x82FcEB07a4D01051519663f6c1c919aF21C27845;
    address clearing = 0x80a44ce970D9380bDA7677916B860f37b4ba8Ce2;

    address usdsUsdcHypervisor;
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
        vm.label(clearing, "Clearing");

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
        USDs_USDC_pool = factory.createPool(usdc, address(usds), 500);
        vm.label(USDs_USDC_pool, "USDs/USDC Pool");

        addLiquidity();
        usdsUsdcHypervisor = setupHypervisor();

        yieldManager = new SmartVaultYieldManager(
            address(usds),
            usdc,
            weth,
            uniProxy,
            ramsesRouter,
            //uniswapRouter,
            usdsUsdcHypervisor,
            uniswapRouter
        );
        yieldManager.setFeeData(0,address(smartVaultManager));

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

    function ramsesV2MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata
    ) external  {
        deal(address(usds), msg.sender, amount0Owed);
        deal(usdc, msg.sender, amount1Owed);
    }

    function addLiquidity() internal {
        (address token0 , address token1) = address(usds) < usdc ? (address(usds), usdc) : (usdc, address(usds));

        uint256 price = (10 ** ERC20(token1).decimals() * 1 << 192) / 10 ** ERC20(token0).decimals();
        uint160 sqrtPriceX96 = uint160(sqrt(price));

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        IUniswapV3Pool(USDs_USDC_pool).initialize(sqrtPriceX96);
 
        int24 tickLower = tick - 10 - tick%IUniswapV3Pool(USDs_USDC_pool).tickSpacing();
        int24 tickUpper = tick + 10 + tick%IUniswapV3Pool(USDs_USDC_pool).tickSpacing();

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            100_000e18,
            100_000e6
        );
        IUniswapV3Pool(USDs_USDC_pool).mint(address(this), tickLower, tickUpper, liquidity,"");

        IUniswapV3Pool(USDs_USDC_pool).increaseObservationCardinalityNext(100);
    }

    function setupHypervisor() internal returns(address hypervisor) {
        bytes memory constructorParams = abi.encode(USDs_USDC_pool, address(this), "USDs/USDC Hypervisors", "USDSUSDCHypervisor");
        bytes memory bytecodeWithParams = bytes.concat(hypervisorCode, constructorParams);

        assembly {
            hypervisor := create(0, add(bytecodeWithParams, 0x20), mload(bytecodeWithParams))
        }
        vm.assertNotEq(hypervisor, address(0));
        vm.label(hypervisor, "USDs/USDC Hypervisor");
        HypervisorOwner(hypervisor).setWhitelist(uniProxy);
        vm.prank(IClearing(uniProxy).owner());
        IClearing(clearing).addPosition(hypervisor, 1);

        HypervisorOwner(hypervisor).rebalance(
            -276350, // base lower  
            -276300, // base upper  
            -276280, // limit lower
            -276230, // limit upper
            FEE_RECIPIENT,
            [uint256(0), uint256(0), uint256(0), uint256(0)],
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        );
        vm.warp(block.timestamp + 3601);
        deal(address(usds), address(this), 1000e18);
        deal(usdc, address(this), 1000e6);

        usds.approve(hypervisor, 1000e18);
        IERC20(usdc).approve(hypervisor, 1000e6);
        IUniProxy(uniProxy).deposit(
            1000e18,
            1000e6,
            msg.sender,
            hypervisor,
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        );
    }

    function sqrt(uint256 x) internal pure returns (uint128) {
        if (x == 0) return 0;
        else{
            uint256 xx = x;
            uint256 r = 1;
            if (xx >= 0x100000000000000000000000000000000) { xx >>= 128; r <<= 64; }
            if (xx >= 0x10000000000000000) { xx >>= 64; r <<= 32; }
            if (xx >= 0x100000000) { xx >>= 32; r <<= 16; }
            if (xx >= 0x10000) { xx >>= 16; r <<= 8; }
            if (xx >= 0x100) { xx >>= 8; r <<= 4; }
            if (xx >= 0x10) { xx >>= 4; r <<= 2; }
            if (xx >= 0x8) { r <<= 1; }
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            uint256 r1 = x / r;
            return uint128 (r < r1 ? r : r1);
        }
    }
}
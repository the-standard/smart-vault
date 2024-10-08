// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {TokenManager} from "src/TokenManager.sol";
import {SmartVaultManagerV6} from "src/SmartVaultManagerV6.sol";
import {SmartVaultDeployerV4} from "src/SmartVaultDeployerV4.sol";
import {SmartVaultIndex} from "src/SmartVaultIndex.sol";
import {SmartVaultYieldManager} from "src/SmartVaultYieldManager.sol";
import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {PriceCalculator} from "src/PriceCalculator.sol";

import {MockNFTMetadataGenerator} from "src/test_utils/MockNFTMetadataGenerator.sol";
import {USDsMock} from "src/test_utils/USDsMock.sol";
import "src/test_utils/BytecodeConstants.sol";

import {FullMath} from "src/uniswap/FullMath.sol";
import {TickMath} from "src/uniswap/TickMath.sol";
import {LiquidityAmounts} from "src/uniswap/LiquidityAmounts.sol";

import {IClearing} from "src/interfaces/IClearing.sol";
import {IHypervisor} from "src/interfaces/IHypervisor.sol";
import {IPeripheryImmutableState} from "src/interfaces/IPeripheryImmutableState.sol";
import {IUniswapV3Pool} from "src/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "src/interfaces/IUniswapV3Factory.sol";

import "./ForkConstants.sol";
import {HYPERVISOR_CODE} from "src/test_utils/BytecodeConstants.sol";
import {console} from "forge-std/console.sol";

contract ForkFixture is Test {
    // Actors
    address VAULT_OWNER = _makeAddr("Vault owner");
    address VAULT_MANAGER_OWNER = _makeAddr("Vault manager owner");
    address YIELD_MANAGER_OWNER = _makeAddr("Yield manager owner");
    address PROTOCOL = _makeAddr("Protocol");
    address HYPERVISOR_FEE_RECIPIENT = _makeAddr("Hypervisor fee recipient");

    // Protocol deployments
    USDsMock usds;
    IUniswapV3Pool usdsPool;
    IHypervisor usdsHypervisor;
    TokenManager tokenManager;
    SmartVaultManagerV6 smartVaultManager;
    SmartVaultYieldManager yieldManager;
    SmartVaultV4 vault;

    // State
    struct CollateralData {
        ERC20 token;
        AggregatorV3Interface clFeed;
        IHypervisor hypervisor;
        bytes pathToUsdc;
        bytes pathFromUsdc;
    }

    bytes32[] collateralSymbols;
    mapping(bytes32 => CollateralData) collateralData;

    function setUp() public virtual {
        // NOTE: we can't use these cheatcodes because they aren't supported by Crytic
        // vm.createSelectFork(vm.envOr(ENV_RPC_URL, DEFAULT_RPC_URL));
        vm.selectFork(vm.createFork(DEFAULT_RPC_URL));

        _labelConstants();
        _pushCollateralSymbols();
        _pushCollateralData();

        _deployUsds();
        _deployTokenManager();
        _deployVaultManager();
        _deployYieldManager();
        _deployVault();
    }

    // create our own version of this forge-std cheat to avoid linearization issues in invariant scaffolding
    function _makeAddr(string memory name) internal virtual returns (address addr) {
        addr = vm.addr(uint256(keccak256(abi.encodePacked(name))));
        vm.label(addr, name);
    }

    function _deal(ERC20 _token, address _whale, address _to) internal {
        uint256 _balance = _token.balanceOf(_whale);
        vm.prank(_whale);
        _token.transfer(_to, _balance);
    }

    function _labelConstants() internal {
        vm.label(USDC_ADDRESS, "USDC");
        vm.label(WETH_ADDRESS, "WETH");
        vm.label(WBTC_ADDRESS, "WBTC");
        vm.label(LINK_ADDRESS, "LINK");
        vm.label(ARB_ADDRESS, "ARB");
        vm.label(GMX_ADDRESS, "GMX");
        vm.label(PAXG_ADDRESS, "PAXG");
        // vm.label(RDNT_ADDRESS, "RDNT");
        vm.label(SUSHI_ADDRESS, "SUSHI");

        vm.label(CL_NATIVE_USD_ADDRESS, "Chainlink ETH/USD");
        vm.label(CL_WBTC_USD_ADDRESS, "Chainlink WBTC/USD");
        vm.label(CL_LINK_USD_ADDRESS, "Chainlink LINK/USD");
        vm.label(CL_ARB_USD_ADDRESS, "Chainlink ARB/USD");
        vm.label(CL_GMX_USD_ADDRESS, "Chainlink GMX/USD");
        vm.label(CL_PAXG_USD_ADDRESS, "Chainlink PAXG/USD");
        // vm.label(CL_RDNT_USD_ADDRESS, "Chainlink RDNT/USD");
        vm.label(CL_SUSHI_USD_ADDRESS, "Chainlink SUSHI/USD");

        vm.label(UNISWAP_ROUTER_ADDRESS, "Uniswap Router");
        vm.label(RAMSES_ROUTER_ADDRESS, "Ramses Router");

        vm.label(UNI_PROXY_ADDRESS, "UniProxy");
        vm.label(CLEARING_ADDRESS, "Clearing");

        vm.label(WBTC_HYPERVISOR_ADDRESS, "WBTC Hypervisor");
        vm.label(LINK_HYPERVISOR_ADDRESS, "LINK Hypervisor");
        vm.label(ARB_HYPERVISOR_ADDRESS, "ARB Hypervisor");
        vm.label(GMX_HYPERVISOR_ADDRESS, "GMX Hypervisor");
        // vm.label(RDNT_HYPERVISOR_ADDRESS, "RDNT Hypervisor");
    }

    function _pushCollateralSymbols() internal {
        _labelConstants();
        collateralSymbols.push(NATIVE);
        collateralSymbols.push(WETH_SYMBOL);
        collateralSymbols.push(WBTC_SYMBOL);
        collateralSymbols.push(LINK_SYMBOL);
        collateralSymbols.push(ARB_SYMBOL);
        collateralSymbols.push(GMX_SYMBOL);
        collateralSymbols.push(PAXG_SYMBOL);
        // collateralSymbols.push(RDNT_SYMBOL);
        collateralSymbols.push(SUSHI_SYMBOL);
    }

    function _pushCollateralData() internal {
        collateralData[NATIVE] = CollateralData(
            ERC20(address(0)),
            CL_NATIVE_USD,
            WBTC_HYPERVISOR,
            abi.encodePacked(WETH_ADDRESS, UNISWAP_FEE, USDC_ADDRESS),
            abi.encodePacked(USDC_ADDRESS, UNISWAP_FEE, WETH_ADDRESS)
        );

        collateralData[WETH_SYMBOL] = CollateralData(
            WETH,
            CL_NATIVE_USD,
            WBTC_HYPERVISOR,
            abi.encodePacked(WETH_ADDRESS, UNISWAP_FEE, USDC_ADDRESS),
            abi.encodePacked(USDC_ADDRESS, UNISWAP_FEE, WETH_ADDRESS)
        );

        collateralData[WBTC_SYMBOL] = CollateralData(
            WBTC,
            CL_WBTC_USD,
            WBTC_HYPERVISOR,
            abi.encodePacked(WBTC_ADDRESS, UNISWAP_FEE, WETH_ADDRESS, UNISWAP_FEE, USDC_ADDRESS),
            abi.encodePacked(USDC_ADDRESS, UNISWAP_FEE, WETH_ADDRESS, UNISWAP_FEE, WBTC_ADDRESS)
        );

        collateralData[LINK_SYMBOL] = CollateralData(
            LINK,
            CL_LINK_USD,
            LINK_HYPERVISOR,
            abi.encodePacked(LINK_ADDRESS, RAMSES_FEE, WETH_ADDRESS, UNISWAP_FEE, USDC_ADDRESS),
            abi.encodePacked(USDC_ADDRESS, UNISWAP_FEE, WETH_ADDRESS, RAMSES_FEE, LINK_ADDRESS)
        );

        collateralData[ARB_SYMBOL] = CollateralData(
            ARB,
            CL_ARB_USD,
            ARB_HYPERVISOR,
            abi.encodePacked(ARB_ADDRESS, UNISWAP_FEE, WETH_ADDRESS, UNISWAP_FEE, USDC_ADDRESS),
            abi.encodePacked(USDC_ADDRESS, UNISWAP_FEE, WETH_ADDRESS, UNISWAP_FEE, ARB_ADDRESS)
        );

        collateralData[GMX_SYMBOL] = CollateralData(
            GMX,
            CL_GMX_USD,
            GMX_HYPERVISOR,
            abi.encodePacked(GMX_ADDRESS, RAMSES_FEE, WETH_ADDRESS, UNISWAP_FEE, USDC_ADDRESS),
            abi.encodePacked(USDC_ADDRESS, UNISWAP_FEE, WETH_ADDRESS, RAMSES_FEE, GMX_ADDRESS)
        );

        collateralData[PAXG_SYMBOL] =
            CollateralData(PAXG, CL_PAXG_USD, IHypervisor(address(0)), new bytes(0), new bytes(0));

        collateralData[SUSHI_SYMBOL] =
            CollateralData(SUSHI, CL_SUSHI_USD, IHypervisor(address(0)), new bytes(0), new bytes(0));

        // TODO: RDNT configurations not clear
    }

    function _deployUsds() internal {
        // deploy USDs
        usds = new USDsMock();
        vm.label(address(usds), "USDs");

        // deploy USDs Uniswap pool
        IUniswapV3Factory factory = IUniswapV3Factory(IPeripheryImmutableState(UNISWAP_ROUTER_ADDRESS).factory());
        usdsPool = IUniswapV3Pool(factory.createPool(USDC_ADDRESS, address(usds), UNISWAP_FEE));
        vm.label(address(usdsPool), "USDs/USDC Uniswap Pool");

        // deal tokens to this contract
        usds.grantRole(usds.MINTER_ROLE(), address(this));
        usds.mint(address(this), 1_000_000 * 10 ** usds.decimals());
        _deal(USDC, USDC_WHALE, address(this));

        // seed the pool with liquidity
        _addUsdsLiquidity();

        // deploy USDs/USDC hypervisor
        usdsHypervisor = IHypervisor(_deployUsdsHypervisor());
        vm.label(address(usdsHypervisor), "USDs/USDC Hypervisor");
    }

    function _deployTokenManager() internal {
        // deploy TokenManager
        tokenManager = new TokenManager(NATIVE, CL_NATIVE_USD_ADDRESS);

        // add accepted tokens
        for (uint256 i; i < collateralSymbols.length; i++) {
            if (collateralSymbols[i] == NATIVE) continue;

            CollateralData memory collateral = collateralData[collateralSymbols[i]];
            tokenManager.addAcceptedToken(address(collateral.token), address(collateral.clFeed));
        }
    }

    function _deployVaultManager() internal {
        // deploy SmartVaultManager
        smartVaultManager = new SmartVaultManagerV6();
        PriceCalculator priceCalculator =
            new PriceCalculator(NATIVE, CL_USDC_USD_ADDRESS, CL_L2_SEQUENCER_UPTIME_FEED_ADDRESS);
        SmartVaultDeployerV4 smartVaultDeployer = new SmartVaultDeployerV4(NATIVE, address(priceCalculator));
        SmartVaultIndex smartVaultIndex = new SmartVaultIndex();
        MockNFTMetadataGenerator nftMetadataGenerator = new MockNFTMetadataGenerator();

        // initialize SmartVaultManager
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.initialize(
            COLLATERAL_RATE,
            PROTOCOL_FEE_RATE,
            address(usds),
            PROTOCOL,
            address(tokenManager),
            address(smartVaultDeployer),
            address(smartVaultIndex),
            address(nftMetadataGenerator),
            VAULT_LIMIT
        );
        // vm.startPrank(sender) is not yet fully supported by invariant fuzzers, so we have to duplicate vm.prank
        // NOTE: the yield manager is set after it is deployed below
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setSwapRouter(UNISWAP_ROUTER_ADDRESS);
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setWethAddress(WETH_ADDRESS);

        smartVaultIndex.setVaultManager(address(smartVaultManager));
        usds.grantRole(usds.DEFAULT_ADMIN_ROLE(), address(smartVaultManager));
        usds.grantRole(usds.BURNER_ROLE(), address(smartVaultManager));
    }

    function _deployYieldManager() internal {
        // deploy SmartVaultYieldManager
        vm.prank(YIELD_MANAGER_OWNER);
        yieldManager = new SmartVaultYieldManager(
            address(usds),
            USDC_ADDRESS,
            WETH_ADDRESS,
            UNI_PROXY_ADDRESS,
            RAMSES_ROUTER_ADDRESS,
            address(usdsHypervisor),
            UNISWAP_ROUTER_ADDRESS
        );

        // add hypervisor data
        for (uint256 i; i < collateralSymbols.length; i++) {
            if (collateralSymbols[i] == NATIVE) continue;

            CollateralData memory collateral = collateralData[collateralSymbols[i]];
            if (address(collateral.hypervisor) == address(0)) continue;

            vm.prank(YIELD_MANAGER_OWNER);
            yieldManager.addHypervisorData(
                address(collateral.token),
                address(collateral.hypervisor),
                UNISWAP_FEE,
                collateral.pathToUsdc,
                collateral.pathFromUsdc
            );
        }

        // set fee data
        vm.prank(YIELD_MANAGER_OWNER);
        yieldManager.setFeeData(PROTOCOL_FEE_RATE, address(smartVaultManager));

        // set yield manager
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setYieldManager(address(yieldManager));
    }

    function _deployVault() internal {
        vm.prank(VAULT_OWNER);
        (address smartVault,) = smartVaultManager.mint();

        vault = SmartVaultV4(payable(smartVault));
    }

    function _addUsdsLiquidity() internal {
        (address token0, address token1) =
            address(usds) < USDC_ADDRESS ? (address(usds), USDC_ADDRESS) : (USDC_ADDRESS, address(usds));

        uint256 price = (10 ** ERC20(token1).decimals() * 1 << 192) / 10 ** ERC20(token0).decimals();
        uint160 sqrtPriceX96 = uint160(FullMath.sqrt(price));

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        IUniswapV3Pool(usdsPool).initialize(sqrtPriceX96);

        int24 tickLower = tick - 100 - tick % IUniswapV3Pool(usdsPool).tickSpacing();
        int24 tickUpper = tick + 100 + tick % IUniswapV3Pool(usdsPool).tickSpacing();

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            100_000 * 10 ** ERC20(token0).decimals(),
            100_000 * 10 ** ERC20(token1).decimals()
        );
        IUniswapV3Pool(usdsPool).mint(address(this), tickLower, tickUpper, liquidity, "");

        IUniswapV3Pool(usdsPool).increaseObservationCardinalityNext(100);
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external {
        usds.transfer(msg.sender, amount0Owed);
        USDC.transfer(msg.sender, amount1Owed);
    }

    // TODO: investigate whether there is a simpler way to do this without using raw bytecode
    function _deployUsdsHypervisor() internal returns (address hypervisor) {
        bytes memory constructorParams = abi.encode(usdsPool, address(this), "USDs-USDC Hypervisor", "USDs-USDC");
        bytes memory bytecodeWithParams = bytes.concat(HYPERVISOR_CODE, constructorParams);

        assembly {
            hypervisor := create(0, add(bytecodeWithParams, 0x20), mload(bytecodeWithParams))
        }

        vm.assertNotEq(hypervisor, address(0));
        IHypervisor(hypervisor).setWhitelist(UNI_PROXY_ADDRESS);
        vm.prank(IClearing(UNI_PROXY_ADDRESS).owner());
        CLEARING.addPosition(hypervisor, 1);

        IHypervisor(hypervisor).rebalance(
            -276350, // base lower
            -276300, // base upper
            -276280, // limit lower
            -276230, // limit upper
            HYPERVISOR_FEE_RECIPIENT,
            [uint256(0), uint256(0), uint256(0), uint256(0)],
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        );
        vm.warp(block.timestamp + 3601);

        usds.approve(hypervisor, 1_000 * 10 ** usds.decimals());
        USDC.approve(hypervisor, 1_000 * 10 ** USDC.decimals());
        UNI_PROXY.deposit(1000e18, 1000e6, msg.sender, hypervisor, [uint256(0), uint256(0), uint256(0), uint256(0)]);
    }
}

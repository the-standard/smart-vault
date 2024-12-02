// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

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
    address USDS_OWNER = 0xF9d85965c6A40D0C029471d758850e4b4C0d5b17;

    // Protocol deployments
    TokenManager tokenManager;
    SmartVaultManagerV6 smartVaultManager;
    SmartVaultYieldManager yieldManager;
    SmartVaultV4 vault;
    PriceCalculator priceCalculator;

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

        _addUSDLiquidity();
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
        vm.label(USDS_ADDRESS, "USDs");
        vm.label(USDC_ADDRESS, "USDC");
        vm.label(WETH_ADDRESS, "WETH");
        vm.label(WBTC_ADDRESS, "WBTC");
        vm.label(LINK_ADDRESS, "LINK");
        vm.label(ARB_ADDRESS, "ARB");
        vm.label(GMX_ADDRESS, "GMX");
        vm.label(PAXG_ADDRESS, "PAXG");
        vm.label(RDNT_ADDRESS, "RDNT");
        vm.label(SUSHI_ADDRESS, "SUSHI");

        vm.label(CL_NATIVE_USD_ADDRESS, "Chainlink ETH/USD");
        vm.label(CL_WBTC_USD_ADDRESS, "Chainlink WBTC/USD");
        vm.label(CL_LINK_USD_ADDRESS, "Chainlink LINK/USD");
        vm.label(CL_ARB_USD_ADDRESS, "Chainlink ARB/USD");
        vm.label(CL_GMX_USD_ADDRESS, "Chainlink GMX/USD");
        vm.label(CL_PAXG_USD_ADDRESS, "Chainlink PAXG/USD");
        vm.label(CL_RDNT_USD_ADDRESS, "Chainlink RDNT/USD");
        vm.label(CL_SUSHI_USD_ADDRESS, "Chainlink SUSHI/USD");

        vm.label(UNISWAP_ROUTER_ADDRESS, "Uniswap Router");

        vm.label(UNI_PROXY_ADDRESS, "UniProxy");
        vm.label(CLEARING_ADDRESS, "Clearing");

        vm.label(USDS_HYPERVISOR_ADDRESS, "USDs Hypervisor");
        vm.label(WBTC_HYPERVISOR_ADDRESS, "WBTC Hypervisor");
        vm.label(LINK_HYPERVISOR_ADDRESS, "LINK Hypervisor");
        vm.label(ARB_HYPERVISOR_ADDRESS, "ARB Hypervisor");
        vm.label(GMX_HYPERVISOR_ADDRESS, "GMX Hypervisor");
        vm.label(RDNT_HYPERVISOR_ADDRESS, "RDNT Hypervisor");
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
        collateralSymbols.push(RDNT_SYMBOL);
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
            abi.encodePacked(WBTC_ADDRESS, UNISWAP_FEE, USDC_ADDRESS),
            abi.encodePacked(USDC_ADDRESS, UNISWAP_FEE, WBTC_ADDRESS)
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

        collateralData[RDNT_SYMBOL] = CollateralData(
            RDNT,
            CL_RDNT_USD,
            RDNT_HYPERVISOR,
            abi.encodePacked(RDNT_ADDRESS, RAMSES_FEE, WETH_ADDRESS, UNISWAP_FEE, USDC_ADDRESS),
            abi.encodePacked(USDC_ADDRESS, UNISWAP_FEE, WETH_ADDRESS, RAMSES_FEE, RDNT_ADDRESS)
        );

        collateralData[PAXG_SYMBOL] =
            CollateralData(PAXG, CL_PAXG_USD, IHypervisor(address(0)), new bytes(0), new bytes(0));

        collateralData[SUSHI_SYMBOL] =
            CollateralData(SUSHI, CL_SUSHI_USD, IHypervisor(address(0)), new bytes(0), new bytes(0));

        // TODO: RDNT configurations not clear
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
        priceCalculator = new PriceCalculator(NATIVE, CL_USDC_USD_ADDRESS, CL_L2_SEQUENCER_UPTIME_FEED_ADDRESS);
        SmartVaultDeployerV4 smartVaultDeployer = new SmartVaultDeployerV4(NATIVE, address(priceCalculator));
        SmartVaultIndex smartVaultIndex = new SmartVaultIndex();
        MockNFTMetadataGenerator nftMetadataGenerator = new MockNFTMetadataGenerator();

        // initialize SmartVaultManager
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.initialize(
            COLLATERAL_RATE,
            PROTOCOL_FEE_RATE,
            USDS_ADDRESS,
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
        // grant default admin role to smart vault manager
        vm.startPrank(USDS_OWNER);
        ADMIN_USDS.grantRole(0x00, address(smartVaultManager));
        ADMIN_USDS.grantRole(ADMIN_USDS.BURNER_ROLE(), address(smartVaultManager));
        vm.stopPrank();
    }

    function _deployYieldManager() internal {
        // deploy SmartVaultYieldManager
        vm.prank(YIELD_MANAGER_OWNER);
        yieldManager = new SmartVaultYieldManager(
            USDS_ADDRESS, USDC_ADDRESS, UNI_PROXY_ADDRESS, USDS_HYPERVISOR_ADDRESS, UNISWAP_ROUTER_ADDRESS
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

    function _addUSDLiquidity() internal {
        vm.startPrank(USDS_OWNER);
        uint256 usdAmount = 1_000_000 * 10 ** USDS.decimals();
        ADMIN_USDS.setSupplyLimit(10_000_000e18);
        ADMIN_USDS.mint(address(this), usdAmount);
        vm.stopPrank();
        _deal(USDC, USDC_WHALE, address(this));

        IUniswapV3Pool pool = IUniswapV3Pool(USD_POOL_ADDRESS);
        (, int24 tick,,,,,) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();
        // int24 tickLower = (tick - tick) / tickSpacing * tickSpacing;
        // int24 tickLower = tick / tickSpacing * tickSpacing - tickSpacing;
        int24 tickLower = (tick - 500) / tickSpacing * tickSpacing;
        // int24 tickUpper = (tick + tick) / tickSpacing * tickSpacing;
        // int24 tickUpper = tick / tickSpacing * tickSpacing + tickSpacing;
        int24 tickUpper = (tick + 500) / tickSpacing * tickSpacing;

        pool.mint(address(this), tickLower, tickUpper, 1e19, "");

        pool.increaseObservationCardinalityNext(100);
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external {
        USDS.transfer(msg.sender, amount0Owed);
        USDC.transfer(msg.sender, amount1Owed);
    }
}

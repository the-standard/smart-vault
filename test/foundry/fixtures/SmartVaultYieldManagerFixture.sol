// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@chimera/Hevm.sol";

import {SmartVaultManagerFixture} from "./SmartVaultManagerFixture.sol";

import {SmartVaultYieldManager} from "src/SmartVaultYieldManager.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {FullMath} from "src/uniswap/FullMath.sol";
import {IUniswapV3Pool} from "src/interfaces/IUniswapV3Pool.sol";

import {MockSwapRouter} from "src/test_utils/MockSwapRouter.sol";
import {UniProxyMock} from "src/test_utils/UniProxyMock.sol";
import {MockUniswapFactory} from "src/test_utils/MockUniswapFactory.sol";
import {MockRamsesFactory} from "src/test_utils/MockRamsesFactory.sol";
import {MockRamsesPool} from "src/test_utils/MockRamsesPool.sol";

contract SmartVaultYieldManagerFixture is SmartVaultManagerFixture {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeERC20 for IERC20;

    SmartVaultYieldManager yieldManager;

    function setUp() public virtual override {
        super.setUp();

        UniProxyMock uniProxy = new UniProxyMock();
        MockSwapRouter ramsesRouter = new MockSwapRouter();

        {
            MockRamsesPool impl = new MockRamsesPool();
            MockRamsesFactory ramsesFactory = new MockRamsesFactory(address(impl));
            ramsesRouter.setFactory(address(ramsesFactory));
            address pool = ramsesFactory.deploy(address(usds), address(usdc));
            // vm.label(pool, "USDs/USDC Ramses Pool"); // TODO: investigate why medusa doesn't like this
            MockRamsesPool(pool).setPrice(_calcSqrtX96(address(usds), address(usdc), 1));
        }

        // uni proxy ratios
        uniProxy.setRatio(address(usdsHypervisor), address(usdc), 10 ** (18 + usds.decimals() - usdc.decimals())); // 1:1
        uniProxy.setRatio(
            address(wbtcHypervisor),
            address(wbtc),
            DEFAULT_WBTC_ETH_MULTIPLIER * 10 ** (18 + weth.decimals() - wbtc.decimals())
        ); // 1:25
        uniProxy.setRatio(
            address(wbtcHypervisor),
            address(weth),
            10 ** (18 + wbtc.decimals() - weth.decimals()) / DEFAULT_WBTC_ETH_MULTIPLIER
        ); // 25:1
        uniProxy.setRatio(
            address(linkHypervisor),
            address(link),
            10 ** (18 + weth.decimals() - link.decimals()) / DEFAULT_LINK_ETH_DIVISOR
        ); // 200:1
        uniProxy.setRatio(
            address(linkHypervisor),
            address(weth),
            DEFAULT_LINK_ETH_DIVISOR * 10 ** (18 + weth.decimals() - link.decimals())
        ); // 1:200

        // ramses router rates: usds <-> usdc
        ramsesRouter.setRate(address(usds), address(usdc), 10 ** (18 + usdc.decimals() - usds.decimals())); // 1:1
        ramsesRouter.setRate(address(usdc), address(usds), 10 ** (18 + usds.decimals() - usdc.decimals())); // 1:1
        {
            MockUniswapFactory uniFactory = new MockUniswapFactory();
            uniswapRouter.setFactory(address(uniFactory));

            // uniswap router rates: weth/wbtc/link <-> usdc
            uniswapRouter.setRate(
                address(weth), address(usdc), DEFAULT_ETH_USD_PRICE * 10 ** (18 + usdc.decimals() - weth.decimals())
            ); // 2500000000: 1 WETH <-> 2500 USDC ✅ exactInput/Output
            uniswapRouter.setRate(
                address(usdc), address(weth), 10 ** (18 + weth.decimals() - usdc.decimals()) / DEFAULT_ETH_USD_PRICE
            ); // 400000000000000000000000000: 2500 USDC <-> 1 WETH ✅ exactInput/Output

            address wethUsdcPool = uniFactory.deploy(address(weth), address(usdc), UNISWAP_FEE);
            IUniswapV3Pool(wethUsdcPool).initialize(_calcSqrtX96(address(usdc), address(weth), DEFAULT_ETH_USD_PRICE));

            uniswapRouter.setRate(
                address(wbtc),
                address(usdc),
                DEFAULT_ETH_USD_PRICE * DEFAULT_WBTC_ETH_MULTIPLIER * 10 ** (18 + usdc.decimals() - wbtc.decimals())
            ); // 625000000000000000000: 1 WBTC <-> 62500 USDC ✅ exactInput/Output
            uniswapRouter.setRate(
                address(usdc),
                address(wbtc),
                10 ** (18 + wbtc.decimals() - usdc.decimals()) / (DEFAULT_ETH_USD_PRICE * DEFAULT_WBTC_ETH_MULTIPLIER)
            ); // 1600000000000000: 62500 USDC <-> 1 WBTC ✅ exactInput/Output
            address usdcWbtcPool = uniFactory.deploy(address(usdc), address(wbtc), UNISWAP_FEE);
            IUniswapV3Pool(usdcWbtcPool).initialize(
                _calcSqrtX96(address(usdc), address(wbtc), DEFAULT_ETH_USD_PRICE * DEFAULT_WBTC_ETH_MULTIPLIER)
            );

            uniswapRouter.setRate(
                address(link),
                address(usdc),
                DEFAULT_ETH_USD_PRICE * 10 ** (18 + usdc.decimals() - link.decimals()) / DEFAULT_LINK_ETH_DIVISOR
            ); // 12500000: 1 LINK <-> 12.5 USDC ✅ exactInput/Output
            uniswapRouter.setRate(
                address(usdc),
                address(link),
                DEFAULT_LINK_ETH_DIVISOR * 10 ** (18 + link.decimals() - usdc.decimals()) / DEFAULT_ETH_USD_PRICE
            ); // 80000000000000000000000000000: 12.5 USDC <-> 1 LINK ✅ exactInput/Output
            address usdcLinkPool = uniFactory.deploy(address(usdc), address(link), UNISWAP_FEE);
            IUniswapV3Pool(usdcLinkPool).initialize(
                _calcSqrtX96(address(usdc), address(link), DEFAULT_ETH_USD_PRICE / DEFAULT_LINK_ETH_DIVISOR)
            );

            // uniswap router rates: wbtc/link <-> weth
            uniswapRouter.setRate(
                address(wbtc),
                address(weth),
                DEFAULT_WBTC_ETH_MULTIPLIER * 10 ** (18 + weth.decimals() - wbtc.decimals())
            ); // 250000000000000000000000000000: 1 WBTC <-> 25 WETH ✅ exactInput/Output
            uniswapRouter.setRate(
                address(weth),
                address(wbtc),
                10 ** (18 + wbtc.decimals() - weth.decimals()) / (DEFAULT_WBTC_ETH_MULTIPLIER)
            ); // 4000000: 25 WETH <-> 1 WBTC ✅ exactInput/Output
            address wbtcWethPool = uniFactory.deploy(address(wbtc), address(weth), UNISWAP_FEE);
            IUniswapV3Pool(wbtcWethPool).initialize(
                _calcSqrtX96(address(weth), address(wbtc), DEFAULT_WBTC_ETH_MULTIPLIER)
            );

            uniswapRouter.setRate(
                address(link), address(weth), 10 ** (18 + weth.decimals() - link.decimals()) / DEFAULT_LINK_ETH_DIVISOR
            ); // 5000000000000000: 200 LINK <-> 1 WETH ✅ exactInput/Output
            uniswapRouter.setRate(
                address(weth), address(link), DEFAULT_LINK_ETH_DIVISOR * 10 ** (18 + link.decimals() - weth.decimals())
            ); // 200000000000000000000: 1 WETH <-> 200 LINK ✅ exactInput/Output
            address linkWethPool = uniFactory.deploy(address(link), address(weth), UNISWAP_FEE);
            IUniswapV3Pool(linkWethPool).initialize(
                _calcSqrtX96(address(link), address(weth), DEFAULT_LINK_ETH_DIVISOR)
            );
        }
        // mint tokens ($25M worth of each) to swap routers
        uint256 usdsAmount = 25_000_000 * 10 ** usds.decimals();
        uint256 usdcAmount = 25_000_000 * 10 ** usdc.decimals();
        uint256 wbtcAmount = 400 * 10 ** wbtc.decimals();
        uint256 wethAmount = 10_000 * 10 ** weth.decimals();
        uint256 linkAmount = 2_000_000 * 10 ** link.decimals();

        usds.grantRole(usds.MINTER_ROLE(), address(this));
        usds.mint(address(ramsesRouter), 25_000_000 * 10 ** usds.decimals());
        usdc.mint(address(ramsesRouter), 25_000_000 * 10 ** usdc.decimals());
        usdc.mint(address(uniswapRouter), 25_000_000 * 10 ** usdc.decimals());
        weth.mint(address(uniswapRouter), 10_000 * 10 ** weth.decimals());
        vm.deal(address(weth), address(weth).balance + 10_000 * 10 ** weth.decimals());
        wbtc.mint(address(uniswapRouter), 400 * 10 ** wbtc.decimals());
        link.mint(address(uniswapRouter), 2_000_000 * 10 ** link.decimals());

        // deposit tokens (based on the rates) to hypervisors and burn tokens to ensure the rates are correct
        // and these underlying tokens remain in the hypervisors when testing yield manager withdrawal logic
        // NOTE: this is part of a workaround for the _swapToRatio() logic in the yield manager
        IERC20(address(usds)).safeApprove(address(usdsHypervisor), usdsAmount);
        IERC20(address(usdc)).safeApprove(address(usdsHypervisor), usdcAmount);
        IERC20(address(wbtc)).safeApprove(address(wbtcHypervisor), wbtcAmount);
        IERC20(address(weth)).safeApprove(address(wbtcHypervisor), wethAmount);
        IERC20(address(link)).safeApprove(address(linkHypervisor), linkAmount);
        IERC20(address(weth)).safeApprove(address(linkHypervisor), wethAmount);

        usds.mint(address(this), usdsAmount);
        usdc.mint(address(this), usdcAmount);
        wbtc.mint(address(this), wbtcAmount);
        weth.mint(address(this), 2 * wethAmount);
        vm.deal(address(weth), address(weth).balance + 2 * wethAmount);
        link.mint(address(this), linkAmount);

        uniProxy.deposit(
            usdsAmount,
            usdcAmount,
            address(0xDEAD),
            address(usdsHypervisor),
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        );
        uniProxy.deposit(
            wbtcAmount,
            wethAmount,
            address(0xDEAD),
            address(wbtcHypervisor),
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        );
        uniProxy.deposit(
            linkAmount,
            wethAmount,
            address(0xDEAD),
            address(linkHypervisor),
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        );

        yieldManager = new SmartVaultYieldManager(
            address(usds),
            address(usdc),
            address(weth),
            address(uniProxy),
            address(ramsesRouter),
            address(usdsHypervisor),
            address(uniswapRouter)
        );

        // add hypervisor data
        for (uint256 i; i < collateralSymbols.length(); i++) {
            if (collateralSymbols.at(i) == NATIVE) continue;

            CollateralData memory collateral = collateralData[collateralSymbols.at(i)];
            yieldManager.addHypervisorData(
                address(collateral.token),
                address(collateral.hypervisor),
                UNISWAP_FEE,
                collateral.pathToUsdc,
                collateral.pathFromUsdc
            );
        }

        // set fee data
        yieldManager.setFeeData(PROTOCOL_FEE_RATE, address(smartVaultManager));

        // set yield manager
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setYieldManager(address(yieldManager));
    }

    function _calcSqrtX96(address tokenA, address tokenB, uint256 ratio) internal view returns (uint160) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bool aIs0 = tokenA == token0;

        uint256 price = aIs0
            ? FullMath.mulDiv(ratio * 10 ** ERC20(token1).decimals(), 1 << 192, 10 ** ERC20(token0).decimals())
            : FullMath.mulDiv(10 ** ERC20(token1).decimals(), 1 << 192, ratio * 10 ** ERC20(token0).decimals());

        return uint160(FullMath.sqrt(price));
    }
}

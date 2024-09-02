// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Common} from "./Common.sol";

import {SmartVaultYieldManager} from "src/SmartVaultYieldManager.sol";

import {MockSwapRouter} from "src/test_utils/MockSwapRouter.sol";
import {UniProxyMock} from "src/test_utils/UniProxyMock.sol";

contract SmartVaultYieldManagerFixture is Common {
    SmartVaultYieldManager yieldManager;

    function setUp() public virtual override {
        // avoid duplicate invocations by inheriting contracts
        if (collateralSymbols.length == 0) {
            super.setUp();
        }

        UniProxyMock uniProxy = new UniProxyMock();
        MockSwapRouter ramsesRouter = new MockSwapRouter();

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
        ramsesRouter.setRate(address(usds), address(usdc), (18 + usdc.decimals() - usds.decimals())); // 1:1
        ramsesRouter.setRate(address(usdc), address(usds), (18 + usds.decimals() - usdc.decimals())); // 1:1

        // uniswap router rates: weth/wbtc/link <-> usdc
        uniswapRouter.setRate(
            address(weth), address(usdc), DEFAULT_ETH_USD_PRICE * 10 ** (18 + usdc.decimals() - weth.decimals())
        ); // 2500000000: 1 WETH <-> 2500 USDC ✅ exactInput/Output
        uniswapRouter.setRate(
            address(usdc), address(weth), 10 ** (18 + weth.decimals() - usdc.decimals()) / DEFAULT_ETH_USD_PRICE
        ); // 400000000000000000000000000: 2500 USDC <-> 1 WETH ✅ exactInput/Output
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

        // uniswap router rates: wbtc/link <-> weth
        uniswapRouter.setRate(
            address(wbtc), address(weth), DEFAULT_WBTC_ETH_MULTIPLIER * 10 ** (18 + weth.decimals() - wbtc.decimals())
        ); // 250000000000000000000000000000: 1 WBTC <-> 25 WETH ✅ exactInput/Output
        uniswapRouter.setRate(
            address(weth), address(wbtc), 10 ** (18 + wbtc.decimals() - weth.decimals()) / (DEFAULT_WBTC_ETH_MULTIPLIER)
        ); // 4000000: 25 WETH <-> 1 WBTC ✅ exactInput/Output
        uniswapRouter.setRate(
            address(link), address(weth), 10 ** (18 + weth.decimals() - link.decimals()) / DEFAULT_LINK_ETH_DIVISOR
        ); // 5000000000000000: 200 LINK <-> 1 WETH ✅ exactInput/Output
        uniswapRouter.setRate(
            address(weth), address(link), DEFAULT_LINK_ETH_DIVISOR * 10 ** (18 + link.decimals() - weth.decimals())
        ); // 200000000000000000000: 1 WETH <-> 200 LINK ✅ exactInput/Output

        // mint tokens ($25M worth of each) to swap routers
        usds.grantRole(usds.MINTER_ROLE(), address(this));
        usds.mint(address(ramsesRouter), 25_000_000 * 10 ** usds.decimals());
        usdc.mint(address(ramsesRouter), 25_000_000 * 10 ** usdc.decimals());
        usdc.mint(address(uniswapRouter), 25_000_000 * 10 ** usdc.decimals());
        weth.mint(address(uniswapRouter), 10_000 * 10 ** weth.decimals());
        wbtc.mint(address(uniswapRouter), 400 * 10 ** wbtc.decimals());
        link.mint(address(uniswapRouter), 2_000_000 * 10 ** link.decimals());

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
        for (uint256 i; i < collateralSymbols.length; i++) {
            if (collateralSymbols[i] == NATIVE) continue;

            CollateralData memory collateral = collateralData[collateralSymbols[i]];
            yieldManager.addHypervisorData(
                address(collateral.token),
                address(collateral.hypervisor),
                UNISWAP_FEE,
                collateral.pathToUsdc,
                collateral.pathFromUsdc
            );
        }
    }
}

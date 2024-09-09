// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@chimera/Hevm.sol";

import {SmartVaultManagerFixture} from "./SmartVaultManagerFixture.sol";

import {SmartVaultYieldManager} from "src/SmartVaultYieldManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MockSwapRouter} from "src/test_utils/MockSwapRouter.sol";
import {UniProxyMock} from "src/test_utils/UniProxyMock.sol";

contract SmartVaultYieldManagerFixture is SmartVaultManagerFixture {
    using SafeERC20 for IERC20;

    SmartVaultYieldManager yieldManager;

    function setUp() public virtual override {
        super.setUp();

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
        ramsesRouter.setRate(address(usds), address(usdc), 10 ** (18 + usdc.decimals() - usds.decimals())); // 1:1
        ramsesRouter.setRate(address(usdc), address(usds), 10 ** (18 + usds.decimals() - usdc.decimals())); // 1:1

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

        // set fee data
        yieldManager.setFeeData(PROTOCOL_FEE_RATE, address(smartVaultManager));

        // set yield manager
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setYieldManager(address(yieldManager));
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@chimera/Hevm.sol";

import {MockWETH} from "src/test_utils/MockWETH.sol";
import {USDsMock} from "src/test_utils/USDsMock.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";
import {ChainlinkMock} from "src/test_utils/ChainlinkMock.sol";
import {HypervisorMock} from "src/test_utils/HypervisorMock.sol";
import {MockSwapRouter} from "src/test_utils/MockSwapRouter.sol";

contract Common {
    // Actors
    address VAULT_OWNER = _makeAddr("Vault owner");
    address VAULT_MANAGER_OWNER = _makeAddr("Vault manager owner");
    address PROTOCOL = _makeAddr("Protocol");
    address LIQUIDATOR = _makeAddr("Liquidator");

    // Constants
    bytes32 constant NATIVE = "ETH";
    uint256 constant DEFAULT_ETH_USD_PRICE = 2500;
    uint256 constant DEFAULT_WBTC_ETH_MULTIPLIER = 25;
    uint256 constant DEFAULT_LINK_ETH_DIVISOR = 200;
    uint256 constant COLLATERAL_RATE = 110_000; // 110%
    uint256 constant PROTOCOL_FEE_RATE = 500; // 0.5%
    uint24 constant UNISWAP_FEE = 500; // 0.05%
    uint24 constant RAMSES_FEE = 3000; // 0.3%
    uint16 constant VAULT_LIMIT = 10;

    // Mocks
    USDsMock usds;
    ERC20Mock usdc;
    MockWETH weth;
    ERC20Mock wbtc;
    ERC20Mock link;
    ChainlinkMock clNativeUsd;
    ChainlinkMock clWbtcUsd;
    ChainlinkMock clLinkUsd;
    HypervisorMock usdsHypervisor;
    HypervisorMock wbtcHypervisor;
    HypervisorMock linkHypervisor;
    MockSwapRouter uniswapRouter;

    // State
    struct CollateralData {
        ERC20Mock token;
        ChainlinkMock clFeed;
        HypervisorMock hypervisor;
        bytes pathToUsdc;
        bytes pathFromUsdc;
    }

    bytes32[] collateralSymbols;
    ERC20Mock[] collateralTokens; // TODO: probably not needed
    mapping(bytes32 => CollateralData) collateralData;

    function setUp() public virtual {
        usds = new USDsMock();
        usdc = new ERC20Mock("USD Coin", "USDC", 6); // NOTE: USDC cannot be a collateral token due to being paired with USDs

        // collateral tokens
        // NOTE: push NATIVE symbol to the collateralSymbols array but not the collateralTokens array as it is handled separately using address(0)
        collateralSymbols.push(NATIVE);

        weth = new MockWETH();
        collateralSymbols.push(bytes32(bytes(weth.symbol())));
        collateralTokens.push(weth);

        string memory wbtcSymbol = "WBTC";
        wbtc = new ERC20Mock("Wrapped Bitcoin", wbtcSymbol, 8);
        collateralSymbols.push(bytes32(bytes(wbtcSymbol)));
        collateralTokens.push(wbtc);

        string memory linkSymbol = "LINK";
        link = new ERC20Mock("Chainlink", linkSymbol, 18);
        collateralSymbols.push(bytes32(bytes(linkSymbol)));
        collateralTokens.push(link);

        // chainlink feeds
        clNativeUsd = new ChainlinkMock("ETH/USD");
        clNativeUsd.setPrice(int256(DEFAULT_ETH_USD_PRICE * 10 ** clNativeUsd.decimals())); // $2,500

        clWbtcUsd = new ChainlinkMock("WBTC/USD");
        clWbtcUsd.setPrice(int256(DEFAULT_ETH_USD_PRICE * DEFAULT_WBTC_ETH_MULTIPLIER * 10 ** clWbtcUsd.decimals())); // $62,500

        clLinkUsd = new ChainlinkMock("LINK/USD");
        clLinkUsd.setPrice(int256(DEFAULT_ETH_USD_PRICE * 10 ** clLinkUsd.decimals() / DEFAULT_LINK_ETH_DIVISOR)); // $12.5

        // gamma vaults
        usdsHypervisor = new HypervisorMock("USDs-USDC", "USDs-USDC", address(usds), address(usdc));
        wbtcHypervisor = new HypervisorMock("WBTC-WETH", "WBTC-WETH", address(wbtc), address(weth));
        linkHypervisor = new HypervisorMock("LINK-WETH", "LINK-WETH", address(link), address(weth));

        // collateral data
        collateralData[NATIVE] = CollateralData(
            ERC20Mock(address(0)),
            clNativeUsd,
            wbtcHypervisor,
            abi.encode(address(weth), RAMSES_FEE, address(usdc)),
            abi.encode(address(usdc), RAMSES_FEE, address(weth))
        ); // wbtcHypervisor because all native token gets converted to its wrapped equivalent. TODO: probably could just remove this and related checks
        collateralData[bytes32(bytes(weth.symbol()))] = CollateralData(
            weth,
            clNativeUsd,
            wbtcHypervisor,
            abi.encode(address(weth), RAMSES_FEE, address(usdc)),
            abi.encode(address(usdc), RAMSES_FEE, address(weth))
        );
        collateralData[bytes32(bytes(wbtcSymbol))] = CollateralData(
            wbtc,
            clWbtcUsd,
            wbtcHypervisor,
            abi.encode(address(wbtc), RAMSES_FEE, address(usdc)),
            abi.encode(address(usdc), RAMSES_FEE, address(wbtc))
        );
        collateralData[bytes32(bytes(linkSymbol))] = CollateralData(
            link,
            clLinkUsd,
            linkHypervisor,
            abi.encode(address(link), RAMSES_FEE, address(usdc)),
            abi.encode(address(usdc), RAMSES_FEE, address(link))
        );

        // swap router
        uniswapRouter = new MockSwapRouter();
    }

    // create our own version of this forge-std cheat to avoid linearization issues in invariant scaffolding
    function _makeAddr(string memory name) internal virtual returns (address addr) {
        addr = vm.addr(uint256(keccak256(abi.encodePacked(name))));
        vm.label(addr, name);
    }
}

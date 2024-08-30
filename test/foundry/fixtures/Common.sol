// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@chimera/Hevm.sol";

import {MockSwapRouter} from "src/test_utils/MockSwapRouter.sol";
import {MockWETH} from "src/test_utils/MockWETH.sol";
import {USDsMock} from "src/test_utils/USDsMock.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";
import {ChainlinkMock} from "src/test_utils/ChainlinkMock.sol";

contract Common {
    // Actors
    address VAULT_OWNER = _makeAddr("Vault owner");
    address VAULT_MANAGER_OWNER = _makeAddr("Vault manager owner");
    address PROTOCOL = _makeAddr("Protocol");
    address LIQUIDATOR = _makeAddr("Liquidator");

    // Constants
    bytes32 constant NATIVE = "ETH";
    uint256 constant COLLATERAL_RATE = 110_000;
    uint256 constant FEE_RATE = 500;
    uint16 constant VAULT_LIMIT = 10;

    // Mocks
    USDsMock internal usds;
    ERC20Mock internal usdc;
    MockWETH internal weth;
    ChainlinkMock internal clNativeUsd;
    MockSwapRouter internal uniswapRouter;

    function setUp() public virtual {
        usds = new USDsMock();
        usdc = new ERC20Mock("USDC", "USDC", 6);
        weth = new MockWETH();

        uniswapRouter = new MockSwapRouter();

        clNativeUsd = new ChainlinkMock("ETH/USD");
        clNativeUsd.setPrice(2000_0000_0000);
    }

    // create our own version of this forge-std cheat to avoid linearization issues
    function _makeAddr(string memory name) internal virtual returns (address addr) {
        addr = vm.addr(uint256(keccak256(abi.encodePacked(name))));
        vm.label(addr, name);
    }
}

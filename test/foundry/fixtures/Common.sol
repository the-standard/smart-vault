// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {MockSwapRouter} from "src/test_utils/MockSwapRouter.sol";
import {MockWETH} from "src/test_utils/MockWETH.sol";
import {USDsMock} from "src/test_utils/USDsMock.sol";

contract Common is Test {
    // Actors
    address VAULT_OWNER = makeAddr("Vault owner");
    address VAULT_MANAGER_OWNER = makeAddr("Vault manager owner");
    address PROTOCOL = makeAddr("Protocol");
    address LIQUIDATOR = makeAddr("Liquidator");

    // Constants
    bytes32 constant NATIVE = "ETH";
    uint256 constant COLLATERAL_RATE = 110_000;
    uint256 constant FEE_RATE = 500;
    uint16 constant USER_VAULT_LIMIT = 10;

    // Mocks
    USDsMock internal usds;
    MockWETH internal weth;
    MockSwapRouter internal uniswapRouter;

    function setUp() public virtual {
        usds = new USDsMock();
        weth = new MockWETH();
        uniswapRouter = new MockSwapRouter();
    }
}

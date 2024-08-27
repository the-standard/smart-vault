// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Common} from "./Common.sol";

import {SmartVaultYieldManager} from "src/SmartVaultYieldManager.sol";

import {HypervisorMock} from "src/test_utils/HypervisorMock.sol";
import {MockSwapRouter} from "src/test_utils/MockSwapRouter.sol";
import {UniProxyMock} from "src/test_utils/UniProxyMock.sol";

contract SmartVaultYieldManagerFixture is Common {
    SmartVaultYieldManager internal yieldManager;

    function setUp() public virtual override {
        super.setUp();

        UniProxyMock uniProxy = new UniProxyMock();
        MockSwapRouter ramsesRouter = new MockSwapRouter();
        HypervisorMock usdsHypervisor = new HypervisorMock("USDs-USDC", "USDs-USDC", address(usds), address(usdc));

        yieldManager = new SmartVaultYieldManager(
            address(usds),
            address(usdc),
            address(weth),
            address(uniProxy),
            address(ramsesRouter),
            address(usdsHypervisor),
            address(uniswapRouter)
        );
    }
}

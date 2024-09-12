// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {ISwapToRatio, SwapToRatioOld, SwapToRatioNew, SwapToRatioPython} from "./SwapToRatio.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";
import {HypervisorMock} from "src/test_utils/HypervisorMock.sol";
import {UniProxyMock} from "src/test_utils/UniProxyMock.sol";
import {MockSwapRouter, ISwapRouter} from "src/test_utils/MockSwapRouter.sol";

import {TickMath} from "contracts/uniswap/TickMath.sol";

import "contracts/uniswap/FullMath.sol";

import {Test, console} from "forge-std/Test.sol";

contract SwapToRatioTest is Test {
    ISwapToRatio oldImpl;
    ISwapToRatio newImpl;
    ISwapToRatio pythonImpl;

    UniProxyMock uniProxy;
    HypervisorMock hypervisor;
    MockSwapRouter swapRouter;
    ERC20Mock tokenA;
    ERC20Mock tokenB;

    function setUp() public {
        uniProxy = new UniProxyMock();
        tokenA = new ERC20Mock("TokenA", "TKNA", 18);
        tokenB = new ERC20Mock("TokenB", "TKNB", 18);
        vm.label(address(tokenA), "TokenA");
        vm.label(address(tokenB), "TokenB");

        hypervisor = new HypervisorMock("TokenA-TokenB", "TKNA-TKNB", address(tokenA), address(tokenB));
        swapRouter = new MockSwapRouter();
        uint24 swapFee = 500;

        oldImpl = new SwapToRatioOld(address(uniProxy), address(hypervisor), address(swapRouter), swapFee);
        newImpl = new SwapToRatioNew(address(uniProxy), address(hypervisor), address(swapRouter), swapFee);
        pythonImpl = new SwapToRatioPython(address(uniProxy), address(hypervisor), address(swapRouter), swapFee);
    }

    function setUpState(uint160 _sqrtPriceX96, uint256 _tokenABalance, uint256 _tokenBBalance, uint256 _ratio)
        internal
        returns (uint160 _boundedSqrtPriceX96)
    {

        // Ensure _sqrtPriceX96 is within uniswap limits
        //_boundedSqrtPriceX96 = uint160(bound(uint256(_sqrtPriceX96), 4295128739, 1461446703485210103287273052203988822378723970342));
        _boundedSqrtPriceX96 = uint160(bound(uint256(_sqrtPriceX96), 4295128739, 3e37));

        uint256 priceX192 = uint256(_sqrtPriceX96) * uint256(_sqrtPriceX96);
        console.log("price: %s, ratio %s", FullMath.mulDiv(1e18, priceX192, 1 << 192), _ratio);

        // Calculate priceX192 based on _boundedSqrtPriceX96

        // Calculate the price of token A in terms of token B using priceX192, normalized to 18 decimals
        uint256 price18 = FullMath.mulDiv(1e18, priceX192, 1 << 192);
        uint256 inversePrice18  = FullMath.mulDiv(1e18, 1 << 192, priceX192);

        // Set the ratio in the proxy and router
        uniProxy.setRatio(address(hypervisor), address(tokenA), _ratio);
        swapRouter.setSqrtRate(address(tokenA), address(tokenB), _boundedSqrtPriceX96);
        swapRouter.setRate(address(tokenA), address(tokenB), price18);
        swapRouter.setRate(address(tokenB), address(tokenA), inversePrice18);

        // Mint balances for both tokens to swapRouter to facilitate swaps
        uint256 swapRouterBalanceA = type(uint128).max;
        tokenA.mint(address(swapRouter), swapRouterBalanceA);
        // Adjust token B balances according to the derived ratio
        tokenB.mint(address(swapRouter), FullMath.mulDiv(swapRouterBalanceA, _ratio, 10 ** tokenA.decimals()));

        // Bound token balances to avoid swapping more than the swap router has available
        uint256 _boundedTokenABalance = bound(_tokenABalance, 10 ** tokenA.decimals(), type(uint88).max);
        uint256 _boundedTokenBBalance = bound(_tokenBBalance, 10 ** tokenB.decimals(), type(uint88).max);

        // Mint balances for both tokens to the old and new implementations
        tokenA.mint(address(oldImpl), _boundedTokenABalance);
        tokenB.mint(address(oldImpl), _boundedTokenBBalance);
        tokenA.mint(address(newImpl), _boundedTokenABalance);
        tokenB.mint(address(newImpl), _boundedTokenBBalance);
        tokenA.mint(address(pythonImpl), _boundedTokenABalance);
        tokenB.mint(address(pythonImpl), _boundedTokenBBalance);
    }

    function getPriceAtTick(int24 tick) public pure returns (uint256) {
        uint160 sqrtPrice = TickMath.getSqrtRatioAtTick(tick);
        uint256 priceX192 = uint256(sqrtPrice) * uint256(sqrtPrice);
        return FullMath.mulDiv(1e18, priceX192, 1 << 192);
    }

    function test_swapToRatioFuzz(
        uint256 tick,
        uint256 ratioTick,
        uint256 _tokenABalance,
        uint256 _tokenBBalance
    ) public {
        int24 boundedTick = int24(int256(bound(tick, 0, 300_000*2))) - 300_000;
        int24 boundedRatioTick = int24(int256(bound(ratioTick, 0, 100_000*2))) - 100_000;

        // int24 boundedTick = 0;
        // int24 boundedRatioTick = 0;

        console.log("max price: %s, min price: %s", getPriceAtTick(300_000), getPriceAtTick(-300_000));
        console.log("max ratio %s, min ratio: %s", getPriceAtTick(100_000), getPriceAtTick(-100_000));

        uint160 _sqrtPriceX96 = TickMath.getSqrtRatioAtTick(boundedTick);
        uint256 _ratio = getPriceAtTick(boundedRatioTick);
        uint160 _boundedSqrtPriceX96 = setUpState(_sqrtPriceX96, _tokenABalance, _tokenBBalance, _ratio);

        // Snapshot the state of the VM to revert to after each call
        uint256 snapshotId = vm.snapshot();

        // Call the old implementation to swap to the ratio
        (bool successOld, bytes memory returnDataOld) = swapToRatioOld(tokenA, tokenB);

        // Revert the state of the VM to the snapshot taken before the previous call
        vm.revertTo(snapshotId);

        // Call the new implementation to swap to the ratio
        (bool successNew, bytes memory returnDataNew) = swapToRatioNew(tokenA, tokenB, _boundedSqrtPriceX96);

        // Revert the state of the VM to the snapshot taken before both calls (this isn't strictly necessary)
        vm.revertTo(snapshotId);

        // Assert that the old and new implementations have the same success status
        if (successOld && successNew) {
            // Retrieve the balances of the old implementation from JSON
            (uint256 oldTokenABalance, uint256 oldTokenBBalance) = abi.decode(
                vm.parseJson(vm.readFile("test/foundry/differential/balances.json"), ".oldImpl"), (uint256, uint256)
            );
            // Retrieve the balances of the new implementation from JSON
            (uint256 newTokenABalance, uint256 newTokenBBalance) = abi.decode(
                vm.parseJson(vm.readFile("test/foundry/differential/balances.json"), ".newImpl"), (uint256, uint256)
            );

            console.log("oldTokenABalance", oldTokenABalance);
            console.log("oldTokenBBalance", oldTokenBBalance);
            console.log("newTokenABalance", newTokenABalance);
            console.log("newTokenBBalance", newTokenBBalance);

            // ratio passed in is reversed in uniProxy, hence B over A here
            assertApproxEqAbs(_ratio, (oldTokenBBalance * 1e18) / oldTokenABalance , (_ratio) / 1000, "old wrong");
            assertApproxEqAbs(_ratio, (newTokenBBalance * 1e18) / newTokenABalance , (_ratio) / 1000, "new wrong");
        } else if (!successOld && successNew) {
            console.log("old implementation reverted when the new one did not");
            // this is fine – new implementation is more robust
            (uint256 newTokenABalance, uint256 newTokenBBalance) = abi.decode(
                vm.parseJson(vm.readFile("test/foundry/differential/balances.json"), ".newImpl"), (uint256, uint256)
            );
            console.log("newTokenABalance", newTokenABalance);
            console.log("newTokenBBalance", newTokenBBalance);

            assertApproxEqAbs(_ratio, (newTokenBBalance * 1e18) / newTokenABalance , (_ratio) / 100, "new wrong");
        } else if (successOld && !successNew) {
            // this is bad – new implementation is less robust
            assertTrue(false, "new implementation should not revert when old one does not");
        } else {
            assertEq(keccak256(returnDataOld), keccak256(returnDataNew), "revert reasons should match");
        }
        _resetJSON();
    }

    // Run with forge test --mt test_swapToRatioFuzzPython -vvv --ffi
    function test_xxswapToRatioFuzzPython(
        uint160 _sqrtPriceX96,
        uint256 _tokenABalance,
        uint256 _tokenBBalance
    ) public {
        uint160 _boundedSqrtPriceX96 = setUpState(_sqrtPriceX96, _tokenABalance, _tokenBBalance, 0.5e18);

        // Snapshot the state of the VM to revert to after each call
        uint256 snapshotId = vm.snapshot();

        // Call the old implementation to swap to the ratio
        swapToRatioOld(tokenA, tokenB);

        // Revert the state of the VM to the snapshot taken before the previous call
        vm.revertTo(snapshotId);

        // Cache the balances before calling the new implementation
        uint256 cachedBalanceA = tokenA.balanceOf(address(newImpl));
        uint256 cachedBalanceB = tokenB.balanceOf(address(newImpl));

        // Call the new implementation to swap to the ratio
        (bool successNew,) = swapToRatioNew(tokenA, tokenB, _boundedSqrtPriceX96);

        // Revert the state of the VM to the snapshot taken before the previous call
        vm.revertTo(snapshotId);

        // Call the Python implementation to swap to the ratio
        (bool successPython,) = swapToRatioPython(tokenA, _boundedSqrtPriceX96);

        // Revert the state of the VM to the snapshot taken before the call (this isn't strictly necessary)
        vm.revertTo(snapshotId);

        if (successNew && successPython) {
            // Retrieve the balances of the old implementation from JSON
            (uint256 oldTokenABalance, uint256 oldTokenBBalance) = abi.decode(
                vm.parseJson(vm.readFile("test/foundry/differential/balances.json"), ".oldImpl"), (uint256, uint256)
            );

            // Retrieve the balances of the new implementation from JSON
            (uint256 newTokenABalance, uint256 newTokenBBalance) = abi.decode(
                vm.parseJson(vm.readFile("test/foundry/differential/balances.json"), ".newImpl"), (uint256, uint256)
            );

            // Retrieve the balances of the new implementation from JSON
            (uint256 pythonDeltaA, uint256 pythonDeltaB) = abi.decode(
                vm.parseJson(vm.readFile("test/foundry/differential/balances.json"), ".pythonImpl"), (uint256, uint256)
            );

            console.log("oldTokenABalance", oldTokenABalance);
            console.log("oldTokenBBalance", oldTokenBBalance);
            console.log("newTokenABalance", newTokenABalance);
            console.log("newTokenBBalance", newTokenBBalance);
            console.log("pythonDeltaA", pythonDeltaA);
            console.log("pythonDeltaB", pythonDeltaB);
            console.log("cachedBalanceA", cachedBalanceA);
            console.log("cachedBalanceB", cachedBalanceB);
            console.log("cachedBalanceA - newTokenABalance", cachedBalanceA - newTokenABalance);
            console.log("newTokenBBalance - cachedBalanceB", newTokenBBalance - cachedBalanceB);

            // Assert more of tokenA was able to be swapped
            assertLe(newTokenABalance, oldTokenABalance);
            assertGe(newTokenBBalance, oldTokenBBalance);

            // Assert that the new Solidity and Python implementations are equal within 1% to account for rounding errors
            if (pythonDeltaA != 0 && pythonDeltaB != 0) {
                assertApproxEqRel(pythonDeltaA, cachedBalanceA - newTokenABalance, 1e16);
                assertApproxEqRel(pythonDeltaB, newTokenBBalance - cachedBalanceB, 1e16);
            }
        }
        _resetJSON();
    }

    function swapToRatioOld(ERC20Mock _tokenA, ERC20Mock _tokenB)
        internal
        returns (bool successOld, bytes memory returnDataOld)
    {
        (successOld, returnDataOld) = address(oldImpl).call(abi.encodeCall(oldImpl._swapToRatio, address(_tokenA)));

        // If successful, cache the resulting balances
        if (successOld) {
            string memory path = "test/foundry/differential/balances.json";
            assertTrue(vm.exists(path));
            vm.writeJson(vm.toString(_tokenA.balanceOf(address(oldImpl))), path, ".oldImpl.tokenA");
            vm.writeJson(vm.toString(_tokenB.balanceOf(address(oldImpl))), path, ".oldImpl.tokenB");
        }
    }

    function swapToRatioNew(ERC20Mock _tokenA, ERC20Mock _tokenB, uint160 _sqrtPriceX96)
        internal
        returns (bool successNew, bytes memory returnDataNew)
    {
        (successNew, returnDataNew) = address(newImpl).call(
            abi.encodeCall(SwapToRatioNew(address(newImpl))._swapToRatioMockPriceX96, (address(_tokenA), _sqrtPriceX96))
        );

        // If successful, cache the resulting balances
        if (successNew) {
            string memory path = "test/foundry/differential/balances.json";
            assertTrue(vm.exists(path));
            vm.writeJson(vm.toString(_tokenA.balanceOf(address(newImpl))), path, ".newImpl.tokenA");
            vm.writeJson(vm.toString(_tokenB.balanceOf(address(newImpl))), path, ".newImpl.tokenB");
        }
    }

    function swapToRatioPython(ERC20Mock _tokenA, uint160 _sqrtPriceX96)
        internal
        returns (bool successPython, bytes memory returnDataPython)
    {
        (successPython, returnDataPython) = address(pythonImpl).call(
            abi.encodeCall(
                SwapToRatioPython(address(pythonImpl))._swapToRatioMockPriceX96, (address(_tokenA), _sqrtPriceX96)
            )
        );

        if (successPython) {
            string memory path = "test/foundry/differential/balances.json";
            assertTrue(vm.exists(path));
            vm.writeJson(vm.toString(SwapToRatioPython(address(pythonImpl)).delta_a()), path, ".pythonImpl.tokenA");
            vm.writeJson(vm.toString(SwapToRatioPython(address(pythonImpl)).delta_b()), path, ".pythonImpl.tokenB");
        }
    }

    function _resetJSON() internal {
        string memory path = "test/foundry/differential/balances.json";
        assertTrue(vm.exists(path));
        string memory initialContent = '{"oldImpl":{"tokenA":"0","tokenB":"0"},"newImpl":{"tokenA":"0","tokenB":"0"},"pythonImpl":{"tokenA":"0","tokenB":"0"}}';
        vm.writeFile(path, initialContent);
    }
}

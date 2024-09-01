// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {ISwapToRatio, SwapToRatioOld, SwapToRatioNew, SwapToRatioPython} from "./SwapToRatio.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";
import {HypervisorMock} from "src/test_utils/HypervisorMock.sol";
import {UniProxyMock} from "src/test_utils/UniProxyMock.sol";
import {MockSwapRouter, ISwapRouter} from "src/test_utils/MockSwapRouter.sol";

import "contracts/uniswap/FullMath.sol";

import {Test, console} from "forge-std/Test.sol";

contract SwapToRatioTest is Test {
    ISwapToRatio oldImpl;
    ISwapToRatio newImpl;
    ISwapToRatio pythonImpl;

    UniProxyMock uniProxy;
    HypervisorMock hypervisor;
    MockSwapRouter swapRouter;
    ERC20Mock token0;
    ERC20Mock token1;

    function setUp() public {
        uniProxy = new UniProxyMock();
        token0 = new ERC20Mock("Token0", "TKN0", 18);
        token1 = new ERC20Mock("Token1", "TKN1", 18);
        hypervisor = new HypervisorMock("Token0-Token1", "TKN0-TKN1", address(token0), address(token1));
        swapRouter = new MockSwapRouter();
        uint24 swapFee = 500;

        oldImpl = new SwapToRatioOld(address(uniProxy), address(hypervisor), address(swapRouter), swapFee);
        newImpl = new SwapToRatioNew(address(uniProxy), address(hypervisor), address(swapRouter), swapFee);
        pythonImpl = new SwapToRatioPython(address(uniProxy), address(hypervisor), address(swapRouter), swapFee);
    }

    function setUpState(bool _swapToken0, uint160 _sqrtPriceX96, uint256 _tokenABalance, uint256 _tokenBBalance)
        internal
        returns (ERC20Mock _tokenA, ERC20Mock _tokenB, uint160 _boundedSqrtPriceX96)
    {
        // Determine which token is token A and token B based on fuzzed input
        (_tokenA, _tokenB) = _swapToken0 ? (token0, token1) : (token1, token0);

        // Ensure _sqrtPriceX96 is within a reasonable range to avoid overflow when squared
        _boundedSqrtPriceX96 = uint160(bound(uint256(_sqrtPriceX96), type(uint72).max, type(uint96).max));

        // Calculate priceX192 based on _boundedSqrtPriceX96
        uint256 priceX192 = uint256(_boundedSqrtPriceX96) * uint256(_boundedSqrtPriceX96);

        // Calculate the price of token A in terms of token B using priceX192, normalized to 18 decimals
        uint256 price18 = _swapToken0
            ? FullMath.mulDiv((10 ** _tokenB.decimals()) * (10 ** (18 - _tokenA.decimals())), 1 << 192, priceX192)
            : FullMath.mulDiv((10 ** _tokenA.decimals()) * (10 ** (18 - _tokenB.decimals())), priceX192, 1 << 192);

        // Calculate the ratio between token A and token B
        uint256 swapRouterBalanceA = type(uint96).max;
        uint256 _ratio = FullMath.mulDiv(swapRouterBalanceA, 1e18, price18);

        // Set the ratio in the proxy and router
        uniProxy.setRatio(address(hypervisor), address(_tokenA), _ratio);
        swapRouter.setRate(address(_tokenA), address(_tokenB), _ratio);

        // Mint balances for both tokens to swapRouter to facilitate swaps
        _tokenA.mint(address(swapRouter), swapRouterBalanceA);
        // Adjust token B balances according to the derived ratio
        _tokenB.mint(address(swapRouter), FullMath.mulDiv(swapRouterBalanceA, _ratio, 10 ** _tokenA.decimals()));

        // Bound token balances to avoid swapping more than the swap router has available
        uint256 _boundedTokenABalance = bound(_tokenABalance, 10 ** _tokenA.decimals(), type(uint88).max);
        uint256 _boundedTokenBBalance = bound(_tokenBBalance, 10 ** _tokenB.decimals(), type(uint88).max);

        // Mint balances for both tokens to the old and new implementations
        _tokenA.mint(address(oldImpl), _boundedTokenABalance);
        _tokenB.mint(address(oldImpl), _boundedTokenBBalance);
        _tokenA.mint(address(newImpl), _boundedTokenABalance);
        _tokenB.mint(address(newImpl), _boundedTokenBBalance);
        _tokenA.mint(address(pythonImpl), _boundedTokenABalance);
        _tokenB.mint(address(pythonImpl), _boundedTokenBBalance);
    }

    function test_swapToRatioFuzz(
        bool _swapToken0,
        uint160 _sqrtPriceX96,
        uint256 _tokenABalance,
        uint256 _tokenBBalance
    ) public {
        (ERC20Mock _tokenA, ERC20Mock _tokenB, uint160 _boundedSqrtPriceX96) =
            setUpState(_swapToken0, _sqrtPriceX96, _tokenABalance, _tokenBBalance);

        // Snapshot the state of the VM to revert to after each call
        uint256 snapshotId = vm.snapshot();

        // Call the old implementation to swap to the ratio
        (bool successOld, bytes memory returnDataOld) = swapToRatioOld(_tokenA, _tokenB);

        // Revert the state of the VM to the snapshot taken before the previous call
        vm.revertTo(snapshotId);

        // Call the new implementation to swap to the ratio
        (bool successNew, bytes memory returnDataNew) = swapToRatioNew(_tokenA, _tokenB, _boundedSqrtPriceX96);

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
            // Assert more of tokenA was able to be swapped
            assertLt(newTokenABalance, oldTokenABalance);
            assertGt(newTokenBBalance, oldTokenBBalance);
        } else if (!successOld && successNew) {
            // this is fine – new implementation is more robust
            console.log("old implementation reverted when the new one did not");
        } else if (successOld && !successNew) {
            // this is bad – new implementation is less robust
            assertTrue(false, "new implementation should not revert when old one does not");
        } else {
            assertEq(keccak256(returnDataOld), keccak256(returnDataNew), "revert reasons should match");
        }
        _resetJSON();
    }

    // Run with forge test --mt test_swapToRatioFuzzPython -vvv --ffi
    function test_swapToRatioFuzzPython(
        bool _swapToken0,
        uint160 _sqrtPriceX96,
        uint256 _tokenABalance,
        uint256 _tokenBBalance
    ) public {
        (ERC20Mock _tokenA, ERC20Mock _tokenB, uint160 _boundedSqrtPriceX96) =
            setUpState(_swapToken0, _sqrtPriceX96, _tokenABalance, _tokenBBalance);

        // Snapshot the state of the VM to revert to after each call
        uint256 snapshotId = vm.snapshot();

        // Call the old implementation to swap to the ratio
        swapToRatioOld(_tokenA, _tokenB);

        // Revert the state of the VM to the snapshot taken before the previous call
        vm.revertTo(snapshotId);

        // Cache the balances before calling the new implementation
        uint256 cachedBalanceA = _tokenA.balanceOf(address(newImpl));
        uint256 cachedBalanceB = _tokenB.balanceOf(address(newImpl));

        // Call the new implementation to swap to the ratio
        (bool successNew,) = swapToRatioNew(_tokenA, _tokenB, _boundedSqrtPriceX96);

        // Revert the state of the VM to the snapshot taken before the previous call
        vm.revertTo(snapshotId);

        // Call the Python implementation to swap to the ratio
        (bool successPython,) = swapToRatioPython(_tokenA, _boundedSqrtPriceX96);

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
        vm.writeJson('"0"', path, ".oldImpl.tokenA");
        vm.writeJson('"0"', path, ".oldImpl.tokenB");
        vm.writeJson('"0"', path, ".newImpl.tokenA");
        vm.writeJson('"0"', path, ".newImpl.tokenB");
        vm.writeJson('"0"', path, ".pythonImpl.tokenA");
        vm.writeJson('"0"', path, ".pythonImpl.tokenB");
    }
}

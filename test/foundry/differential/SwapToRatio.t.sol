// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {ISwapToRatio, SwapToRatioOld, SwapToRatioNew} from "./SwapToRatio.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";
import {HypervisorMock} from "src/test_utils/HypervisorMock.sol";
import {UniProxyMock} from "src/test_utils/UniProxyMock.sol";
import {MockSwapRouter} from "src/test_utils/MockSwapRouter.sol";

import "contracts/uniswap/FullMath.sol";

import {Test, console} from "forge-std/Test.sol";

contract SwapToRatioTest is Test {
    ISwapToRatio oldImpl;
    ISwapToRatio newImpl;

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
    }

    function test_swapToRatioFuzz(bool _swapToken0, uint160 _sqrtPriceX96, uint256 _tokenABalance, uint256 _tokenBBalance)
        public
    {
        // Determine which token is token A and token B based on fuzzed input
        (ERC20Mock _tokenA, ERC20Mock _tokenB) = _swapToken0 ? (token0, token1) : (token1, token0);

        // Ensure _sqrtPriceX96 is within a reasonable range to avoid overflow when squared
        _sqrtPriceX96 = uint160(bound(uint256(_sqrtPriceX96), type(uint72).max, type(uint96).max));

        // Calculate priceX192 based on _sqrtPriceX96
        uint256 priceX192 = uint256(_sqrtPriceX96) * uint256(_sqrtPriceX96);

        // Calculate the price of token A in terms of token B using priceX192, normalized to 18 decimals
        uint256 price18 = FullMath.mulDiv((10 ** _tokenA.decimals()) * (10 ** (18 - _tokenB.decimals())), priceX192, 1 << 192);

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
        _tokenABalance = bound(_tokenABalance, 10 ** _tokenA.decimals(), type(uint88).max);
        _tokenBBalance = bound(_tokenBBalance, 10 ** _tokenB.decimals(), type(uint88).max);

        // Mint balances for both tokens to the old and new implementations
        _tokenA.mint(address(oldImpl), _tokenABalance);
        _tokenA.mint(address(newImpl), _tokenABalance);
        _tokenB.mint(address(oldImpl), _tokenBBalance);
        _tokenB.mint(address(newImpl), _tokenBBalance);

        // Put variable back at the top of the stack
        uint160 _sqrtPriceX96 = _sqrtPriceX96;

        // Snapshot the state of the VM to revert to after each call
        uint256 snapshotId = vm.snapshot();

        // Call the old and new implementations to swap to the ratio
        (bool successOld, bytes memory returnDataOld) =
            address(oldImpl).call(abi.encodeCall(oldImpl._swapToRatio, address(_tokenA)));
        
        // If successful, cache the resulting balances
        if (successOld) {
            // TODO: write to JSON instead
            vm.store(address(this), keccak256(abi.encodePacked("oldTokenABalance")), bytes32(_tokenA.balanceOf(address(oldImpl))));
            vm.store(address(this), keccak256(abi.encodePacked("oldTokenBBalance")), bytes32(_tokenB.balanceOf(address(oldImpl))));
        }

        // Revert the state of the VM to the snapshot taken before the previous call
        vm.revertTo(snapshotId);

        // Call the new implementation to swap to the ratio
        (bool successNew, bytes memory returnDataNew) =
            address(newImpl).call(abi.encodeCall(SwapToRatioNew(address(newImpl))._swapToRatioMockPriceX96, (address(_tokenA), _sqrtPriceX96)));

        // If successful, cache the resulting balances
        if (successNew) {
            // TODO: write to JSON instead
            vm.store(address(this), keccak256(abi.encodePacked("newTokenABalance")), bytes32(_tokenA.balanceOf(address(newImpl))));
            vm.store(address(this), keccak256(abi.encodePacked("newTokenBBalance")), bytes32(_tokenB.balanceOf(address(newImpl))));
        }

        // Revert the state of the VM to the snapshot taken before both calls (this isn't strictly necessary)
        vm.revertTo(snapshotId);

        // Assert that the old and new implementations have the same success status
        if (successOld && successNew) {
            console.log("here");
            // TODO: load from JSON instead
            // uint256 oldTokenABalance = uint256(vm.load(address(this), keccak256(abi.encodePacked("oldTokenABalance"))));
            // uint256 oldTokenBBalance = uint256(vm.load(address(this), keccak256(abi.encodePacked("oldTokenBBalance"))));
            // uint256 newTokenABalance = uint256(vm.load(address(this), keccak256(abi.encodePacked("newTokenABalance"))));
            // uint256 newTokenBBalance = uint256(vm.load(address(this), keccak256(abi.encodePacked("newTokenBBalance"))));
            console.log("oldTokenABalance", oldTokenABalance);
            console.log("oldTokenBBalance", oldTokenBBalance);
            console.log("newTokenABalance", newTokenABalance);
            console.log("newTokenBBalance", newTokenBBalance);
            // TODO: assert cached balances are within some threshold
        }
        else if (!successOld && successNew) {
            // this is fine – new implementation is more robust
        }
        else if (successOld && !successNew) {
            // this is bad – new implementation is less robust
            assertTrue(false, "new implementation should not revert when old one does not");
        } else {
            assertEq(keccak256(returnDataOld), keccak256(returnDataNew), "revert reasons should match");
        }
    }

    function swapToRatioPython(uint256 price, uint256 midRatio, uint256 tokenABalance, uint256 tokenBBalance)
        internal
        returns (uint256 delta_a, uint256 delta_b)
    {
        string[] memory inputs = new string[](11);
        inputs[0] = "python";
        inputs[1] = "test/differential/python/swap_to_ratio.py";
        inputs[2] = "swap_to_ratio";
        inputs[3] = "--price";
        inputs[4] = vm.toString(price);
        inputs[5] = "--mid-ratio";
        inputs[6] = vm.toString(midRatio);
        inputs[7] = "--balance-a";
        inputs[8] = vm.toString(tokenABalance);
        inputs[9] = "--balance-b";
        inputs[10] = vm.toString(tokenBBalance);

        (delta_a, delta_b) = abi.decode(vm.ffi(inputs), (uint256, uint256));
    }
}

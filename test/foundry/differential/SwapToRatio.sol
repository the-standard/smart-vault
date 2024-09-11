// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/uniswap/FullMath.sol";
import "contracts/uniswap/PoolAddress.sol";
import "contracts/interfaces/IHypervisor.sol";
import "contracts/interfaces/IPeripheryImmutableState.sol";
import "contracts/interfaces/ISwapRouter.sol";
import "contracts/interfaces/IUniProxy.sol";
import "contracts/interfaces/IUniswapV3Pool.sol";

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/vm.sol";

interface ISwapToRatio {
    error RatioError();

    function _swapToRatio(address _tokenA) external;
}

contract SwapToRatioBase is ISwapToRatio {
    address internal uniProxy;
    address internal hypervisor;
    address internal swapRouter;
    uint24 internal swapFee;

    constructor(address _uniProxy, address _hypervisor, address _swapRouter, uint24 _swapFee) {
        uniProxy = _uniProxy;
        hypervisor = _hypervisor;
        swapRouter = _swapRouter;
        swapFee = _swapFee;
    }

    function _thisBalanceOf(address _token) internal view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function _withinRatio(uint256 _tokenBBalance, uint256 _requiredStart, uint256 _requiredEnd)
        internal
        pure
        returns (bool)
    {
        return _tokenBBalance >= _requiredStart && _tokenBBalance <= _requiredEnd;
    }

    function _swapToRatio(address _tokenA) public virtual override {}
}

contract SwapToRatioOld is SwapToRatioBase {
    using SafeERC20 for IERC20;

    constructor(address _uniProxy, address _hypervisor, address _swapRouter, uint24 _swapFee)
        SwapToRatioBase(_uniProxy, _hypervisor, _swapRouter, _swapFee)
    {}

    function _swapToRatio(address _tokenA) public override {
        address _tokenB = _tokenA == IHypervisor(hypervisor).token0()
            ? IHypervisor(hypervisor).token1()
            : IHypervisor(hypervisor).token0();
        uint256 _tokenBBalance = _thisBalanceOf(_tokenB);
        (uint256 _amountStart, uint256 _amountEnd) =
            IUniProxy(uniProxy).getDepositAmount(hypervisor, _tokenA, _thisBalanceOf(_tokenA));
        uint256 _divisor = 2;
        bool _tokenBTooLarge;
        for (uint256 index = 0; index < 20; index++) {
            if (_withinRatio(_tokenBBalance, _amountStart, _amountEnd)) break;
            uint256 _midRatio = (_amountStart + _amountEnd) / 2;
            if (_tokenBBalance < _midRatio) {
                if (_tokenBTooLarge) {
                    _divisor++;
                    _tokenBTooLarge = false;
                }
                IERC20(_tokenA).safeApprove(swapRouter, _thisBalanceOf(_tokenA));
                try ISwapRouter(swapRouter).exactOutputSingle(
                    ISwapRouter.ExactOutputSingleParams({
                        tokenIn: _tokenA,
                        tokenOut: _tokenB,
                        fee: swapFee,
                        recipient: address(this),
                        deadline: block.timestamp + 60,
                        amountOut: (_midRatio - _tokenBBalance) / _divisor,
                        amountInMaximum: _thisBalanceOf(_tokenA),
                        sqrtPriceLimitX96: 0
                    })
                ) returns (uint256) {} catch {
                    _divisor++;
                }
                IERC20(_tokenA).safeApprove(swapRouter, 0);
            } else {
                if (!_tokenBTooLarge) {
                    _divisor++;
                    _tokenBTooLarge = true;
                }
                IERC20(_tokenB).safeApprove(swapRouter, (_tokenBBalance - _midRatio) / _divisor);
                try ISwapRouter(swapRouter).exactInputSingle(
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: _tokenB,
                        tokenOut: _tokenA,
                        fee: swapFee,
                        recipient: address(this),
                        deadline: block.timestamp + 60,
                        amountIn: (_tokenBBalance - _midRatio) / _divisor,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                ) returns (uint256) {} catch {
                    _divisor++;
                }
                IERC20(_tokenB).safeApprove(swapRouter, 0);
            }
            _tokenBBalance = _thisBalanceOf(_tokenB);
            (_amountStart, _amountEnd) =
                IUniProxy(uniProxy).getDepositAmount(hypervisor, _tokenA, _thisBalanceOf(_tokenA));
        }

        if (!_withinRatio(_tokenBBalance, _amountStart, _amountEnd)) revert RatioError();
    }
}

contract SwapToRatioNew is SwapToRatioBase {
    using SafeERC20 for IERC20;

    uint160 _sqrtPriceX96;

    constructor(address _uniProxy, address _hypervisor, address _swapRouter, uint24 _swapFee)
        SwapToRatioBase(_uniProxy, _hypervisor, _swapRouter, _swapFee)
    {}

    function _swapToRatioMockPriceX96(address _tokenA, uint160 _mockPriceX96) public {
        _sqrtPriceX96 = _mockPriceX96;
        _swapToRatio(_tokenA);
    }

    function _swapToRatio(address _tokenA) public override {
        address _token0 = IHypervisor(hypervisor).token0();
        address _token1 = IHypervisor(hypervisor).token1();

        address _tokenB = _tokenA == _token0 ? _token1 : _token0;

        // TODO: make this work with mocked pools and fork setup
        // uint160 _sqrtPriceX96;
        // {
        //     PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(_token0, _token1, _fee);
        //     address factory = IPeripheryImmutableState(_swapRouter).factory();
        //     (_sqrtPriceX96,,,,,,) = _swapRouter == uniswapRouter
        //         ? IUniswapV3Pool(PoolAddress.computeAddressUniswap(factory, poolKey)).slot0()
        //         : IUniswapV3Pool(PoolAddress.computeAddressRamses(factory, poolKey)).slot0();
        // }

        uint256 _midRatio;
        {
            (uint256 _amountStart, uint256 _amountEnd) =
                IUniProxy(uniProxy).getDepositAmount(hypervisor, _tokenA, _thisBalanceOf(_tokenA));
            if (_withinRatio(_thisBalanceOf(_tokenB), _amountStart, _amountEnd)) return;

            _midRatio = (_amountStart + _amountEnd) / 2;
        }

        bool _tokenAIs0 = _tokenA == _token0;
        uint256 _tokenBBalance = _thisBalanceOf(_tokenB);
        uint256 _tokenABalance = _thisBalanceOf(_tokenA);

        uint256 _amountIn;
        uint256 _amountOut;

        {
            uint256 aDec = ERC20(_tokenA).decimals();
            uint256 bDec = ERC20(_tokenB).decimals();

            uint256 price18;
            {
                uint256 priceX192 = uint256(_sqrtPriceX96) * _sqrtPriceX96;
                price18 = _tokenAIs0
                    ? FullMath.mulDiv((10 ** bDec) * (10 ** (18 - aDec)), 1 << 192, priceX192)
                    : FullMath.mulDiv((10 ** aDec) * (10 ** (18 - bDec)), priceX192, 1 << 192);
            }

            uint256 _a = _tokenABalance * (10 ** (18 - aDec));
            uint256 _ratio = FullMath.mulDiv(_a, 1e18, _midRatio * (10 ** (18 - bDec)));

            uint256 _denominator = 1e18 + FullMath.mulDiv(_ratio, 1e18, price18);
            uint256 _rb = FullMath.mulDiv(_tokenBBalance * (10 ** (18 - bDec)), _ratio, 1e18);

            if (_a > _rb) {
                _amountIn = FullMath.mulDiv(_a - _rb, 1e18, _denominator) / 10 ** (18 - aDec);
            } else {
                _amountOut = FullMath.mulDiv(_rb - _a, 1e18, _denominator) / 10 ** (18 - aDec);
            }
        }

        if (_tokenBBalance < _midRatio) {
            // we want more tokenB

            address _tokenIn = _tokenAIs0 ? _token0 : _token1;
            address _tokenOut = _tokenAIs0 ? _token1 : _token0;

            IERC20(_tokenIn).safeApprove(swapRouter, _tokenABalance);
            ISwapRouter(swapRouter).exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: _tokenIn,
                    tokenOut: _tokenOut,
                    fee: swapFee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: _amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
            IERC20(_tokenIn).safeApprove(swapRouter, 0);
        } else {
            // we want more tokenA

            address _tokenIn = _tokenAIs0 ? _token1 : _token0;
            address _tokenOut = _tokenAIs0 ? _token0 : _token1;

            IERC20(_tokenIn).safeApprove(swapRouter, _tokenBBalance);
            ISwapRouter(swapRouter).exactOutputSingle(
                ISwapRouter.ExactOutputSingleParams({
                    tokenIn: _tokenIn,
                    tokenOut: _tokenOut,
                    fee: swapFee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountOut: _amountOut,
                    amountInMaximum: _tokenBBalance,
                    sqrtPriceLimitX96: 0
                })
            );
            IERC20(_tokenIn).safeApprove(swapRouter, 0);
        }
    }
}

contract SwapToRatioPython is SwapToRatioBase {
    using SafeERC20 for IERC20;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 public delta_a;
    uint256 public delta_b;

    uint256 _sqrtPriceX96;

    constructor(address _uniProxy, address _hypervisor, address _swapRouter, uint24 _swapFee)
        SwapToRatioBase(_uniProxy, _hypervisor, _swapRouter, _swapFee)
    {}

    function _swapToRatioMockPriceX96(address _tokenA, uint160 _mockPriceX96) public {
        _sqrtPriceX96 = _mockPriceX96;
        _swapToRatio(_tokenA);
    }

    function _swapToRatio(address _tokenA) public override {
        address _token0 = IHypervisor(hypervisor).token0();
        address _token1 = IHypervisor(hypervisor).token1();

        bool _tokenAIs0 = _tokenA == _token0;
        address _tokenB = _tokenAIs0 ? _token1 : _token0;

        uint256 _tokenABalance = _thisBalanceOf(_tokenA);
        uint256 _tokenBBalance = _thisBalanceOf(_tokenB);

        // Calculate the ratio based on the token A and token B balances for the Python implementation
        uint256 _midRatio;
        uint256 _ratio;
        uint256 price18;
        {
            (uint256 _amountStart, uint256 _amountEnd) =
                IUniProxy(uniProxy).getDepositAmount(address(hypervisor), address(_tokenA), _tokenABalance);
            // If the token B balance is within the range of the token A balance, newImpl does nothing
            if (_withinRatio(_tokenBBalance, _amountStart, _amountEnd)) {
                _ratio = 0;
            } else {
                _midRatio = (_amountStart + _amountEnd) / 2;
                _ratio = FullMath.mulDiv(
                    _tokenABalance * (10 ** (18 - ERC20(_tokenB).decimals())),
                    1e18,
                    _midRatio * (10 ** (18 - ERC20(_tokenB).decimals()))
                );
            }

            uint256 priceX192 = uint256(_sqrtPriceX96) * _sqrtPriceX96;
            price18 = _tokenAIs0
                ? FullMath.mulDiv(
                    (10 ** ERC20(_tokenB).decimals()) * (10 ** (18 - ERC20(_tokenA).decimals())), 1 << 192, priceX192
                )
                : FullMath.mulDiv(
                    (10 ** ERC20(_tokenA).decimals()) * (10 ** (18 - ERC20(_tokenB).decimals())), priceX192, 1 << 192
                );
        }

        string[] memory inputs = new string[](11);
        inputs[0] = "python";
        inputs[1] = "test/foundry/differential/python/swap_to_ratio.py";
        inputs[2] = "swap_to_ratio";
        inputs[3] = "--price";
        inputs[4] = vm.toString(price18);
        inputs[5] = "--ratio";
        inputs[6] = vm.toString(_ratio);
        inputs[7] = "--balance-a";
        inputs[8] = vm.toString(_tokenABalance);
        inputs[9] = "--balance-b";
        inputs[10] = vm.toString(_tokenBBalance);

        (delta_a, delta_b) = abi.decode(vm.ffi(inputs), (uint256, uint256));

        // Unless Python returns zero for both values, perform the swap to get the other token balance delta
        if (delta_a != 0) {
            if (_tokenBBalance < _midRatio) {
                IERC20(_tokenA).safeApprove(swapRouter, delta_a);
                delta_b = ISwapRouter(swapRouter).exactInputSingle(
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: _tokenA,
                        tokenOut: _tokenB,
                        fee: swapFee,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: delta_a,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                );
                IERC20(_tokenA).safeApprove(swapRouter, 0);
            } else {
                IERC20(_tokenB).safeApprove(swapRouter, _tokenBBalance);
                delta_b = ISwapRouter(swapRouter).exactOutputSingle(
                    ISwapRouter.ExactOutputSingleParams({
                        tokenIn: _tokenB,
                        tokenOut: _tokenA,
                        fee: swapFee,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountOut: delta_a,
                        amountInMaximum: _tokenBBalance,
                        sqrtPriceLimitX96: 0
                    })
                );
                IERC20(_tokenB).safeApprove(swapRouter, 0);
            }
        }
    }
}

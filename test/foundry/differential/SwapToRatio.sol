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

        // uint160 _sqrtPriceX96;
        // {
        //     PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(_token0, _token1, swapFee);
        //     address factory = IPeripheryImmutableState(swapRouter).factory();
        //     (_sqrtPriceX96,,,,,,) = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey)).slot0();
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
            // we want more token b

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
            // we want more token a

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

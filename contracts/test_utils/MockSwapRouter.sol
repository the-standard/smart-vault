// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/interfaces/ISwapRouter.sol";

import {IPeripheryImmutableState} from "contracts/interfaces/IPeripheryImmutableState.sol";
import {FullMath} from "contracts/uniswap/FullMath.sol";

import {console} from "forge-std/console.sol";

contract MockSwapRouter is ISwapRouter, IPeripheryImmutableState {
    address private tokenIn;
    address private tokenOut;
    uint24 private fee;
    address private recipient;
    uint256 private deadline;
    uint256 private amountIn;
    uint256 private amountOutMinimum;
    uint160 private sqrtPriceLimitX96;
    uint256 private txValue;

    address private _factory;

    mapping(address => mapping(address => uint256)) private rates;
    mapping(address => mapping(address => uint160)) private sqrtRates;

    struct MockSwapData {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
        uint256 txValue;
    }

    function getAmountOut(uint256 _amountIn, address _tokenIn, address _tokenOut) private view returns (uint256) {
        uint160 sqrtPrice = sqrtRates[_tokenIn][_tokenOut];
        if(sqrtPrice != 0) {
            uint256 priceX192 = uint256(sqrtPrice) * uint256(sqrtPrice);
            return FullMath.mulDiv(_amountIn, priceX192, 1 << 192);
        }

        sqrtPrice = sqrtRates[_tokenOut][_tokenIn];
        if(sqrtPrice != 0) {
            uint256 priceX192 = uint256(sqrtPrice) * uint256(sqrtPrice);
            return FullMath.mulDiv(_amountIn, 1 << 192, priceX192);
        }

        return rates[_tokenIn][_tokenOut] * _amountIn / 1e18;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 _amountOut) {
        tokenIn = params.tokenIn;
        tokenOut = params.tokenOut;
        fee = params.fee;
        recipient = params.recipient;
        deadline = params.deadline;
        amountIn = params.amountIn;
        amountOutMinimum = params.amountOutMinimum;
        sqrtPriceLimitX96 = params.sqrtPriceLimitX96;
        txValue = msg.value;

        console.log("amountIn: %d", amountIn);

        _amountOut = getAmountOut(amountIn, tokenIn, tokenOut);

        console.log("amountOut: %d", _amountOut);
        require(_amountOut > amountOutMinimum);
        if (msg.value == 0) {
            IERC20(tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        }
        IERC20(tokenOut).transfer(recipient, _amountOut);
    }

    function receivedSwap() external view returns (MockSwapData memory) {
        return MockSwapData(
            tokenIn, tokenOut, fee, recipient, deadline, amountIn, amountOutMinimum, sqrtPriceLimitX96, txValue
        );
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 _amountOut) {
        (address _tokenIn,, address _tokenOut) = abi.decode(params.path, (address, uint24, address));
        _amountOut = rates[_tokenIn][_tokenOut] * params.amountIn / 1e18;
        require(_amountOut > params.amountOutMinimum);
        if (msg.value == 0) {
            IERC20(_tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        }
        IERC20(_tokenOut).transfer(params.recipient, _amountOut);
    }

    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 _amountIn) {
        (address _tokenOut,, address _tokenIn) = abi.decode(params.path, (address, uint24, address));
        _amountIn = params.amountOut * 1e18 / rates[_tokenIn][_tokenOut];
        require(_amountIn < params.amountInMaximum);
        if (msg.value == 0) {
            IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        }
        IERC20(_tokenOut).transfer(params.recipient, params.amountOut);
    }


    function getAmountIn(uint256 _amountOut, address _tokenIn, address _tokenOut) private view returns (uint256) {
        uint160 sqrtPrice = sqrtRates[_tokenIn][_tokenOut];
        if(sqrtPrice != 0) {
            uint256 priceX192 = uint256(sqrtPrice) * uint256(sqrtPrice);
            uint256 _amountIn = FullMath.mulDiv(_amountOut, 1 << 192, priceX192);
            console.log("normal _amountIn: %d, rate %s, out from rate %s", _amountIn, rates[_tokenIn][_tokenOut], _amountOut * 1e18 / rates[_tokenIn][_tokenOut]);
            return _amountIn;
        }

        sqrtPrice = sqrtRates[_tokenOut][_tokenIn];
        if(sqrtPrice != 0) {
            uint256 priceX192 = uint256(sqrtPrice) * uint256(sqrtPrice);
            uint256 _amountIn = FullMath.mulDiv(_amountOut, priceX192, 1 << 192);
            console.log("reversed _amountIn: %d, rate %s, out from rate %s", _amountIn, rates[_tokenIn][_tokenOut], _amountOut * 1e18 / rates[_tokenIn][_tokenOut]);
            return _amountIn;
        }

        return _amountOut * 1e18 / rates[_tokenIn][_tokenOut];
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 _amountIn) {
        console.log("params.amountOut: %d, rate %d", params.amountOut, rates[params.tokenIn][params.tokenOut]);
        _amountIn = getAmountIn(params.amountOut, params.tokenIn, params.tokenOut);
        console.log("_amountIn: %d", _amountIn);
        require(_amountIn <= params.amountInMaximum,"price too high");
        if (msg.value == 0) {
            IERC20(params.tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        }
        IERC20(params.tokenOut).transfer(params.recipient, params.amountOut);
    }

    function setRate(address _tokenIn, address _tokenOut, uint256 _rate) external {
        rates[_tokenIn][_tokenOut] = _rate;
    }

    function setSqrtRate(address _tokenIn, address _tokenOut, uint160 _rate) external {
        sqrtRates[_tokenIn][_tokenOut] = _rate;
    }

    function getRate(address _tokenIn, address _tokenOut) external view returns (uint256) {
        return rates[_tokenIn][_tokenOut];
    }

    function setFactory(address __factory) external {
        _factory = __factory;
    }

    function factory() external view override returns (address) {
        return _factory;
    }
}

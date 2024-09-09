// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/interfaces/ISwapRouter.sol";

import {console} from "forge-std/console.sol";

contract MockSwapRouter is ISwapRouter {
    address private tokenIn;
    address private tokenOut;
    uint24 private fee;
    address private recipient;
    uint256 private deadline;
    uint256 private amountIn;
    uint256 private amountOutMinimum;
    uint160 private sqrtPriceLimitX96;
    uint256 private txValue;

    mapping(address => mapping(address => uint256)) private rates;

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

        _amountOut = rates[tokenIn][tokenOut] * amountIn / 1e18;
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

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 _amountIn) {
        _amountIn = params.amountOut * 1e18 / rates[params.tokenIn][params.tokenOut];
        require(_amountIn < params.amountInMaximum);
        if (msg.value == 0) {
            IERC20(params.tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        }
        IERC20(params.tokenOut).transfer(params.recipient, params.amountOut);
    }

    function setRate(address _tokenIn, address _tokenOut, uint256 _rate) external {
        rates[_tokenIn][_tokenOut] = _rate;
    }

    function getRate(address _tokenIn, address _tokenOut) external view returns (uint256) {
        return rates[_tokenIn][_tokenOut];
    }
}

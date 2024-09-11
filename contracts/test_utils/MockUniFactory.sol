// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./ByteCodeConstants.sol";

contract MockUniswapFactory {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    Parameters public parameters;

    mapping(uint24 => int24) public feeAmountTickSpacing;

    constructor() {
        feeAmountTickSpacing[500] = 10;
        feeAmountTickSpacing[3000] = 60;
        feeAmountTickSpacing[10000] = 200;
    }

    function deploy(address tokenA, address tokenB, uint24 fee) external returns (address pool) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 salt = keccak256(abi.encode(token0, token1, fee));
        bytes memory bytecode = uniPoolCode;
        parameters = Parameters({
            factory: address(this),
            token0: token0,
            token1: token1,
            fee: fee,
            tickSpacing: feeAmountTickSpacing[fee]
        });
        assembly {
            pool := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        delete parameters;
    }
}

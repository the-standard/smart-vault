// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./BytecodeConstants.sol";

contract MockRamsesFactory {
    address fakePool;

    constructor(address _fakePool) {
        fakePool = _fakePool;
    }

    function implementation() external view returns (address) {
        return fakePool;
    }

    function deploy(address tokenA, address tokenB) external returns (address pool) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 salt = keccak256(abi.encode(token0, token1, uint24(500)));
        bytes memory bytecode = RAMSES_POOL_CODE;
        assembly {
            pool := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
    }
}

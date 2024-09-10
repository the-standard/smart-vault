// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

contract MockRamsesPool {
    uint160 public sqrtPriceX96;

    function setPrice(uint160 _sqrtPriceX96) public {
        sqrtPriceX96 = _sqrtPriceX96;
    }

    function slot0() external view returns (uint160, int24, uint16, uint16, uint16 , uint8, bool) {
        return (sqrtPriceX96, 0, 0, 0, 0, 0, false);
    }
}
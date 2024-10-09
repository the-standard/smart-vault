// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHypervisor is IERC20 {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getTotalAmounts() external view returns (uint256 total0, uint256 total1);
    function deposit(uint256 deposit0, uint256 deposit1, address to, address from, uint256[4] memory inMin)
        external
        returns (uint256 shares);

    function withdraw(uint256 shares, address to, address from, uint256[4] memory minAmounts)
        external
        returns (uint256 amount0, uint256 amount1);

    function rebalance(
        int24 baseLower,
        int24 baseUpper,
        int24 limitLower,
        int24 limitUpper,
        address feeRecipient,
        uint256[4] memory baseFees,
        uint256[4] memory limitFees
    ) external;

    function setWhitelist(address _address) external;
}

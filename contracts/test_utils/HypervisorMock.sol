// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/interfaces/IHypervisor.sol";

contract HypervisorMock is IHypervisor, ERC20 {
    address public immutable token0;
    address public immutable token1;

    constructor(string memory _name, string memory _symbol, address _token0, address _token1) ERC20(_name, _symbol) {
        token0 = _token0;
        token1 = _token1;
    }

    function getTotalAmounts() public view returns (uint256 total0, uint256 total1) {
        total0 = IERC20(token0).balanceOf(address(this));
        total1 = IERC20(token1).balanceOf(address(this));
    }

    function deposit(uint256 deposit0, uint256 deposit1, address to, address from, uint256[4] memory inMin)
        external
        returns (uint256 shares)
    {
        IERC20(token0).transferFrom(from, address(this), deposit0);
        IERC20(token1).transferFrom(from, address(this), deposit1);
        // simplified calculation because our mock will not deal with a changing swap rate
        _mint(to, deposit0);
    }

    function withdraw(uint256 shares, address to, address from, uint256[4] memory minAmounts)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 _total0, uint256 _total1) = getTotalAmounts();
        amount0 = shares * _total0 / totalSupply();
        amount1 = shares * _total1 / totalSupply();
        _burn(from, shares);
        IERC20(token0).transfer(to, amount0);
        IERC20(token1).transfer(to, amount1);
    }

    function rebalance(
        int24 baseLower,
        int24 baseUpper,
        int24 limitLower,
        int24 limitUpper,
        address feeRecipient,
        uint256[4] memory baseFees,
        uint256[4] memory limitFees
    ) external {}

    function setWhitelist(address _address) external {}
}

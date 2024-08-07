// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/interfaces/IHypervisor.sol";

contract GammaVaultMock is IHypervisor, ERC20 {
    address public immutable token0;
    address public immutable token1;

    constructor (string memory _name, string memory _symbol, address _token0, address _token1) ERC20(_name, _symbol) {
        token0 = _token0;
        token1 = _token1;
    }

    function getTotalAmounts() public view returns (uint256 total0, uint256 total1) {
        total0 = IERC20(token0).balanceOf(address(this));
        total1 = IERC20(token1).balanceOf(address(this));
    }

    function deposit(
        uint256 deposit0,
        uint256 deposit1,
        address to,
        address from,
        uint256[4] memory inMin
    ) external returns (uint256 shares) {
        IERC20(token0).transferFrom(from, address(this), deposit0);
        IERC20(token1).transferFrom(from, address(this), deposit1);
        // simplified calculation because our mock will not deal with a changing swap rate
        _mint(to, deposit0);
    }
}
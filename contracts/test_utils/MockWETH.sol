// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/interfaces/IWETH.sol";

contract MockWETH is IWETH, ERC20 {

    constructor() ERC20("Wrapped Ether", "WETH") {
    }

    function withdraw(uint256 _value) external {
        _burn(msg.sender, _value);
        (bool sent, ) = payable(msg.sender).call{value: _value}("");
        require(sent);
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }
}
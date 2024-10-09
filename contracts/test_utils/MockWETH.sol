// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "contracts/test_utils/ERC20Mock.sol";
import "contracts/interfaces/IWETH.sol";

contract MockWETH is IWETH, ERC20Mock {
    constructor() ERC20Mock("Wrapped Ether", "WETH", 18) {}

    receive() external payable {}

    function withdraw(uint256 _value) external {
        _burn(msg.sender, _value);
        (bool sent,) = payable(msg.sender).call{value: _value}("");
        require(sent);
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }
}

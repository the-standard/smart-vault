// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LimitedERC20 is ERC20 {
    uint256 private immutable AMOUNT;

    uint8 private dec;
    mapping(address => uint256) private requests;
    mapping(uint256 => address payable) private vaultAddresses;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol) {
        dec = _decimals;
        AMOUNT = 1000 * 10 ** dec;
    }

    modifier limit() {
        require(requests[msg.sender] < block.timestamp - 1 days, "err-limited");
        _;
    }

    function mint() public limit {
        requests[msg.sender] = block.timestamp;
        _mint(msg.sender, AMOUNT);
    }

    function decimals() public view override returns (uint8) {
        return dec;
    }
}

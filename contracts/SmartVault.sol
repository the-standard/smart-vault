// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/ISEuro.sol";
import "contracts/interfaces/IChainlink.sol";

contract SmartVault {
    uint256 public constant hundredPC = 100000;

    address public protocol;
    uint256 public collateral;
    uint256 public minted;
    uint256 public collateralRate;
    uint256 public feeRate;
    IChainlink public clEthUsd;
    IChainlink public clEurUsd;
    ISEuro public seuro;

    constructor(uint256 _collateralRate, uint256 _feeRate, address _seuro, address _clEthUsd, address _clEurUsd, address _protocol) {
        collateralRate = _collateralRate;
        clEthUsd = IChainlink(_clEthUsd);
        clEurUsd = IChainlink(_clEurUsd);
        seuro = ISEuro(_seuro);
        feeRate = _feeRate;
        protocol = _protocol;
    }

    modifier ifFullyCollateralised(uint256 _amount) {
        uint256 decDiff = clEurUsd.decimals() - clEthUsd.decimals();
        uint256 maxMint = collateral * 10 ** decDiff * uint256(clEthUsd.latestAnswer()) / uint256(clEurUsd.latestAnswer());
        uint256 potentialMinted = minted + _amount;
        require(potentialMinted <= maxMint, "err-under-coll");
        _;
    }

    function addCollateralETH() external payable {
        collateral += msg.value;
    }

    function mint(address _to, uint256 _amount) external ifFullyCollateralised(_amount) {
        minted += _amount;
        uint256 fee = _amount * feeRate / hundredPC;
        seuro.mint(_to, _amount - fee);
        seuro.mint(protocol, fee);
    }
}

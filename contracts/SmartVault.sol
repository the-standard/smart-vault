// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/ISEuro.sol";
import "contracts/interfaces/IChainlink.sol";
import "hardhat/console.sol";

contract SmartVault {
    uint256 public constant rateHundredPC = 100000;

    uint256 public collateral;
    IChainlink public clEthUsd;
    IChainlink public clEurUsd;
    uint256 public minted;
    uint256 public collateralRate;
    ISEuro public seuro;

    constructor(uint256 _collateralRate, address _seuro, address _clEthUsd, address _clEurUsd) {
        collateralRate = _collateralRate;
        clEthUsd = IChainlink(_clEthUsd);
        clEurUsd = IChainlink(_clEurUsd);
        seuro = ISEuro(_seuro);
    }

    modifier ifFullyCollateralised(uint256 _amount) {
        uint256 decDiff = clEurUsd.decimals() - clEthUsd.decimals();
        uint256 maxMint = collateral * 10 ** decDiff * uint256(clEthUsd.latestAnswer()) / uint256(clEurUsd.latestAnswer());
        console.log(maxMint);
        uint256 potentialMinted = minted + _amount;
        console.log(potentialMinted);
        require(potentialMinted <= maxMint, "err-under-coll");
        _;
    }

    function addCollateralETH() external payable {
        collateral += msg.value;
    }

    function mint(address _to, uint256 _amount) external ifFullyCollateralised(_amount) {
        minted += _amount;
        seuro.mint(_to, _amount);
    }
}

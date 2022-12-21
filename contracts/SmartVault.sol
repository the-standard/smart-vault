// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/ISEuro.sol";
import "contracts/interfaces/IChainlink.sol";
import "contracts/interfaces/ISmartVaultManager.sol";

contract SmartVault {
    uint256 public constant hundredPC = 100000;

    address public owner;
    uint256 public collateral;
    uint256 public minted;
    ISmartVaultManager public manager;
    ISEuro public seuro;

    struct Status { uint256 collateral; uint256 minted; }

    constructor(address _manager, address _owner, address _seuro) {
        owner = _owner;
        manager = ISmartVaultManager(_manager);
        seuro = ISEuro(_seuro);
    }

    modifier ifFullyCollateralised(uint256 _amount) {
        IChainlink clEurUsd = IChainlink(manager.clEurUsd());
        IChainlink clEthUsd = IChainlink(manager.clEthUsd());
        uint256 decDiff = clEurUsd.decimals() - clEthUsd.decimals();
        uint256 euroCollateral = collateral * 10 ** decDiff * uint256(clEthUsd.latestAnswer()) / uint256(clEurUsd.latestAnswer());
        uint256 maxMint = euroCollateral * hundredPC / manager.collateralRate();
        uint256 potentialMinted = minted + _amount;
        require(potentialMinted <= maxMint, "err-under-coll");
        _;
    }

    function status() external view returns (Status memory) {
        return Status(collateral, minted);
    }

    function addCollateralETH() external payable {
        collateral += msg.value;
    }

    function mint(address _to, uint256 _amount) external ifFullyCollateralised(_amount) {
        minted += _amount;
        uint256 fee = _amount * manager.feeRate() / hundredPC;
        seuro.mint(_to, _amount - fee);
        seuro.mint(manager.protocol(), fee);
    }
}

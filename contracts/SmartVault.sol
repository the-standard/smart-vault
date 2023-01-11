// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/ISEuro.sol";
import "contracts/interfaces/IChainlink.sol";
import "contracts/interfaces/ISmartVaultManager.sol";

contract SmartVault {
    uint256 public constant hundredPC = 100000;

    address public owner;
    uint256 public minted;
    ISmartVaultManager public manager;
    ISEuro public seuro;

    struct Asset { bytes32 symbol; uint256 amount; }
    struct Status { uint256 minted; uint256 maxMintable; uint256 currentCollateralPercentage; Asset[] collateral; }

    constructor(address _manager, address _owner, address _seuro) {
        owner = _owner;
        manager = ISmartVaultManager(_manager);
        seuro = ISEuro(_seuro);
    }

    modifier onlyOwnerOrVaultManager {
        require(msg.sender == owner || msg.sender == address(manager), "err-not-owner");
        _;
    }

    modifier onlyVaultManager {
        require(msg.sender == address(manager), "err-not-manager");
        _;
    }

    modifier ifFullyCollateralised(uint256 _amount) {
        uint256 potentialMinted = minted + _amount;
        require(potentialMinted <= maxMintable(), "err-under-coll");
        _;
    }

    function euroCollateral() private view returns (uint256) {
        IChainlink clEurUsd = IChainlink(manager.clEurUsd());
        IChainlink clEthUsd = IChainlink(manager.clEthUsd());
        uint256 decDiff = clEurUsd.decimals() - clEthUsd.decimals();
        return getCollateral(bytes32("ETH")) * 10 ** decDiff * uint256(clEthUsd.latestAnswer()) / uint256(clEurUsd.latestAnswer());
    }

    function maxMintable() private view returns (uint256) {
        return euroCollateral() * hundredPC / manager.collateralRate();
    }

    function currentCollateralPercentage() private view returns (uint256) {
        return minted == 0 ? 0 : euroCollateral() * hundredPC / minted;
    }

    function getCollateral(bytes32 _symbol) private view returns (uint256) {
        if (_symbol == bytes32("ETH")) return address(this).balance;
        return 0;
    }

    function status() external view returns (Status memory) {
        Asset[] memory assets = new Asset[](1);
        assets[0] = Asset(bytes32("ETH"), address(this).balance);
        return Status(minted, maxMintable(), currentCollateralPercentage(), assets);
    }

    function eqlStrings(string memory _a, string memory _b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((_a))) == keccak256(abi.encodePacked((_b))));
    }

    receive() external payable {}

    function mint(address _to, uint256 _amount) external onlyOwnerOrVaultManager ifFullyCollateralised(_amount) {
        minted += _amount;
        uint256 fee = _amount * manager.feeRate() / hundredPC;
        seuro.mint(_to, _amount - fee);
        seuro.mint(manager.protocol(), fee);
    }

    function setOwner(address _newOwner) external onlyVaultManager {
        require(_newOwner != address(0), "invalid-owner-addr");
        owner = _newOwner;
    }
}

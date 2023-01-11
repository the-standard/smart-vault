// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/ISEuro.sol";
import "contracts/interfaces/IChainlink.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/ISmartVaultManager.sol";
import "contracts/interfaces/ITokenManager.sol";

contract SmartVault is ISmartVault {
    uint256 private constant HUNDRED_PC = 100000;
    string private constant INVALID_USER = "err-invalid-user";
    bytes32 private constant ETH = bytes32("ETH");

    address public owner;
    uint256 private minted;
    ISmartVaultManager public manager;
    ISEuro public seuro;

    constructor(address _manager, address _owner, address _seuro) {
        owner = _owner;
        manager = ISmartVaultManager(_manager);
        seuro = ISEuro(_seuro);
    }

    modifier onlyOwnerOrVaultManager {
        require(msg.sender == owner || msg.sender == address(manager), INVALID_USER);
        _;
    }

    modifier onlyVaultManager {
        require(msg.sender == address(manager), INVALID_USER);
        _;
    }

    modifier ifFullyCollateralised(uint256 _amount) {
        uint256 potentialMinted = minted + _amount;
        require(potentialMinted <= maxMintable(), "err-under-coll");
        _;
    }

    function euroCollateral() private view returns (uint256 euros) {
        ITokenManager tokenManager = ITokenManager(manager.tokenManager());
        ITokenManager.Token[] memory acceptedTokens = tokenManager.getAcceptedTokens();
        IChainlink clEurUsd = IChainlink(tokenManager.clEurUsd());
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            ITokenManager.Token memory token = acceptedTokens[i];
            IChainlink tokenUsdClFeed = IChainlink(acceptedTokens[i].clAddr);
            uint256 decDiff = clEurUsd.decimals() - tokenUsdClFeed.decimals();
            euros += getCollateral(token.symbol, token.addr) * 10 ** decDiff * uint256(tokenUsdClFeed.latestAnswer()) / uint256(clEurUsd.latestAnswer());
        }
    }

    function maxMintable() private view returns (uint256) {
        return euroCollateral() * HUNDRED_PC / manager.collateralRate();
    }

    function currentCollateralPercentage() private view returns (uint256) {
        return minted == 0 ? 0 : euroCollateral() * HUNDRED_PC / minted;
    }

    function getCollateral(bytes32 _symbol, address _tokenAddress) private view returns (uint256) {
        if (_symbol == ETH) return address(this).balance;
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    function getAssets() private view returns (Asset[] memory) {
        ITokenManager tokenManager = ITokenManager(manager.tokenManager());
        ITokenManager.Token[] memory acceptedTokens = tokenManager.getAcceptedTokens();
        Asset[] memory assets = new Asset[](acceptedTokens.length);
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            ITokenManager.Token memory token = acceptedTokens[i];
            assets[i] = Asset(token.symbol, getCollateral(token.symbol, token.addr));
        }
        return assets;
    }

    function status() external view returns (Status memory) {
        return Status(minted, maxMintable(), currentCollateralPercentage(), getAssets());
    }

    receive() external payable {}

    function mint(address _to, uint256 _amount) external onlyOwnerOrVaultManager ifFullyCollateralised(_amount) {
        minted += _amount;
        uint256 fee = _amount * manager.feeRate() / HUNDRED_PC;
        seuro.mint(_to, _amount - fee);
        seuro.mint(manager.protocol(), fee);
    }

    function setOwner(address _newOwner) external onlyVaultManager {
        require(_newOwner != address(0), "invalid-owner-addr");
        owner = _newOwner;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/interfaces/ISEuro.sol";
import "contracts/interfaces/IChainlink.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/ISmartVaultManager.sol";
import "contracts/interfaces/ITokenManager.sol";

contract SmartVault is ISmartVault {
    using SafeERC20 for IERC20;

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

    modifier ifMinted(uint256 _amount) {
        require(minted >= _amount, "err-insuff-minted");
        _;
    }

    function euroCollateral() private view returns (uint256 euros) {
        ITokenManager tokenManager = ITokenManager(manager.tokenManager());
        ITokenManager.Token[] memory acceptedTokens = tokenManager.getAcceptedTokens();
        IChainlink clEurUsd = IChainlink(tokenManager.clEurUsd());
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            ITokenManager.Token memory token = acceptedTokens[i];
            IChainlink tokenUsdClFeed = IChainlink(acceptedTokens[i].clAddr);
            uint256 clScaleDiff = clEurUsd.decimals() - tokenUsdClFeed.decimals();
            // TODO refactor this
            uint256 scaledCollateral = getCollateral(token.symbol, token.addr) * 10 ** getTokenScaleDiff(token.symbol, token.addr);
            uint256 collateralUsd = scaledCollateral * 10 ** clScaleDiff * uint256(tokenUsdClFeed.latestAnswer());
            euros += collateralUsd / uint256(clEurUsd.latestAnswer());
        }
    }

    function maxMintable() private view returns (uint256) {
        return euroCollateral() * HUNDRED_PC / manager.collateralRate();
    }

    function currentCollateralPercentage() private view returns (uint256) {
        return minted == 0 ? 0 : euroCollateral() * HUNDRED_PC / minted;
    }

    function getTokenScaleDiff(bytes32 _symbol, address _tokenAddress) private view returns (uint256 scaleDiff) {
        return _symbol == ETH ? 0 : 18 - ERC20(_tokenAddress).decimals();
    }

    function getCollateral(bytes32 _symbol, address _tokenAddress) private view returns (uint256 amount) {
        return _symbol == ETH ? address(this).balance : IERC20(_tokenAddress).balanceOf(address(this));
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

    function burn(uint256 _amount) external ifMinted(_amount) {
        minted -= _amount;
        seuro.burn(msg.sender, _amount);
    }

    function setOwner(address _newOwner) external onlyVaultManager {
        require(_newOwner != address(0), "invalid-owner-addr");
        owner = _newOwner;
    }
}

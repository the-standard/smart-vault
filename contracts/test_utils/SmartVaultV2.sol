// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/interfaces/IEUROs.sol";
import "contracts/interfaces/IPriceCalculator.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/ISmartVaultManager.sol";
import "contracts/interfaces/ITokenManager.sol";

contract SmartVaultV2 is ISmartVault {
    using SafeERC20 for IERC20;

    string private constant INVALID_USER = "err-invalid-user";
    string private constant UNDER_COLL = "err-under-coll";
    uint8 private constant version = 2;
    bytes32 private constant vaultType = bytes32("EUROs");
    bytes32 private immutable NATIVE;

    address public owner;
    uint256 private minted;
    bool private liquidated;
    ISmartVaultManager public manager;
    IEUROs public EUROs;
    IPriceCalculator public calculator;

    constructor(bytes32 _native, address _manager, address _owner, address _euros, address _priceCalculator) {
        NATIVE = _native;
        owner = _owner;
        manager = ISmartVaultManager(_manager);
        EUROs = IEUROs(_euros);
        calculator = IPriceCalculator(_priceCalculator);
    }

    modifier onlyOwnerOrVaultManager {
        require(msg.sender == owner || msg.sender == address(manager), INVALID_USER);
        _;
    }

    modifier onlyVaultManager {
        require(msg.sender == address(manager), INVALID_USER);
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, INVALID_USER);
        _;
    }

    modifier ifMinted(uint256 _amount) {
        require(minted >= _amount, "err-insuff-minted");
        _;
    }

    function getTokenManager() private view returns (ITokenManager) {
        return ITokenManager(manager.tokenManager());
    }

    function euroCollateral() private view returns (uint256 euros) {
        ITokenManager tokenManager = ITokenManager(manager.tokenManager());
        ITokenManager.Token[] memory acceptedTokens = tokenManager.getAcceptedTokens();
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            ITokenManager.Token memory token = acceptedTokens[i];
            euros += calculator.tokenToEur(token, getAssetBalance(token.symbol, token.addr));
        }
    }

    function maxMintable() private view returns (uint256) {
        return euroCollateral() * manager.HUNDRED_PC() / manager.collateralRate();
    }

    function getAssetBalance(bytes32 _symbol, address _tokenAddress) private view returns (uint256 amount) {
        return _symbol == NATIVE ? address(this).balance : IERC20(_tokenAddress).balanceOf(address(this));
    }

    function getAssets() private view returns (Asset[] memory) {
        ITokenManager tokenManager = ITokenManager(manager.tokenManager());
        ITokenManager.Token[] memory acceptedTokens = tokenManager.getAcceptedTokens();
        Asset[] memory assets = new Asset[](acceptedTokens.length);
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            ITokenManager.Token memory token = acceptedTokens[i];
            uint256 assetBalance = getAssetBalance(token.symbol, token.addr);
            assets[i] = Asset(token, assetBalance, calculator.tokenToEur(token, assetBalance));
        }
        return assets;
    }

    function status() external view returns (Status memory) {
        return Status(
            address(this), minted, maxMintable(), euroCollateral(), getAssets(),
            liquidated, version, vaultType
        );
    }

    function undercollateralised() public view returns (bool) {
        return minted > maxMintable();
    }

    function liquidateNative() private {
        (bool sent,) = payable(manager.protocol()).call{value: address(this).balance}("");
        require(sent, "err-native-liquidate");
    }

    function liquidateERC20(IERC20 _token) private {
        _token.safeTransfer(manager.protocol(), _token.balanceOf(address(this)));
    }

    function liquidate() external onlyVaultManager {
        require(undercollateralised(), "err-not-liquidatable");
        liquidated = true;
        minted = 0;
        liquidateNative();
        ITokenManager.Token[] memory tokens = ITokenManager(manager.tokenManager()).getAcceptedTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].symbol != NATIVE) liquidateERC20(IERC20(tokens[i].addr));
        }
    }

    receive() external payable {}

    function canRemoveCollateral(ITokenManager.Token memory _token, uint256 _amount) private view returns (bool) {
        if (minted == 0) return true;
        uint256 currentMintable = maxMintable();
        uint256 eurValueToRemove = calculator.tokenToEur(_token, _amount);
        return currentMintable >= eurValueToRemove &&
            minted <= currentMintable - eurValueToRemove;
    }

    function removeCollateralNative(uint256 _amount, address payable _to) external onlyOwnerOrVaultManager {
        require(canRemoveCollateral(getTokenManager().getToken(NATIVE), _amount), UNDER_COLL);
        (bool sent,) = _to.call{value: _amount}("");
        require(sent, "err-native-call");
    }

    function removeCollateral(bytes32 _symbol, uint256 _amount, address _to) external onlyOwnerOrVaultManager {
        ITokenManager.Token memory token = getTokenManager().getToken(_symbol);
        require(canRemoveCollateral(token, _amount), UNDER_COLL);
        IERC20(token.addr).safeTransfer(_to, _amount);
    }

    function removeAsset(address _tokenAddr, uint256 _amount, address _to) external onlyOwnerOrVaultManager {
        require(IERC20(_tokenAddr).balanceOf(address(this)) > 0, "err-insuff-funds");
        ITokenManager.Token memory token = getTokenManager().getTokenIfExists(_tokenAddr);
        if (token.addr == _tokenAddr) require(canRemoveCollateral(token, _amount), UNDER_COLL);
        IERC20(_tokenAddr).safeTransfer(_to, _amount);
    }

    function fullyCollateralised(uint256 _amount) private view returns (bool) {
        return minted + _amount <= maxMintable();
    }

    function mint(address _to, uint256 _amount) external onlyOwnerOrVaultManager {
        uint256 fee = _amount * manager.mintFeeRate() / manager.HUNDRED_PC();
        require(fullyCollateralised(_amount + fee), UNDER_COLL);
        minted += _amount + fee;
        EUROs.mint(_to, _amount);
        EUROs.mint(manager.protocol(), fee);
    }

    function burn(uint256 _amount) external ifMinted(_amount) {
        uint256 fee = _amount * manager.burnFeeRate() / manager.HUNDRED_PC();
        minted -= _amount;
        EUROs.burn(msg.sender, _amount);
        IERC20(address(EUROs)).safeTransferFrom(msg.sender, manager.protocol(), fee);
    }

    function setOwner(address _newOwner) external onlyVaultManager {
        owner = _newOwner;
    }
}

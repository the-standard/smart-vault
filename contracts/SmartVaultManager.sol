// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/interfaces/ISEuro.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/ISmartVaultDeployer.sol";
import "contracts/interfaces/ISmartVaultManager.sol";
import "contracts/interfaces/ITokenManager.sol";

contract SmartVaultManager is ISmartVaultManager, ERC721, Ownable {
    using SafeERC20 for IERC20;
    
    string private constant INVALID_ADDRESS = "err-invalid-address";

    address public protocol;
    ISEuro public seuro;
    uint256 public collateralRate;
    uint256 public feeRate;
    address public tokenManager;
    address public liquidator;
    ISmartVaultDeployer public smartVaultDeployer;
    mapping(address => uint256[]) private tokenIds;
    mapping(uint256 => address payable) private vaultAddresses;

    uint256 private currentToken;

    struct SmartVaultData { uint256 tokenId; address vaultAddress; uint256 collateralRate; uint256 feeRate; ISmartVault.Status status; }

    constructor(uint256 _collateralRate, uint256 _feeRate, address _seuro, address _protocol, address _tokenManager, address _smartVaultDeployer) ERC721("The Standard Smart Vault Manager", "TSVAULTMAN") {
        collateralRate = _collateralRate;
        seuro = ISEuro(_seuro);
        feeRate = _feeRate;
        protocol = _protocol;
        tokenManager = _tokenManager;
        smartVaultDeployer = ISmartVaultDeployer(_smartVaultDeployer);
    }

    modifier onlyVaultOwner(uint256 _tokenId) {
        require(msg.sender == ownerOf(_tokenId), "err-not-owner");
        _;
    }

    modifier onlyLiquidator() {
        require(msg.sender == liquidator, "err-invalid-user");
        _;
    }

    function getVault(uint256 _tokenId) private view returns (ISmartVault) {
        return ISmartVault(vaultAddresses[_tokenId]);
    }

    function vaults() external view returns (SmartVaultData[] memory) {
        uint256[] memory userTokens = tokenIds[msg.sender];
        SmartVaultData[] memory vaultData = new SmartVaultData[](userTokens.length);
        for (uint256 i = 0; i < userTokens.length; i++) {
            uint256 tokenId = userTokens[i];
            vaultData[i] = SmartVaultData({
                tokenId: tokenId,
                vaultAddress: vaultAddresses[tokenId],
                collateralRate: collateralRate,
                feeRate: feeRate,
                status: getVault(tokenId).status()
            });
        }
        return vaultData;
    }

    function mint() external returns (address vault, uint256 tokenId) {
        // SmartVault smartVault = new SmartVault(address(this), msg.sender, seuro);
        vault = smartVaultDeployer.deploy(address(this), msg.sender, address(seuro));
        tokenId = ++currentToken;
        vaultAddresses[tokenId] = payable(vault);
        _mint(msg.sender, tokenId);
        seuro.grantRole(seuro.MINTER_ROLE(), vault);
        seuro.grantRole(seuro.BURNER_ROLE(), vault);
    }

    function addCollateralETH(uint256 _tokenId) external payable onlyVaultOwner(_tokenId) {
        (bool sent,) = vaultAddresses[_tokenId].call{value: msg.value}("");
        require(sent, "err-eth-transfer");
    }

    function addCollateral(uint256 _tokenId, bytes32 _token, uint256 _value) external onlyVaultOwner(_tokenId) {
        IERC20(ITokenManager(tokenManager).getAddressOf(_token))
            .safeTransferFrom(msg.sender, vaultAddresses[_tokenId], _value);
    }

    function removeCollateralETH(uint256 _tokenId, uint256 _amount) external onlyVaultOwner(_tokenId) {
        ISmartVault(vaultAddresses[_tokenId]).removeCollateralETH(_amount, payable(msg.sender));
    }

    function removeCollateral(uint256 _tokenId, bytes32 _symbol, uint256 _amount) external onlyVaultOwner(_tokenId) {
        ISmartVault(vaultAddresses[_tokenId]).removeCollateral(_symbol, _amount, msg.sender);
    }

    function removeAsset(uint256 _tokenId, address _token, uint256 _amount) external onlyVaultOwner(_tokenId) {
        ISmartVault(vaultAddresses[_tokenId]).removeAsset(_token, _amount, msg.sender);
    }

    function mintSEuro(uint256 _tokenId, uint256 _amount) external onlyVaultOwner(_tokenId) {
        getVault(_tokenId).mint(msg.sender, _amount);
    }

    function burnSEuro(uint256 _tokenId, uint256 _amount) external {
        ISmartVault vault = getVault(_tokenId);
        SafeERC20.safeTransferFrom(seuro, msg.sender, address(this), _amount);
        SafeERC20.safeApprove(seuro, address(vault), _amount);
        vault.burn(_amount);
    }

    function removeTokenId(address _user, uint256 _tokenId) private {
        uint256[] memory currentIds = tokenIds[_user];
        delete tokenIds[_user];
        for (uint256 i = 0; i < currentIds.length; i++) {
            if (currentIds[i] != _tokenId) tokenIds[_user].push(currentIds[i]);
        }
    }

    function liquidateVaults() external onlyLiquidator {

    }

    function _afterTokenTransfer(address _from, address _to, uint256 _tokenId, uint256) internal override {
        removeTokenId(_from, _tokenId);
        tokenIds[_to].push(_tokenId);
        if (address(_from) != address(0)) ISmartVault(vaultAddresses[_tokenId]).setOwner(_to);
    }

    function setTokenManager(address _tokenManager) external onlyOwner {
        require(_tokenManager != address(tokenManager) && _tokenManager != address(0), INVALID_ADDRESS);
        tokenManager = _tokenManager;
    }

    function setLiquidator(address _liquidator) external onlyOwner {
        require(_liquidator != address(liquidator) && _liquidator != address(0), INVALID_ADDRESS);
        liquidator = _liquidator;
    }
}

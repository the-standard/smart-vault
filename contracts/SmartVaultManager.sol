// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/ISmartVaultDeployer.sol";

contract SmartVaultManager is ERC721, Ownable {
    address public protocol;
    address public seuro;
    uint256 public collateralRate;
    uint256 public feeRate;
    address public tokenManager;
    ISmartVaultDeployer public smartVaultDeployer;
    mapping(address => uint256[]) private tokenIds;
    mapping(uint256 => address payable) private vaultAddresses;

    uint256 private currentToken;

    struct SmartVaultData { uint256 tokenId; address vaultAddress; uint256 collateralRate; uint256 feeRate; ISmartVault.Status status; }

    constructor(uint256 _collateralRate, uint256 _feeRate, address _seuro, address _protocol, address _tokenManager, address _smartVaultDeployer) ERC721("The Standard Smart Vault Manager", "TSVAULTMAN") {
        collateralRate = _collateralRate;
        seuro = _seuro;
        feeRate = _feeRate;
        protocol = _protocol;
        tokenManager = _tokenManager;
        smartVaultDeployer = ISmartVaultDeployer(_smartVaultDeployer);
    }

    modifier onlyVaultOwner(uint256 _tokenId) {
        require(msg.sender == ownerOf(_tokenId), "err-not-owner");
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
        vault = smartVaultDeployer.deploy(address(this), msg.sender, seuro);
        tokenId = ++currentToken;
        vaultAddresses[tokenId] = payable(vault);
        _mint(msg.sender, tokenId);
        // TODO give minter rights to new vault (manager will have to be minter admin)
    }

    function addCollateralETH(uint256 _tokenId) external payable onlyVaultOwner(_tokenId) {
        (bool sent,) = vaultAddresses[_tokenId].call{value: msg.value}("");
        require(sent);
    }

    function mintSEuro(uint256 _tokenId, address _to, uint256 _amount) external onlyVaultOwner(_tokenId) {
        getVault(_tokenId).mint(_to, _amount);
    }

    function removeTokenId(address _user, uint256 _tokenId) private {
        uint256[] memory currentIds = tokenIds[_user];
        delete tokenIds[_user];
        for (uint256 i = 0; i < currentIds.length; i++) {
            if (currentIds[i] != _tokenId) tokenIds[_user].push(currentIds[i]);
        }
    }

    function _afterTokenTransfer(address _from, address _to, uint256 _tokenId, uint256) internal override {
        removeTokenId(_from, _tokenId);
        tokenIds[_to].push(_tokenId);
        if (address(_from) != address(0)) ISmartVault(vaultAddresses[_tokenId]).setOwner(_to);
    }

    function setTokenManager(address _tokenManager) external onlyOwner {
        require(_tokenManager != address(tokenManager) && _tokenManager != address(0));
        tokenManager = _tokenManager;
    }
}

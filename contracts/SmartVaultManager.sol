// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/interfaces/ISEuro.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/ISmartVaultDeployer.sol";
import "contracts/interfaces/ISmartVaultIndex.sol";
import "contracts/interfaces/ISmartVaultManager.sol";
import "contracts/interfaces/ITokenManager.sol";

contract SmartVaultManager is ISmartVaultManager, Initializable, ERC721Upgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    
    string private constant INVALID_ADDRESS = "err-invalid-address";
    uint256 public constant HUNDRED_PC = 100000;

    address public protocol;
    address public seuro;
    uint256 public collateralRate;
    uint256 public feeRate;
    address public tokenManager;
    address public smartVaultDeployer;
    ISmartVaultIndex private smartVaultIndex;

    uint256 private lastToken;

    struct SmartVaultData { uint256 tokenId; address vaultAddress; uint256 collateralRate; uint256 feeRate; ISmartVault.Status status; }

    function initialize(uint256 _collateralRate, uint256 _feeRate, address _seuro, address _protocol, address _tokenManager, address _smartVaultDeployer, address _smartVaultIndex) initializer public {
        __ERC721_init("The Standard Smart Vault Manager", "TSVAULTMAN");
        __Ownable_init();
        collateralRate = _collateralRate;
        seuro = _seuro;
        feeRate = _feeRate;
        protocol = _protocol;
        tokenManager = _tokenManager;
        smartVaultDeployer = _smartVaultDeployer;
        smartVaultIndex = ISmartVaultIndex(_smartVaultIndex);
    }

    function vaults() external view returns (SmartVaultData[] memory) {
        uint256[] memory tokenIds = smartVaultIndex.getTokenIds(msg.sender);
        SmartVaultData[] memory vaultData = new SmartVaultData[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            address vaultAddress = smartVaultIndex.getVaultAddress(tokenId);
            vaultData[i] = SmartVaultData({
                tokenId: tokenId,
                vaultAddress: vaultAddress,
                collateralRate: collateralRate,
                feeRate: feeRate,
                status: ISmartVault(vaultAddress).status()
            });
        }
        return vaultData;
    }

    function mint() external returns (address vault, uint256 tokenId) {
        vault = ISmartVaultDeployer(smartVaultDeployer).deploy(address(this), msg.sender, seuro);
        tokenId = ++lastToken;
        smartVaultIndex.addVaultAddress(tokenId, payable(vault));
        _mint(msg.sender, tokenId);
        ISEuro(seuro).grantRole(ISEuro(seuro).MINTER_ROLE(), vault);
        ISEuro(seuro).grantRole(ISEuro(seuro).BURNER_ROLE(), vault);
    }

    function liquidateVaults() external {
        bool liquidating;
        for (uint256 i = 1; i <= lastToken; i++) {
            ISmartVault vault = ISmartVault(smartVaultIndex.getVaultAddress(i));
            if (vault.undercollateralised()) {
                liquidating = true;
                vault.liquidate();
            }
        }
        require(liquidating, "no-liquidatable-vaults");
    }

    function _afterTokenTransfer(address _from, address _to, uint256 _tokenId, uint256) internal override {
        smartVaultIndex.transferTokenId(_from, _to, _tokenId);
        if (address(_from) != address(0)) ISmartVault(smartVaultIndex.getVaultAddress(_tokenId)).setOwner(_to);
    }
}

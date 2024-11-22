// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/interfaces/INFTMetadataGenerator.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/ISmartVaultDeployer.sol";
import "contracts/interfaces/ISmartVaultIndex.sol";
import "contracts/interfaces/ISmartVaultManager.sol";
import "contracts/interfaces/ISmartVaultManagerV2.sol";
import "contracts/interfaces/ISmartVaultManagerV3.sol";
import "contracts/interfaces/IUSDs.sol";

//
// TODO describe changes
// TODO upgraded zz/zz/zz
//
contract SmartVaultManagerV7 is
    ISmartVaultManagerV3,
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 public constant HUNDRED_PC = 1e5;

    address public protocol;
    address public usds;
    uint256 public collateralRate;
    address public tokenManager;
    address public smartVaultDeployer;
    ISmartVaultIndex private smartVaultIndex;
    uint256 private lastToken;
    address public nftMetadataGenerator;
    uint256 public mintFeeRate;
    uint256 public burnFeeRate;
    uint256 public swapFeeRate;
    address public weth;
    address public swapRouter;
    uint16 public userVaultLimit;
    address public yieldManager;

    event VaultDeployed(address indexed vaultAddress, address indexed owner, address vaultType, uint256 tokenId);
    event VaultLiquidated(address indexed vaultAddress);
    event VaultTransferred(uint256 indexed tokenId, address from, address to);

    struct SmartVaultData {
        uint256 tokenId;
        uint256 collateralRate;
        uint256 mintFeeRate;
        uint256 burnFeeRate;
        ISmartVault.Status status;
    }

    function initialize(
        uint256 _collateralRate,
        uint256 _feeRate,
        address _usds,
        address _protocol,
        address _tokenManager,
        address _smartVaultDeployer,
        address _smartVaultIndex,
        address _nftMetadataGenerator,
        uint16 _userVaultLimit
    ) public initializer {
        __ERC721_init("The Standard Smart Vault Manager (USDs)", "TS-VAULTMAN-USDs");
        __Ownable_init(msg.sender);
        collateralRate = _collateralRate;
        usds = _usds;
        mintFeeRate = _feeRate;
        burnFeeRate = _feeRate;
        swapFeeRate = _feeRate;
        protocol = _protocol;
        tokenManager = _tokenManager;
        smartVaultDeployer = _smartVaultDeployer;
        smartVaultIndex = ISmartVaultIndex(_smartVaultIndex);
        nftMetadataGenerator = _nftMetadataGenerator;
        userVaultLimit = _userVaultLimit;
    }

    function vaultIDs(address _holder) public view returns (uint256[] memory) {
        return smartVaultIndex.getTokenIds(_holder);
    }

    function vaultData(uint256 _tokenID) external view returns (SmartVaultData memory) {
        return SmartVaultData({
            tokenId: _tokenID,
            collateralRate: collateralRate,
            mintFeeRate: mintFeeRate,
            burnFeeRate: burnFeeRate,
            status: ISmartVault(smartVaultIndex.getVaultAddress(_tokenID)).status()
        });
    }

    function mint() external returns (address vault, uint256 tokenId) {
        tokenId = lastToken + 1;
        _safeMint(msg.sender, tokenId);
        lastToken = tokenId;
        vault = ISmartVaultDeployer(smartVaultDeployer).deploy(address(this), msg.sender, usds);
        smartVaultIndex.addVaultAddress(tokenId, payable(vault));
        IUSDs(usds).grantRole(IUSDs(usds).MINTER_ROLE(), vault);
        IUSDs(usds).grantRole(IUSDs(usds).BURNER_ROLE(), vault);
        emit VaultDeployed(vault, msg.sender, usds, tokenId);
    }

    function liquidateVault(uint256 _tokenId) external {
        ISmartVault vault = ISmartVault(smartVaultIndex.getVaultAddress(_tokenId));
        IUSDs(usds).burn(msg.sender, vault.status().minted);
        IUSDs(usds).revokeRole(IUSDs(usds).MINTER_ROLE(), address(vault));
        IUSDs(usds).revokeRole(IUSDs(usds).BURNER_ROLE(), address(vault));
        vault.liquidate(msg.sender);
        emit VaultLiquidated(address(vault));
    }

    function vaultAutoRedemption(
        uint256 _tokenID,
        address _collateralAddr,
        bytes memory _swapPath,
        uint256 _collateralAmount,
        address _hypervisor
    ) external onlyOwner returns (uint256 _amountOut) {
        return _hypervisor == address(0) ?
            ISmartVault(smartVaultIndex.getVaultAddress(_tokenID)).autoRedemption(
                swapRouter, _collateralAddr, _swapPath, _collateralAmount
            ) : 
            ISmartVault(smartVaultIndex.getVaultAddress(_tokenID)).autoWithdrawAndRedemption(
                swapRouter, _collateralAddr, _swapPath, _collateralAmount, _hypervisor
            );
    }

    // TODO maintain vault liquidations with old vault liquidate interface for EUROs

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        ISmartVault.Status memory vaultStatus = ISmartVault(smartVaultIndex.getVaultAddress(_tokenId)).status();
        return INFTMetadataGenerator(nftMetadataGenerator).generateNFTMetadata(_tokenId, vaultStatus);
    }

    function totalSupply() external view returns (uint256) {
        return lastToken;
    }

    function setMintFeeRate(uint256 _rate) external onlyOwner {
        mintFeeRate = _rate;
    }

    function setBurnFeeRate(uint256 _rate) external onlyOwner {
        burnFeeRate = _rate;
    }

    function setSwapFeeRate(uint256 _rate) external onlyOwner {
        swapFeeRate = _rate;
    }

    function setWethAddress(address _weth) external onlyOwner {
        weth = _weth;
    }

    function setSwapRouter(address _swapRouter) external onlyOwner {
        swapRouter = _swapRouter;
    }

    function setNFTMetadataGenerator(address _nftMetadataGenerator) external onlyOwner {
        nftMetadataGenerator = _nftMetadataGenerator;
    }

    function setSmartVaultDeployer(address _smartVaultDeployer) external onlyOwner {
        smartVaultDeployer = _smartVaultDeployer;
    }

    function setProtocolAddress(address _protocol) external onlyOwner {
        protocol = _protocol;
    }

    function setUserVaultLimit(uint16 _userVaultLimit) external onlyOwner {
        userVaultLimit = _userVaultLimit;
    }

    function setYieldManager(address _yieldManager) external onlyOwner {
        yieldManager = _yieldManager;
    }

    function _update(address _to, uint256 _tokenID, address _auth) internal virtual override returns (address) {
        address _from = super._update(_to, _tokenID, _auth);
        require(vaultIDs(_to).length < userVaultLimit, "err-vault-limit");
        smartVaultIndex.transferTokenId(_from, _to, _tokenID);
        if (address(_from) != address(0)) ISmartVault(smartVaultIndex.getVaultAddress(_tokenID)).setOwner(_to);
        emit VaultTransferred(_tokenID, _from, _to);
        return _from;
    }
}
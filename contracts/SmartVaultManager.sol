// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "contracts/interfaces/IChainlink.sol";
import "contracts/SmartVault.sol";
import "hardhat/console.sol";

contract SmartVaultManager is ERC721 {
    uint256 public constant hundredPC = 100000;

    address public protocol;
    address public seuro;
    uint256 public collateralRate;
    uint256 public feeRate;
    IChainlink public clEthUsd;
    IChainlink public clEurUsd;
    mapping(address => uint256[]) public tokenIds;
    mapping(uint256 => address) public vaultAddresses;

    uint256 private currentToken;

    struct SmartVaultData { uint256 tokenId; address vaultAddress; uint256 collateral; uint256 minted; uint256 collateralRate; uint256 feeRate; }

    constructor(uint256 _collateralRate, uint256 _feeRate, address _seuro, address _clEthUsd, address _clEurUsd, address _protocol) ERC721("The Standard Smart Vault Manager", "TSTVAULTMAN") {
        collateralRate = _collateralRate;
        clEthUsd = IChainlink(_clEthUsd);
        clEurUsd = IChainlink(_clEurUsd);
        seuro = _seuro;
        feeRate = _feeRate;
        protocol = _protocol;
    }

    function getVault(uint256 _tokenId) private view returns (SmartVault) {
        return SmartVault(vaultAddresses[_tokenId]);
    }

    function vaults() external view returns (SmartVaultData[] memory) {
        uint256[] memory userTokens = tokenIds[msg.sender];
        SmartVaultData[] memory vaultData = new SmartVaultData[](userTokens.length);
        for (uint256 i = 0; i < userTokens.length; i++) {
            uint256 tokenId = userTokens[i];
            SmartVault.Status memory status = getVault(tokenId).status();
            vaultData[i] = SmartVaultData({
                tokenId: tokenId,
                vaultAddress: vaultAddresses[tokenId],
                collateral: status.collateral,
                minted: status.minted,
                collateralRate: collateralRate,
                feeRate: feeRate
            });
        }
        return vaultData;
    }

    function mint() external returns (address vault, uint256 tokenId) {
        SmartVault smartVault = new SmartVault(address(this), msg.sender, seuro);
        vault = address(smartVault);
        tokenId = ++currentToken;
        tokenIds[msg.sender].push(tokenId);
        vaultAddresses[tokenId] = vault;
        _mint(msg.sender, tokenId);
        // TODO give minter rights to new vault (manager will have to be minter admin)
    }

    function addCollateralETH(uint256 _tokenId) external payable {
        // TODO check sender is token owner (with test)
        getVault(_tokenId).addCollateralETH{value: msg.value}();
    }

    function mintSEuro(uint256 _tokenId, address _to, uint256 _amount) external {
        getVault(_tokenId).mint(_to, _amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/ISmartVaultIndex.sol";

contract SmartVaultIndex is ISmartVaultIndex {
    mapping(address => uint256[]) private tokenIds;
    mapping(uint256 => address payable) private vaultAddresses;

    function getTokenIds(address _user) external view returns (uint256[] memory) {
        return tokenIds[_user];
    }

    function getVaultAddress(uint256 _tokenId) external view returns (address payable) {
        return vaultAddresses[_tokenId];
    }

    function addVaultAddress(uint256 _tokenId, address payable _vault) external {
        vaultAddresses[_tokenId] = _vault;
    }

    function removeTokenId(address _user, uint256 _tokenId) private {
        uint256[] memory currentIds = tokenIds[_user];
        delete tokenIds[_user];
        for (uint256 i = 0; i < currentIds.length; i++) {
            if (currentIds[i] != _tokenId) tokenIds[_user].push(currentIds[i]);
        }
    }

    function transferTokenId(address _from, address _to, uint256 _tokenId) external {
        removeTokenId(_from, _tokenId);
        tokenIds[_to].push(_tokenId);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/contracts/utils/Base64.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/INFTMetadataGenerator.sol";

contract MockNFTMetadataGenerator is INFTMetadataGenerator {
    function generateNFTMetadata(uint256 _tokenId, ISmartVault.Status memory _vaultStatus)
        external
        view
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        "{",
                        '"name": "The Standard Smart Vault #',
                        '"description": "The Standard Smart Vault',
                        '"attributes": [',
                        "],",
                        '"image_data": "',
                        '"',
                        "}"
                    )
                )
            )
        );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/INFTMetadataGenerator.sol";

contract NFTMetadataGenerator is INFTMetadataGenerator {
    using Strings for uint256;

    // take bytes32 and return a string
    function toShortString(bytes32 _data) pure public returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint8 i = 0; i < 32; i++) {
            bytes1 char = _data[i];
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint8 j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    function mapCollateral(ISmartVault.Asset[] memory _collateral) private pure returns (string memory collateralTraits) {
        collateralTraits = "";
        for (uint256 i = 0; i < _collateral.length; i++) {
            ISmartVault.Asset memory asset = _collateral[i];
            collateralTraits = string(abi.encodePacked(collateralTraits, '{"trait_type":"', toShortString(asset.symbol), '", ','"display_type": "boost_number",','"value": ',(asset.amount / 1 ether).toString(),'},'));
        }
    }

    function generateSvg(uint256 _tokenId, ISmartVault.Status memory _vaultStatus) private pure returns (string memory) {
        bytes memory svg = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
                "<style>.header { font-weight: 700; } .base { fill: #6cf; font-family: Arial, Helvetica, sans-serif; font-size: 12px; }</style>",
                '<rect width="100%" height="100%" fill="rgb(40,40,40)" />',
                '<text x="50%" y="20%" class="header base" dominant-baseline="middle" text-anchor="middle">',
                    "The Standard Smart Vault #",_tokenId.toString()," (",toShortString(_vaultStatus.vaultType),")",
                "</text>",
                '<text x="50%" y="30%" class="base" dominant-baseline="middle" text-anchor="middle">',
                    "Version: ", uint256(_vaultStatus.version).toString(),
                "</text>",
                '<text x="50%" y="40%" class="base" dominant-baseline="middle" text-anchor="middle">',
                    "Borrowed: ", (_vaultStatus.minted / 1 ether).toString(), " sEURO",
                "</text>",
                '<text x="50%" y="50%" class="base" dominant-baseline="middle" text-anchor="middle">',
                    "Current Borrow Limit: ", (_vaultStatus.maxMintable / 1 ether).toString(), " sEURO",
                "</text>",
                '<text x="50%" y="60%" class="base" dominant-baseline="middle" text-anchor="middle">',
                    "Collateral %: ", (_vaultStatus.currentCollateralPercentage / 1000).toString(), "%",
                "</text>",
            "</svg>"
        );
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(svg)
                )
            );
    }

    function generateNFTMetadata(uint256 _tokenId, ISmartVault.Status memory _vaultStatus) external pure returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            "{",
                '"name": "The Standard Smart Vault #',_tokenId.toString(),'",',
                '"description": "The Standard Smart Vault (',toShortString(_vaultStatus.vaultType),')",',
                '"attributes": [',
                    '{"trait_type": "Status", "value": "',_vaultStatus.liquidated ?"liquidated":"active",'"},',
                    '{"trait_type": "Borrowed",  "display_type": "number", "value": ', (_vaultStatus.minted / 1 ether).toString(),'},',
                    '{"trait_type": "Max Borrowable Amount", "display_type": "number", "value": "',(_vaultStatus.maxMintable / 1 ether).toString(),'"},',
                    '{"trait_type": "Collateral %", "display_type": "number", "value": ',(_vaultStatus.currentCollateralPercentage / 1000).toString(),'},',
                    mapCollateral(_vaultStatus.collateral),
                    '{"trait_type": "Version", "value": "',uint256(_vaultStatus.version).toString(),'"},',
                    '{"trait_type": "Vault Type", "value": "',toShortString(_vaultStatus.vaultType),'"}',
                '],',
                '"image": "',generateSvg(_tokenId, _vaultStatus),'"',
            "}"
        );
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(dataURI)
                )
            );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/INFTMetadataGenerator.sol";

contract NFTMetadataGenerator is INFTMetadataGenerator {
    using Strings for uint256;

    uint256 private constant TABLE_ROW_HEIGHT = 117;
    uint256 private constant TABLE_ROW_WIDTH = 2110;
    uint256 private constant TABLE_INITIAL_Y = 944;
    uint256 private constant TABLE_INITIAL_X = 2127;

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

    function padFraction(bytes memory _input, uint8 _dec) private pure returns (bytes memory fractionalPartPadded) {
        fractionalPartPadded = new bytes(_dec);
        uint256 i = fractionalPartPadded.length;
        uint256 j = _input.length;
        bool smallestCharacterAppended;
        while(i > 0) {
            i--;
            if (j > 0) {
                j--;
                if (_input[j] != bytes1("0") || smallestCharacterAppended) {
                    fractionalPartPadded[i] = _input[j];
                    smallestCharacterAppended = true;
                } else {
                    fractionalPartPadded = new bytes(fractionalPartPadded.length - 1);
                }
            } else {
                fractionalPartPadded[i] = "0";
            }
        }
    }

    function truncateFraction(bytes memory _input, uint8 _places) private pure returns (bytes memory truncated) {
        truncated = new bytes(_places);
        for (uint256 i = 0; i < _places; i++) {
            truncated[i] = _input[i];
        }
    }

    function toDecimalString(uint256 _amount, uint8 _inputDec) private pure returns (string memory) {
        uint8 maxDecPlaces = 5;
        string memory wholePart = (_amount / 10 ** _inputDec).toString();
        uint256 fraction = _amount % 10 ** _inputDec;
        if (fraction == 0) return wholePart;
        bytes memory fractionalPart = bytes(fraction.toString());
        bytes memory fractionalPartPadded = padFraction(fractionalPart, _inputDec);
        if (fractionalPartPadded.length > maxDecPlaces) fractionalPartPadded = truncateFraction(fractionalPartPadded, maxDecPlaces);
        return string(abi.encodePacked(wholePart, ".", fractionalPartPadded));
    }

    function mapCollateralForJSON(ISmartVault.Asset[] memory _collateral) private pure returns (string memory collateralTraits) {
        collateralTraits = "";
        for (uint256 i = 0; i < _collateral.length; i++) {
            ISmartVault.Asset memory asset = _collateral[i];
            collateralTraits = string(abi.encodePacked(collateralTraits, '{"trait_type":"', toShortString(asset.symbol), '", ','"display_type": "number",','"value": ',toDecimalString(asset.amount, 18),'},'));
        }
    }

    function mapCollateralForSVG(ISmartVault.Asset[] memory _collateral) private pure returns (string memory displayText, uint256 collateralSize) {
        displayText = "";
        uint256 paddingTop = 84;
        uint256 paddingLeftSymbol = 37;
        uint256 paddingLeftAmount = paddingLeftSymbol + 300;
        collateralSize = 0;
        for (uint256 i = 0; i < _collateral.length; i++) {
            ISmartVault.Asset memory asset = _collateral[i];
            uint256 xShift = collateralSize % 2 == 0 ? 0 : TABLE_ROW_WIDTH / 2;
            if (asset.amount > 0) {
                uint256 currentRow = collateralSize / 2;
                uint256 textYPosition = TABLE_INITIAL_Y + currentRow * TABLE_ROW_HEIGHT + paddingTop;
                displayText = string(abi.encodePacked(displayText,
                    '<g id="Collateral',(collateralSize+1).toString(),'">',
                        '<text class="cls-5" transform="translate(',(TABLE_INITIAL_X + xShift + paddingLeftSymbol).toString()," ",textYPosition.toString(),')">',
                            '<tspan x="0" y="0">',toShortString(asset.symbol),"</tspan>",
                        "</text>",
                        '<text class="cls-5" transform="translate(',(TABLE_INITIAL_X + xShift + paddingLeftAmount).toString()," ",textYPosition.toString(),')">',
                            '<tspan x="0" y="0">',toDecimalString(asset.amount, 18),"</tspan>",
                        "</text>",
                    "</g>"));
                collateralSize++;
            }
        }
    }

    function mapRows(uint256 _collateralSize) private pure returns (string memory mappedRows) {
        mappedRows = "";
        uint256 rowCount = (_collateralSize + 1) / 2;
        uint256 highlightRowCount = (rowCount + 1) / 2;
        for (uint256 i = 0; i < highlightRowCount; i++) {
            uint256 y = TABLE_INITIAL_Y+i*TABLE_ROW_HEIGHT;
            mappedRows = string(abi.encodePacked(
                mappedRows, '<rect id="Highlight',(highlightRowCount-i).toString(),'" class="cls-6" x="',TABLE_INITIAL_X.toString(),'" y="',y.toString(),'" width="',TABLE_ROW_WIDTH.toString(),'" height="',TABLE_ROW_HEIGHT.toString(),'"/>'
            ));
        }
        uint256 rowMidpoint = TABLE_INITIAL_X + TABLE_ROW_WIDTH / 2;
        uint256 tableEndY = TABLE_INITIAL_Y + rowCount * TABLE_ROW_HEIGHT;
        mappedRows = string(abi.encodePacked(mappedRows,
        '<line id="Table-split-line" class="cls-1" x1="',rowMidpoint.toString(),'" y1="',TABLE_INITIAL_Y.toString(),'" x2="',rowMidpoint.toString(),'" y2="',tableEndY.toString(),'"/>'));
    }

    function calculateValueMinusDebt(ISmartVault.Status memory _vaultStatus) private pure returns (uint256) {
        uint256 collateralValue = _vaultStatus.minted * _vaultStatus.currentCollateralPercentage / 100000;
        return collateralValue - _vaultStatus.minted;
    }

    function generateSvg(ISmartVault.Status memory _vaultStatus) private pure returns (string memory) {
        (string memory collateralText, uint256 collateralSize) = mapCollateralForSVG(_vaultStatus.collateral);
        bytes memory svg = abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 4995.66 3856.02">',
            '<defs>',
                '<style>',
                '.cls-1 {',
                    'fill: none;',
                    'stroke: #fff;',
                    'stroke-miterlimit: 10;',
                    'stroke-width: 3px;',
                '}',
                '.cls-2 {',
                    'font-size: 53.51px;',
                '}',
                '.cls-2, .cls-3, .cls-4, .cls-5, .cls-6, .cls-7, .cls-8 {',
                    'fill: #fff;',
                '}',
                '.cls-2, .cls-3, .cls-5, .cls-7 {',
                    'font-family: Poppins-Light, Poppins;',
                '}',
                '.cls-3 {',
                    'font-size: 102.5px;',
                '}',
                '.cls-4, .cls-5 {',
                    'font-size: 72px;',
                '}',
                '.cls-4, .cls-8 {',
                    'font-family: Poppins-Bold, Poppins;',
                '}',
                '.cls-6 {',
                    'opacity: .17;',
                '}',
                '.cls-7, .cls-8 {',
                    'font-size: 65.13px;',
                '}',
                '</style>',
            '</defs>',
            '<g id="sEURO-CDP-NFT-BackGround">',
                '<image id="PNG" transform="scale(2.6)" xlink:href="https://i.imgur.com/JOBM02z.png"/>',
            '</g>',
            '<g id="Table">',
                mapRows(collateralSize),
            '</g>',
            '<g id="AllText">',
                '<g id="HeadText">',
                '<text class="cls-3" transform="translate(2151.11 627.51)"><tspan x="0" y="0">The owner of this NFT owns the collateral and debt</tspan></text>',
                '<text class="cls-2" transform="translate(2151.11 726.66)"><tspan x="0" y="0">NOTE: Open Sea caching might show older NFT data, it is up to the buyer to check the blockchain </tspan></text>',
                '</g>',
                '<text class="cls-4" transform="translate(2167.11 887.58)"><tspan x="0" y="0">Collateral</tspan></text>',
                collateralText,
                '<g id="TotalDebt">',
                '<text class="cls-4" transform="translate(2161.46 2422.11)"><tspan x="0" y="0">Debt</tspan></text>',
                '<text class="cls-7" transform="translate(3229.25 2422.11)"><tspan x="0" y="0">',toDecimalString(_vaultStatus.minted, 18),' sEURO</tspan></text>',
                '</g>',
                '<g id="CollateralRatio">',
                '<text class="cls-4" transform="translate(2165.93 2523.81)"><tspan x="0" y="0">Debt/Collateral</tspan></text>',
                '<text class="cls-5" transform="translate(3229.25 2523.81)"><tspan x="0" y="0">',toDecimalString(_vaultStatus.currentCollateralPercentage, 3),'%</tspan></text>',
                '</g>',
                '<g id="TotalValueMinusDebt">',
                '<text class="cls-4" transform="translate(2165.93 2623.54)"><tspan x="0" y="0">Total value minus Debt:</tspan></text>',
                '<text class="cls-8" transform="translate(3227.04 2623.54)"><tspan x="0" y="0">',toDecimalString(calculateValueMinusDebt(_vaultStatus), 18),' sEURO</tspan></text>',
                '</g>',
            '</g>',
            '</svg>'
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
                    mapCollateralForJSON(_vaultStatus.collateral),
                    '{"trait_type": "Version", "value": "',uint256(_vaultStatus.version).toString(),'"},',
                    '{"trait_type": "Vault Type", "value": "',toShortString(_vaultStatus.vaultType),'"}',
                '],',
                '"image": "',generateSvg(_vaultStatus),'"',
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

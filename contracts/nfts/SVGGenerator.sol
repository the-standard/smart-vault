// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/nfts/DefGenerator.sol";
import "contracts/nfts/NFTUtils.sol";

contract SVGGenerator {
    using Strings for uint256;
    using Strings for uint16;

    uint16 private constant TABLE_ROW_HEIGHT = 67;
    uint16 private constant TABLE_ROW_WIDTH = 1235;
    uint16 private constant TABLE_INITIAL_Y = 1250;
    uint16 private constant TABLE_INITIAL_X = 357;
    uint32 private constant HUNDRED_PC = 1e5;

    DefGenerator private immutable defGenerator;

    constructor() {
        defGenerator = new DefGenerator();
    }

    struct CollateralForSVG {string text; uint256 size;}

    function mapCollateralForSVG(ISmartVault.Asset[] memory _collateral) private pure returns (CollateralForSVG memory) {
        string memory displayText = "";
        uint256 paddingTop = 50;
        uint256 paddingLeftSymbol = 22;
        uint256 paddingLeftAmount = paddingLeftSymbol + 250;
        uint256 collateralSize = 0;
        for (uint256 i = 0; i < _collateral.length; i++) {
            ISmartVault.Asset memory asset = _collateral[i];
            uint256 xShift = collateralSize % 2 == 0 ? 0 : TABLE_ROW_WIDTH >> 1;
            if (asset.amount > 0) {
                uint256 currentRow = collateralSize >> 1;
                uint256 textYPosition = TABLE_INITIAL_Y + currentRow * TABLE_ROW_HEIGHT + paddingTop;
                displayText = string(abi.encodePacked(displayText,
                    "<g>",
                        "<text class='cls-8' transform='translate(",(TABLE_INITIAL_X + xShift + paddingLeftSymbol).toString()," ",textYPosition.toString(),")'>",
                            "<tspan x='0' y='0'>",NFTUtils.toShortString(asset.token.symbol),"</tspan>",
                        "</text>",
                        "<text class='cls-8' transform='translate(",(TABLE_INITIAL_X + xShift + paddingLeftAmount).toString()," ",textYPosition.toString(),")'>",
                            "<tspan x='0' y='0'>",NFTUtils.toDecimalString(asset.amount, asset.token.dec),"</tspan>",
                        "</text>",
                    "</g>"
                ));
                collateralSize++;
            }
        }
        if (collateralSize == 0) {
            displayText = string(abi.encodePacked(
                "<g>",
                    "<text class='cls-8' transform='translate(",(TABLE_INITIAL_X + paddingLeftSymbol).toString()," ",(TABLE_INITIAL_Y + paddingTop).toString(),")'>",
                        "<tspan x='0' y='0'>N/A</tspan>",
                    "</text>",
                "</g>"
            ));
            collateralSize = 1;
        }
        return CollateralForSVG(displayText, collateralSize);
    }

    function mapRows(uint256 _collateralSize) private pure returns (string memory mappedRows) {
        mappedRows = "";
        uint256 rowCount = (_collateralSize + 1) >> 1;
        for (uint256 i = 0; i < (rowCount + 1) >> 1; i++) {
            mappedRows = string(abi.encodePacked(
                mappedRows, "<rect class='cls-9' x='", TABLE_INITIAL_X.toString(), "' y='", (TABLE_INITIAL_Y + i * TABLE_ROW_HEIGHT).toString(), "' width='", TABLE_ROW_WIDTH.toString(), "' height='", TABLE_ROW_HEIGHT.toString(), "'/>"
            ));
        }
        uint256 rowMidpoint = TABLE_INITIAL_X + TABLE_ROW_WIDTH >> 1;
        uint256 tableEndY = TABLE_INITIAL_Y + rowCount * TABLE_ROW_HEIGHT;
        mappedRows = string(abi.encodePacked(mappedRows,
        "<line class='cls-11' x1='",rowMidpoint.toString(),"' y1='",TABLE_INITIAL_Y.toString(),"' x2='",rowMidpoint.toString(),"' y2='",tableEndY.toString(),"'/>"));
    }


    function calculateCollateralLockedWidth(uint256 value) private view returns (string memory) {
        // @return value must be between 0 and 690
        return "690";
    }

    function collateralDebtPecentage(ISmartVault.Status memory _vaultStatus) private pure returns (string memory) {
        return _vaultStatus.minted == 0 ? "N/A" : string(abi.encodePacked(NFTUtils.toDecimalString(HUNDRED_PC * _vaultStatus.totalCollateralValue / _vaultStatus.minted, 3), "%"));
    }

    function generateSvg(uint256 _tokenId, ISmartVault.Status memory _vaultStatus) external view returns (string memory) {
        CollateralForSVG memory collateral = mapCollateralForSVG(_vaultStatus.collateral);
        return
        string(
            abi.encodePacked(
                "<svg width='900' height='900' viewBox='0 0 900 900' fill='none' xmlns='http://www.w3.org/2000/svg'>",
                defGenerator.generateDefs(_tokenId),
                "<style>","text { font-family: Arial; fill: white; font-size=14}","</style>", "<g clip-path='url(#clip0_428_47)'>",
                "<rect width='900' height='900' class='token-",_tokenId.toString(),"-cls-12'/>",
                "<circle cx='52.5' cy='751.5' r='328.5' fill='#FF3BC9'/>", "<g filter='url(#filter0_d_428_47)'>", "<rect x='57' y='153' width='787' height='553' rx='72' fill='url(#paint1_linear_428_47)'/>",
                "<rect x='58.5' y='154.5' width='784' height='550' rx='70.5' stroke='white' stroke-opacity='0.14' stroke-width='3'/>", "</g>",
                "<rect x='57' y='261' width='787' height='445' rx='72' fill='url(#paint2_linear_428_47)'/>", "<rect x='57' y='261' width='787' height='445' rx='72' fill='url(#paint3_radial_428_47)' fill-opacity='0.74'/>",
                "<rect x='58.5' y='262.5' width='784' height='442' rx='70.5' stroke='white' stroke-opacity='0.12' stroke-width='3'/>",
                "<path d='M136.228 203H116.719C112.301 203 108.719 206.582 108.719 211V216.754' stroke='white' stroke-width='4'/>",
                "<path d='M107 230.509H126.509C130.927 230.509 134.509 226.927 134.509 222.509V216.754' stroke='white' stroke-width='4'/>",
                "<text x='115' y='223' font-weight='bold' font-size='18'> &#8364; </text>", "<text x='150' y='223' font-weight='bold' font-size='18'>EUROs SmartVault</text>",
                "<path d='M631 203.246H611.491C607.073 203.246 603.491 206.827 603.491 211.246V217' stroke='white' stroke-width='4'/>",
                "<path d='M601.772 230.754H621.281C625.699 230.754 629.281 227.173 629.281 222.754V217' stroke='white' stroke-width='4'/>",
                "<path d='M614.927 225.473V209.561H618.429V225.473H614.927Z'/>", "<text x='645' y='223' font-weight='bold' font-size='18'>TheStandard.io</text>",
                "<text x='130' y='400' font-size='40' font-weight='900'>THE OWNER OF THIS NFT OWNS</text>", "<text x='170' y='440' font-size='40' font-weight='900'>THE COLLATERAL AND DEBT</text>",
                "<text x='350' y='310' font-size='18'>EUROs SmartVault # ", _tokenId.toString(), "</text>",
                "<text x='145' y='490' text-anchor='middle'>Total Value</text>", "<rect x='107' y='504' width='132' height='40' rx='11' fill='#DA76EE'/>",
                "<text x='170' y='528' font-weight='bold' text-anchor='middle'>&#8364; ", NFTUtils.toDecimalString(_vaultStatus.totalCollateralValue, 18), "</text>",
                "<text x='280' y='490' text-anchor='middle'>Debt</text>", "<rect x='263' y='504' width='132' height='40' rx='11' fill='#9F8CF2'/>",
                "<text x='325' y='528' font-weight='bold' text-anchor='middle'>&#8364;", NFTUtils.toDecimalString(_vaultStatus.minted, 18), "</text>",
                "<text x='470' y='490' text-anchor='middle'>Collateral/Debt</text>", "<rect x='419' y='504' width='132' height='40' rx='11' fill='#979DFA'/>",
                "<text x='485' y='528' font-weight='bold' text-anchor='middle'>", collateralDebtPecentage(_vaultStatus), "</text>", "<text x='720' y='490' text-anchor='middle'>Total Minus Debt</text>",
                "<rect x='662' y='504' width='132' height='40' rx='11' fill='url(#paint4_linear_428_47)'/>",
                "<text x='730' y='528' font-weight='bold' text-anchor='middle'>&#8364;", NFTUtils.toDecimalString(_vaultStatus.totalCollateralValue - _vaultStatus.minted, 18), "</text>",
                "<text x='221' y='622' font-size='18' text-anchor='middle'>Collateral locked in this vault</text>",
                "<text x='790' y='628' font-size='18' font-weight='bold' text-anchor='end'>&#8364; 84 </text>", "<rect x='107' y='640' width='687' height='16' rx='8' fill='#AC99F7'/>",
                "<rect x='107' y='640' width='", calculateCollateralLockedWidth(0), "' height='16' rx='8' fill='white'/>", "</g>", "<defs>",
                "<filter id='filter0_d_428_47' x='-39' y='153' width='919' height='687' filterUnits='userSpaceOnUse' color-interpolation-filters='sRGB'>", "<feFlood flood-opacity='0' result='BackgroundImageFix'/>",
                "<feColorMatrix in='SourceAlpha' type='matrix' values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0' result='hardAlpha'/>", "<feOffset dx='-30' dy='68'/>", "<feGaussianBlur stdDeviation='33'/>", "<feComposite in2='hardAlpha' operator='out'/>",
                "<feColorMatrix type='matrix' values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0'/>", "<feBlend mode='normal' in2='BackgroundImageFix' result='effect1_dropShadow_428_47'/>",
                "<feBlend mode='normal' in='SourceGraphic' in2='effect1_dropShadow_428_47' result='shape'/>", "</filter>", "<linearGradient id='paint0_linear_428_47' x1='-654.5' y1='275.5' x2='347' y2='1261.5' gradientUnits='userSpaceOnUse'>",
                "<stop stop-color='#00FFAA'/>", "<stop offset='0.517251' stop-color='#4579F5'/>", "<stop offset='0.999815' stop-color='#9C42F5'/>", "</linearGradient>",
                "<linearGradient id='paint1_linear_428_47' x1='110' y1='173.5' x2='816.5' y2='692' gradientUnits='userSpaceOnUse'>",
                "<stop stop-color='#3EB0DE'/>", "<stop offset='0.522557' stop-color='#7582F7'/>", "<stop offset='1' stop-color='#A365F7'/>", "</linearGradient>",
                "<linearGradient id='paint2_linear_428_47' x1='105.5' y1='285' x2='797' y2='685' gradientUnits='userSpaceOnUse'>", "<stop stop-color='#52ACE6'/>", "<stop offset='1' stop-color='#A465F7'/>", "</linearGradient>",
                "<radialGradient id='paint3_radial_428_47' cx='0' cy='0' r='1' gradientUnits='userSpaceOnUse' gradientTransform='translate(127.5 673) rotate(-36.8186) scale(335.4 526.783)'>",
                "<stop stop-color='#FF3BC9'/>", "<stop offset='0.402382' stop-color='#FF3BC9'/>", "<stop offset='0.657404' stop-color='#FF3BC9' stop-opacity='0.56'/>", "<stop offset='1' stop-color='#FF3BC9' stop-opacity='0'/>",
                "</radialGradient>", "<linearGradient id='paint4_linear_428_47' x1='665.5' y1='548' x2='810.5' y2='459' gradientUnits='userSpaceOnUse'>",
                "<stop stop-color='#F05BBD'/>", "<stop offset='1' stop-color='#8A28ED'/>", "</linearGradient>", "<clipPath id='clip0_428_47'>", "<rect width='900' height='900' fill='white'/>", "</clipPath>", "</defs>", "</svg>"
            )
        );
    }

}
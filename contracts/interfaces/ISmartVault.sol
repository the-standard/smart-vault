// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ISmartVault {
    struct Asset { bytes32 symbol; uint256 amount; }
    struct Status { uint256 minted; uint256 maxMintable; uint256 currentCollateralPercentage; Asset[] collateral; }

    function status() external view returns (Status memory);
    function undercollateralised() external view returns (bool);
    function removeCollateralETH(uint256 _amount, address payable _to) external;
    function removeCollateral(bytes32 _symbol, uint256 _amount, address _to) external;
    function removeAsset(address _tokenAddr, uint256 _amount, address _to) external;
    function mint(address _to, uint256 _amount) external;
    function burn(uint256 _amount) external;
    function setOwner(address _newOwner) external;
    function liquidate() external;
}
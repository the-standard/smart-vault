const { ethers, upgrades } = require('hardhat');
const { BigNumber } = ethers;

const HUNDRED_PC = BigNumber.from(100000);
const DEFAULT_COLLATERAL_RATE = BigNumber.from(120000); // 120%
const DEFAULT_ETH_USD_PRICE = BigNumber.from(160000000000); // $1600
const DEFAULT_EUR_USD_PRICE = BigNumber.from(106000000); // $1.06
const PROTOCOL_FEE_RATE = BigNumber.from(500); // 0.5%
const ETH = ethers.utils.formatBytes32String('ETH');
const WETH_ADDRESS = '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1';

const getCollateralOf = (symbol, collateral) => collateral.filter(c => c.token.symbol === ethers.utils.formatBytes32String(symbol))[0];

const getNFTMetadataContract = async () => {
  const LibContract = await ethers.getContractFactory('NFTUtils');
  const lib = await LibContract.deploy();
  await lib.deployed();
  return await ethers.getContractFactory('NFTMetadataGenerator', {
    libraries: {
      NFTUtils: lib.address,
    },
  });
}

const fullyUpgradedSmartVaultManager = async (
  collateralRate, protocolFeeRate, eurosAddress, protocolAddress, 
  liquidatorAddress, tokenManagerAddress, smartVaultDeployerAddress,
  smartVaultIndexAddress, nFTMetadataGeneratorAddress, wethAddress, 
  swapRouterAddress
) => {
  const v1 = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManager'), [
    collateralRate, protocolFeeRate, eurosAddress, protocolAddress, 
    liquidatorAddress, tokenManagerAddress, smartVaultDeployerAddress,
    smartVaultIndexAddress, nFTMetadataGeneratorAddress
  ]);

  await upgrades.upgradeProxy(v1.address, await ethers.getContractFactory('SmartVaultManagerNewNFTGenerator'));
  await upgrades.upgradeProxy(v1.address, await ethers.getContractFactory('SmartVaultManagerV2'));
  await upgrades.upgradeProxy(v1.address, await ethers.getContractFactory('SmartVaultManagerV3'));
  const v4 = await upgrades.upgradeProxy(v1.address, await ethers.getContractFactory('SmartVaultManagerV4'));

  await v4.setSwapFeeRate(protocolFeeRate);
  await v4.setWethAddress(wethAddress);
  await v4.setSwapRouterAddress(swapRouterAddress);
  return v4;
}

module.exports = {
  HUNDRED_PC,
  DEFAULT_COLLATERAL_RATE,
  DEFAULT_ETH_USD_PRICE,
  DEFAULT_EUR_USD_PRICE,
  PROTOCOL_FEE_RATE,
  ETH,
  WETH_ADDRESS,
  getCollateralOf,
  getNFTMetadataContract,
  fullyUpgradedSmartVaultManager
}
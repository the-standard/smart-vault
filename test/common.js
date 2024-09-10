const { ethers, upgrades } = require('hardhat');
const { BigNumber } = ethers;

const HUNDRED_PC = BigNumber.from(100000);
const DEFAULT_COLLATERAL_RATE = BigNumber.from(110000); // 110%
const DEFAULT_ETH_USD_PRICE = BigNumber.from(160000000000); // $1600
const PROTOCOL_FEE_RATE = BigNumber.from(500); // 0.5%
const TEST_VAULT_LIMIT = 10;
const DEFAULT_POOL_FEE = 3000;
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
  collateralRate, protocolFeeRate, usdsAddress, protocolAddress, 
  liquidatorAddress, tokenManagerAddress, smartVaultDeployerAddress,
  smartVaultIndexAddress, nFTMetadataGeneratorAddress, wethAddress, 
  swapRouterAddress, vaultLimit, yieldManagerAddress
) => {
  const V6 = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManagerV6'), [
    collateralRate, protocolFeeRate, usdsAddress, protocolAddress, 
    liquidatorAddress, tokenManagerAddress, smartVaultDeployerAddress,
    smartVaultIndexAddress, nFTMetadataGeneratorAddress, vaultLimit
  ]);

  await V6.setWethAddress(wethAddress);
  await V6.setSwapRouter(swapRouterAddress);
  await V6.setYieldManager(yieldManagerAddress);
  return V6;
}

module.exports = {
  HUNDRED_PC,
  DEFAULT_COLLATERAL_RATE,
  DEFAULT_ETH_USD_PRICE,
  PROTOCOL_FEE_RATE,
  ETH,
  TEST_VAULT_LIMIT,
  DEFAULT_POOL_FEE,
  WETH_ADDRESS,
  getCollateralOf,
  getNFTMetadataContract,
  fullyUpgradedSmartVaultManager
}
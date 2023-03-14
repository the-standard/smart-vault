const { ethers } = require('hardhat');
const { BigNumber } = ethers;

const HUNDRED_PC = BigNumber.from(100000);
const DEFAULT_COLLATERAL_RATE = BigNumber.from(120000); // 120%
const DEFAULT_ETH_USD_PRICE = BigNumber.from(125000000000); // $1250
const DEFAULT_EUR_USD_PRICE = BigNumber.from(105000000); // $1.05
const PROTOCOL_FEE_RATE = BigNumber.from(1000); // 1%

const getCollateralOf = (symbol, collateral) => collateral.filter(c => c.symbol === ethers.utils.formatBytes32String(symbol))[0];

const getLibraryFactory = async (signerAccount, linkedContract, libraryName) => {
  const LibContract = await ethers.getContractFactory(libraryName);
  const lib = await LibContract.deploy();
  await lib.deployed();
  const libraries = {};
  libraries[libraryName] = lib.address
  return await ethers.getContractFactory(linkedContract, {
    signer: signerAccount,
    libraries,
  });
}

module.exports = {
  HUNDRED_PC,
  DEFAULT_COLLATERAL_RATE,
  DEFAULT_ETH_USD_PRICE,
  DEFAULT_EUR_USD_PRICE,
  PROTOCOL_FEE_RATE,
  getCollateralOf,
  getLibraryFactory
}
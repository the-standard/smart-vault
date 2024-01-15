const { ethers } = require("hardhat");
const { ETH, DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, getNFTMetadataContract } = require("../test/common");

async function main() {
  const [deployer] = await ethers.getSigners();

  const CL_ETH_USD = '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612';
  const CL_EUR_USD = '0xA14d53bC1F1c0F31B4aA3BD109344E5009051a84';
  const PROTOCOL_ADDRESS = '0x99d5D7C8F40Deba9d0075E8Fff2fB13Da787996a';
  const LIQUIDATOR_ADDRESS = deployer.address;
  const EUROs = await (await ethers.getContractAt('AccessControl', '0x643b34980e635719c15a2d4ce69571a258f940e9'));
  console.log(await EUROs.hasRole(await EUROs.DEFAULT_ADMIN_ROLE(),deployer.address))
  console.log('EUROs', EUROs.address)
  const TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ETH, CL_ETH_USD);
  await TokenManager.deployed();
  console.log('TokenManager', TokenManager.address)
  const Deployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy(ETH, CL_EUR_USD);
  await Deployer.deployed();
  console.log('Deployer', Deployer.address)
  const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
  await SmartVaultIndex.deployed();
  console.log('SmartVaultIndex', SmartVaultIndex.address)
  const NFTMetadataGenerator = await (getNFTMetadataContract()).deploy();
  await NFTMetadataGenerator.deployed();
  console.log('NFTMetadataGenerator', NFTMetadataGenerator.address)
  const SmartVaultManager = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManager'), [
    '110000', 500, EUROs.address, TokenManager.address,
    Deployer.address, SmartVaultIndex.address, NFTMetadataGenerator.address
  ]);
  await SmartVaultManager.deployed();
  console.log('SmartVaultManager', SmartVaultManager.address)

  await (await SmartVaultIndex.setVaultManager(SmartVaultManager.address)).wait();
  await (await EUROs.grantRole(await EUROs.DEFAULT_ADMIN_ROLE(), SmartVaultManager.address));

  console.log({
    EUROs: EUROs.address,
    TokenManager: TokenManager.address,
    Deployer: Deployer.address,
    SmartVaultIndex: SmartVaultIndex.address,
    NFTMetadataGenerator: NFTMetadataGenerator.address,
    SmartVaultManager: SmartVaultManager.address,
  });

  await new Promise(resolve => setTimeout(resolve, 60000));

  await run(`verify:verify`, {
    address: TokenManager.address,
    constructorArguments: [ETH, CL_ETH_USD],
  });

  await run(`verify:verify`, {
    address: Deployer.address,
    constructorArguments: [ETH, CL_EUR_USD],
  });

  await run(`verify:verify`, {
    address: SmartVaultManager.address,
    constructorArguments: [],
  });

  await run(`verify:verify`, {
    address: NFTMetadataGenerator.address,
    constructorArguments: [],
  });

  await run(`verify:verify`, {
    address: SmartVaultIndex.address,
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
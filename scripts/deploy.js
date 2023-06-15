const { ethers } = require("hardhat");
const { ETH, DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE } = require("../test/common");

async function main() {
  const [user] = await ethers.getSigners();

  const SEuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
  await SEuro.deployed();
  const ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
  await ClEthUsd.deployed();
  await (await ClEthUsd.setPrice(DEFAULT_ETH_USD_PRICE)).wait();
  const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
  await ClEurUsd.deployed();
  await (await ClEurUsd.setPrice(DEFAULT_EUR_USD_PRICE)).wait();
  const TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ETH, ClEthUsd.address);
  await TokenManager.deployed();
  const Deployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy(ETH, ClEurUsd.address);
  await Deployer.deployed();
  const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
  await SmartVaultIndex.deployed();
  const NFTMetadataGenerator = await (await ethers.getContractFactory('NFTMetadataGenerator')).deploy();
  await NFTMetadataGenerator.deployed();
  const SmartVaultManager = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManager'), [
    DEFAULT_COLLATERAL_RATE, 1000, SEuro.address, user.address, TokenManager.address, Deployer.address,
    SmartVaultIndex.address, NFTMetadataGenerator.address
  ]);
  await SmartVaultManager.deployed();

  await (await SmartVaultIndex.setVaultManager(SmartVaultManager.address)).wait();
  
  await SEuro.grantRole(await SEuro.DEFAULT_ADMIN_ROLE(), SmartVaultManager.address);
  const usd6 = await (await ethers.getContractFactory('LimitedERC20')).deploy('Standard USD 6 Dec', 'SUSD6', 6);
  await usd6.deployed();
  const usd18 = await (await ethers.getContractFactory('LimitedERC20')).deploy('Standard USD 18 Dec', 'SUSD18', 18);
  await usd18.deployed();

  const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
  await ClUsdUsd.deployed();
  await (await ClUsdUsd.setPrice(100000000)).wait();
  await (await TokenManager.addAcceptedToken(usd6.address, ClUsdUsd.address)).wait();
  await (await TokenManager.addAcceptedToken(usd18.address, ClUsdUsd.address)).wait();

  console.log({
    SEuro: SEuro.address,
    ClEthUsd: ClEthUsd.address,
    ClEurUsd: ClEurUsd.address,
    TokenManager: TokenManager.address,
    Deployer: Deployer.address,
    SmartVaultIndex: SmartVaultIndex.address,
    NFTMetadataGenerator: NFTMetadataGenerator.address,
    SmartVaultManager: SmartVaultManager.address,
    USD6: usd6.address,
    USD18: usd18.address
  });

  await new Promise(resolve => setTimeout(resolve, 60000));

  await run(`verify:verify`, {
    address: SEuro.address,
    constructorArguments: [],
  });

  await run(`verify:verify`, {
    address: ClEthUsd.address,
    constructorArguments: [],
  });

  await run(`verify:verify`, {
    address: TokenManager.address,
    constructorArguments: [ETH, ClEthUsd.address],
  });

  await run(`verify:verify`, {
    address: Deployer.address,
    constructorArguments: [ETH, ClEurUsd.address],
  });

  await run(`verify:verify`, {
    address: SmartVaultManager.address,
    constructorArguments: [],
  });

  await run(`verify:verify`, {
    address: usd6.address,
    constructorArguments: ['Standard USD 6 Dec', 'SUSD6', 6]
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
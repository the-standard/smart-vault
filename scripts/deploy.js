const { ethers } = require("hardhat");
const { ETH } = require("../test/common");

async function main() {
  const [user] = await ethers.getSigners();
  const MATIC = ethers.utils.formatBytes32String('MATIC')

  const SEuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
  await SEuro.deployed();
  const ClMaticUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
  await ClMaticUsd.deployed();
  await (await ClMaticUsd.setPrice(115000000)).wait();
  const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
  await ClEurUsd.deployed();
  await (await ClEurUsd.setPrice(106000000)).wait();
  const TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(MATIC, ClMaticUsd.address);
  await TokenManager.deployed();
  const Deployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy(MATIC, ClEurUsd.address);
  await Deployer.deployed();
  const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
  await SmartVaultIndex.deployed();
  const SmartVaultManager = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManager'), [
    120000, 1000, SEuro.address, user.address, TokenManager.address, Deployer.address,
    SmartVaultIndex.address
  ]);
  await SmartVaultManager.deployed();
  
  await SEuro.grantRole(await SEuro.DEFAULT_ADMIN_ROLE(), SmartVaultManager.address);
  const usd6 = await (await ethers.getContractFactory('LimitedERC20')).deploy('Standard USD 6 Dec', 'SUSD6', 6);
  await usd6.deployed();
  const usd18 = await (await ethers.getContractFactory('LimitedERC20')).deploy('Standard USD 18 Dec', 'SUSD18', 18);
  await usd18.deployed();

  const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
  await (await ClUsdUsd.setPrice(100000000)).wait();
  await (await TokenManager.addAcceptedToken(usd6.address, ClUsdUsd.address)).wait();
  await (await TokenManager.addAcceptedToken(usd18.address, ClUsdUsd.address)).wait();

  console.log({
    SEuro: SEuro.address,
    ClMaticUsd: ClMaticUsd.address,
    ClEurUsd: ClEurUsd.address,
    TokenManager: TokenManager.address,
    Deployer: Deployer.address,
    SmartVaultIndex: SmartVaultIndex.address,
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
    address: ClMaticUsd.address,
    constructorArguments: [],
  });

  // await run(`verify:verify`, {
  //   address: ClEurUsd.address,
  //   constructorArguments: [],
  // });

  await run(`verify:verify`, {
    address: TokenManager.address,
    constructorArguments: [MATIC, ClMaticUsd.address],
  });

  await run(`verify:verify`, {
    address: Deployer.address,
    constructorArguments: [MATIC, ClEurUsd.address],
  });

  await run(`verify:verify`, {
    address: SmartVaultIndex.address,
    constructorArguments: [],
  });

  await run(`verify:verify`, {
    address: SmartVaultManager.address,
    constructorArguments: [],
  });

  await run(`verify:verify`, {
    address: usd6.address,
    constructorArguments: ['Standard USD 6 Dec', 'SUSD6', 6]
  });

  // await run(`verify:verify`, {
  //   address: usd18.address,
  //   constructorArguments: ['Standard USD 18 Dec', 'SUSD18', 18]
  // });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
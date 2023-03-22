const { ethers, network } = require("hardhat");
const { ETH } = require("../test/common");

async function main() {
  const [user] = await ethers.getSigners();

  const SEuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
  await SEuro.deployed();
  const ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
  await ClEthUsd.deployed();
  let price = await ClEthUsd.setPrice(180000000000);
  await price.wait();
  const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
  await ClEurUsd.deployed();
  price = await ClEurUsd.setPrice(106000000);
  await price.wait();
  const TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ETH, ClEthUsd.address);
  await TokenManager.deployed();
  const Deployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy(ETH, ClEurUsd.address);
  await Deployer.deployed();
  const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
  await SmartVaultIndex.deployed();
  const SmartVaultManager = await (await ethers.getContractFactory('SmartVaultManager')).deploy(
    120000, 1000, SEuro.address, user.address, TokenManager.address, Deployer.address, SmartVaultIndex.address
  );
  await SmartVaultManager.deployed();

  await SEuro.grantRole(await SEuro.DEFAULT_ADMIN_ROLE(), SmartVaultManager.address);

  console.log({
    SEuro: SEuro.address,
    ClEthUsd: ClEthUsd.address,
    ClEurUsd: ClEurUsd.address,
    TokenManager: TokenManager.address,
    Deployer: Deployer.address,
    SmartVaultIndex: SmartVaultIndex.address,
    SmartVaultManager: SmartVaultManager.address
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
    address: ClEurUsd.address,
    constructorArguments: [],
  });

  await run(`verify:verify`, {
    address: TokenManager.address,
    constructorArguments: [ClEthUsd.address],
  });

  await run(`verify:verify`, {
    address: Deployer.address,
    constructorArguments: [ClEurUsd.address],
  });

  await run(`verify:verify`, {
    address: SmartVaultIndex.address,
    constructorArguments: [],
  });

  await run(`verify:verify`, {
    address: SmartVaultManager.address,
    constructorArguments: [120000, 1000, SEuro.address, user.address, TokenManager.address, Deployer.address],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
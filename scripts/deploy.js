const { ethers } = require("hardhat");
const { ETH, DEFAULT_COLLATERAL_RATE, getNFTMetadataContract } = require("../test/common");

async function main() {

  const USDs = await ethers.getContractAt('IUSDs', '0x...'); // TODO replace this address after USDs deployment
  const USDC = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';
  const WETH = '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1';
  const uniproxy = '0x82FcEB07a4D01051519663f6c1c919aF21C27845';
  const ramsesRouter = '0xAA23611badAFB62D37E7295A682D21960ac85A90';
  const usdHypervisor = '0x...'; // TODO replace this once deployed
  const uniswapRouter = '0xE592427A0AEce92De3Edee1F18E0157C05861564';
  const protocolGateway = '0x'; // TODO replace this once deployed
  const tokenManager = '0x33c5A816382760b6E5fb50d8854a61b3383a32a0';


  const YieldManager = await (await ethers.getContractFactory('SmartVaultYieldManager')).deploy(
    USDs.address, USDC, WETH, uniproxy, ramsesRouter, usdHypervisor, uniswapRouter
  );
  await YieldManager.deployed();

  const Deployer = await (await ethers.getContractFactory('SmartVaultDeployerV4')).deploy(ETH);
  await Deployer.deployed();

  const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
  await SmartVaultIndex.deployed();

  const NFTUtils = await (await ethers.getContractFactory('NFTUtils')).deploy();
  await NFTUtils.deployed();


  const NFTMetadataGenerator = await (await ethers.getContractFactory('NFTMetadataGenerator', {
    libraries: {
      NFTUtils: NFTUtils.address,
    },
  })).deploy();
  await NFTMetadataGenerator.deployed();

  const SmartVaultManager = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManagerV6', admin), [
    DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, USDs.address, protocolGateway,
    protocolGateway, tokenManager, Deployer.address, SmartVaultIndex.address,
    NFTMetadataGenerator.address, 1000
  ]);

  await (await SmartVaultIndex.setVaultManager(SmartVaultManager.address)).wait();
  await (await SmartVaultManager.setYieldManager(YieldManager.address)).wait();
  await (await SmartVaultManager.setSwapRouter(uniswapRouter)).wait();
  await (await SmartVaultManager.setWethAddress(WETH)).wait();


  console.log({
    Deployer: Deployer.address,
    SmartVaultIndex: SmartVaultIndex.address,
    NFTMetadataGenerator: NFTMetadataGenerator.address,
    SmartVaultManager: SmartVaultManager.address,
    YieldManager: YieldManager.address
  });

  await new Promise(resolve => setTimeout(resolve, 60000));

  await run(`verify:verify`, {
    address: Deployer.address,
    constructorArguments: [ETH],
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
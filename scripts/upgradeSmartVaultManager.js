const { ethers, upgrades } = require("hardhat");
const { PROTOCOL_FEE_RATE, DEFAULT_EUR_USD_PRICE } = require("../test/common");

async function main() {
  const managerAddress = '0xba169cceCCF7aC51dA223e04654Cf16ef41A68CC';
  const deployerV2 = await (await ethers.getContractFactory('SmartVaultDeployerV2')).deploy(ethers.utils.formatBytes32String('ETH'), '0xa14d53bc1f1c0f31b4aa3bd109344e5009051a84');
  await deployerV2.deployed();
  const v2 = await upgrades.upgradeProxy(managerAddress,
    await ethers.getContractFactory('SmartVaultManagerV2'));

  const fee = await v2.setSwapFeeRate(PROTOCOL_FEE_RATE);
  await fee.wait();
  const weth = await v2.setWethAddress('0x82aF49447D8a07e3bd95BD0d56f35241523fBab1');
  await weth.wait();
  const router = await v2.setSwapRouterAddress('0xE592427A0AEce92De3Edee1F18E0157C05861564');
  await router.wait();
  const setDeployer = await v2.setSmartVaultDeployer(deployerV2.address);
  await setDeployer.wait();

  await new Promise(resolve => setTimeout(resolve, 60000));

  await run(`verify:verify`, {
    address: managerAddress,
    constructorArguments: [],
  });

  await run(`verify:verify`, {
    address: deployerV2.address,
    constructorArguments: [ethers.utils.formatBytes32String('ETH'), '0xa14d53bc1f1c0f31b4aa3bd109344e5009051a84']
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
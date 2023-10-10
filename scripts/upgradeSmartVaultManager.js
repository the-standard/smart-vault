const { ethers, upgrades } = require("hardhat");
const { PROTOCOL_FEE_RATE } = require("../test/common");

async function main() {
  const managerAddress = '0x2342755a637451e9af75545e257Cb007EaC930B1';
  const v2 = await upgrades.upgradeProxy(managerAddress,
    await ethers.getContractFactory('SmartVaultManagerV2'));

  const fee = await v2.setSwapFeeRate(PROTOCOL_FEE_RATE);
  await fee.wait();
  const weth = await v2.setWethAddress('0xe39Ab88f8A4777030A534146A9Ca3B52bd5D43A3');
  await weth.wait();
  const router = await v2.setSwapRouterAddress('0xE592427A0AEce92De3Edee1F18E0157C05861564');
  await router.wait();

  await new Promise(resolve => setTimeout(resolve, 60000));

  await run(`verify:verify`, {
    address: managerAddress,
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
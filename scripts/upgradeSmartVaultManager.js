const { ethers, upgrades } = require("hardhat");
const { PROTOCOL_FEE_RATE, DEFAULT_EUR_USD_PRICE } = require("../test/common");

async function main() {
  const managerAddress = '0xba169cceCCF7aC51dA223e04654Cf16ef41A68CC';
  const v3 = await upgrades.upgradeProxy(managerAddress,
    await ethers.getContractFactory('SmartVaultManagerV3'));

  await new Promise(resolve => setTimeout(resolve, 60000));
  
  await run(`verify:verify`, {
    address: v3.address,
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
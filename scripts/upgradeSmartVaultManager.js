const { ethers, upgrades } = require("hardhat");
const { PROTOCOL_FEE_RATE, DEFAULT_EUR_USD_PRICE } = require("../test/common");

async function main() {
  const managerAddress = '0xba169cceCCF7aC51dA223e04654Cf16ef41A68CC';
  const V4 = await upgrades.upgradeProxy(managerAddress,
    await ethers.getContractFactory('SmartVaultManagerV4'));

  await new Promise(resolve => setTimeout(resolve, 60000));
  
  await run(`verify:verify`, {
    address: managerAddress,
    constructorArguments: []
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
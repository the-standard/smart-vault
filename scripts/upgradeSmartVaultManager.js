const { ethers, upgrades } = require("hardhat");
const { PROTOCOL_FEE_RATE, DEFAULT_EUR_USD_PRICE } = require("../test/common");

async function main() {
  const managerAddress = '0xBbB704f184E716410a9c00435530eA055CfAD187';
  const V5 = await upgrades.upgradeProxy(managerAddress,
    await ethers.getContractFactory('SmartVaultManagerV5'));

  set = await V5.setLiquidatorAddress('0x2C051f4f2B00695e773De4C3431F70c0163B3788');
  await set.wait()

  await new Promise(resolve => setTimeout(resolve, 60000));
  
  await run(`verify:verify`, {
    address: V5.address,
    constructorArguments: []
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
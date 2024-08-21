const { ethers, upgrades } = require("hardhat");
const { ETH } = require("../test/common");

async function main() {
  const managerAddress = '0xBbB704f184E716410a9c00435530eA055CfAD187';
  const V5 = await upgrades.upgradeProxy(managerAddress,
    await ethers.getContractFactory('SmartVaultManagerV5'));
  
  const deployer = await (await ethers.getContractFactory('SmartVaultDeployerV3')).deploy(ETH, '0x34319A7424bC39C29958d2eb905D743C2b1cAFCa');
  await deployer.deployed();

  const set = await V5.setSmartVaultDeployer(deployer.address);
  await set.wait();

  await new Promise(resolve => setTimeout(resolve, 60000));
  
  await run(`verify:verify`, {
    address: managerAddress,
    constructorArguments: []
  });
  
  await run(`verify:verify`, {
    address: deployer.address,
    constructorArguments: [ETH, '0x34319A7424bC39C29958d2eb905D743C2b1cAFCa']
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
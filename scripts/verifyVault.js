const { ethers, upgrades } = require("hardhat");

async function main() {
  const [ user ] = await ethers.getSigners();

  const vault = '0x2579E077826BC309B2FDD02bAEc87508d91Ff86F';
  const native = ethers.utils.formatBytes32String('ETH');
  const manager = await ethers.getContractAt('SmartVaultManagerV2', '0xba169cceCCF7aC51dA223e04654Cf16ef41A68CC')
  const owner = user.address;
  const euros = '0x643b34980E635719C15a2D4ce69571a258F940E9'
  const calculator = '0x97517b3Fef774cBe3f520253cDf04067A4b9aaFb'

  // await run(`verify:verify`, {
  //   address: vault,
  //   constructorArguments: [
  //     native, manager.address, owner, euros, calculator
  //   ],
  // });
  console.log(await manager.connect(user).vaults());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
const { ethers, upgrades } = require("hardhat");

async function main() {
  const [ user ] = await ethers.getSigners();

  const vault = '0x318034a72b000FE38798355e295Aa2faBE275EaE';
  const native = ethers.utils.formatBytes32String('ETH');
  const owner = user.address;
  const euros = '0x5D1684E5b989Eb232ac84D6b73D783FE44114C2b'
  const calculator = '0x0f0De637F96deb10dF6f556A1DE26C041f22f923'

  await run(`verify:verify`, {
    address: vault,
    constructorArguments: [
      native, '0xBbB704f184E716410a9c00435530eA055CfAD187', owner, euros, calculator
    ],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
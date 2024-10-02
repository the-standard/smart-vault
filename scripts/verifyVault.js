const { ethers, upgrades } = require("hardhat");

async function main() {
  const [ user ] = await ethers.getSigners();

  const vault = '0x33a04e11ce8c16e92ec9be2ec4848e9dd583408a';
  const native = ethers.utils.formatBytes32String('ETH');
  const owner = user.address;
  const usds = '0x0173184A51CF807Cc386B3F5Dc5689Cae09B81fb'
  const calculator = '0x90dE8F1691403f599A4E5E2eb73AeD66e20F918E'
  const manager = '0xf752AD9dBacCA40f771164ca03b68844DBB93BF7'

  await run(`verify:verify`, {
    address: vault,
    constructorArguments: [
      native, manager, owner, usds, calculator
    ],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
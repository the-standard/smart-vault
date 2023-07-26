const { ethers, upgrades } = require("hardhat");

async function main() {
  const [ user ] = await ethers.getSigners();

  const vault = '0x34B2b38F5ac25cB5Bcb4c19150f01baDCFb02cCb';
  const native = ethers.utils.formatBytes32String('AGOR');
  const manager = '0x6A301a76f67ECf0D56377F8Db384dbCa9E161203';
  const owner = user.address;
  const seuro = '0x9C777AD2575010E3ED67F6E849cfE1115BFE2A50'
  const calculator = '0xA35Ff34200432F573e0Db493872cDbc18e2d5E08'

  await run(`verify:verify`, {
    address: vault,
    constructorArguments: [
      native, manager, owner, seuro, calculator
    ],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
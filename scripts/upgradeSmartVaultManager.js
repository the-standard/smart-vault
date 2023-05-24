const { ethers, upgrades } = require("hardhat");

async function main() {

  const NFTMetadataGenerator = await (await ethers.getContractFactory('NFTMetadataGenerator')).deploy();
  await NFTMetadataGenerator.deployed();
  console.log(NFTMetadataGenerator.address)
  await upgrades.upgradeProxy('0xF05b859c70c58EF88A4418F808c8d197Bb4Caa79',
    await ethers.getContractFactory('SmartVaultManagerNewNFTGenerator'), {
      call: {fn: 'completeUpgrade', args: [NFTMetadataGenerator.address]}
    }
  );

  await new Promise(resolve => setTimeout(resolve, 60000));

  await run(`verify:verify`, {
    address: NFTMetadataGenerator.address,
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
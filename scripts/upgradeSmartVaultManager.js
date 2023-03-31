const { ethers, upgrades } = require("hardhat");

async function main() {
  // await upgrades.forceImport(
  //   '0xbE70d41FB3505385c01429cbcCB1943646Db344f',
  //   await ethers.getContractFactory('SmartVaultManager')
  // );

  const NFTMetadataGenerator = await (await ethers.getContractFactory('NFTMetadataGenerator')).deploy();
  await NFTMetadataGenerator.deployed();
  console.log(NFTMetadataGenerator.address)
  await upgrades.upgradeProxy('0xbE70d41FB3505385c01429cbcCB1943646Db344f',
    await ethers.getContractFactory('SmartVaultManagerTestnetV2'), {
      call: {fn: 'completeUpgrade', args: [NFTMetadataGenerator.address]}
    }
  );

  await new Promise(resolve => setTimeout(resolve, 60000));

  await run(`verify:verify`, {
    address: '0xbE70d41FB3505385c01429cbcCB1943646Db344f',
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
const {ethers} = require("hardhat");

async function main() {
    const LibContract = await ethers.getContractFactory('NFTUtils');
    const lib = await LibContract.deploy();
    await lib.deployed();

    let nftMetadatagenerator = await ethers.getContractFactory('NFTMetadataGenerator', {
        libraries: {
            NFTUtils: lib.address,
        },
    });

    nftMetadatagenerator = await nftMetadatagenerator.deploy();
    await nftMetadatagenerator.deployed();

    console.log('nftMetadatagenerator deployed to:', nftMetadatagenerator.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
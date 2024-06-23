const {ethers} = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const balance = await deployer.getBalance();
    console.log("Account balance:", balance.toString());

    const LibContract = await ethers.getContractFactory('NFTUtils');
    const lib = await LibContract.deploy();
    await lib.deployed();

    let svgGenerator = await ethers.getContractFactory('SVGGenerator', {
        libraries: {
            NFTUtils: lib.address,
        },
    });

    svgGenerator = await svgGenerator.deploy();
    await svgGenerator.deployed();
    console.log('SVGGenerator deployed to:', svgGenerator.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
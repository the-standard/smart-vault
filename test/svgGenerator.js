const {ethers} = require("hardhat");


describe('SVG Generator', async () => {
    let svgGenerator;

    beforeEach(async () => {
        // Deploy the NFTUtils library
        const NFTUtils = await ethers.getContractFactory("NFTUtils");
        const nftUtils = await NFTUtils.deploy();
        await nftUtils.deployed();

        svgGenerator = await ethers.getContractFactory("SVGGenerator", {
            libraries: {
                NFTUtils: nftUtils.address,
            },
        });

        // Deploy the SVGGenerator contract
        svgGenerator = await svgGenerator.deploy();
        await svgGenerator.deployed();
    });

    it('should create an svg', async function () {
        // Create a sample Status struct
        const sampleStatus = {
            vaultAddress: "0x1234567890123456789012345678901234567890",
            minted: ethers.BigNumber.from("1000"),
            maxMintable: ethers.BigNumber.from("10000"),
            totalCollateralValue: ethers.BigNumber.from("500000"),
            collateral: [],
            liquidated: false,
            version: 1,
            vaultType: ethers.utils.formatBytes32String("sampleVault")
        };

        const svg = await svgGenerator.generateSvg(1, sampleStatus);

        const svgDataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;

        console.log(`Open the following URL in your browser to see the SVG: \n \n ${svgDataUrl}`);
    });
})
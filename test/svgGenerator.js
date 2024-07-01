const {ethers} = require("hardhat");
const {expect} = require('chai');

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
        const minted = ethers.utils.parseUnits('2500', 18);
        const maxMintable = ethers.utils.parseUnits('1000', 18);
        const totalCollateralValue = ethers.utils.parseUnits('10000', 18);

        const sampleStatus = {
            vaultAddress: "0x1234567890123456789012345678901234567890",
            minted: ethers.BigNumber.from(minted),
            maxMintable: ethers.BigNumber.from(maxMintable),
            totalCollateralValue: ethers.BigNumber.from(totalCollateralValue),
            collateral: [],
            liquidated: false,
            version: 1,
            vaultType: ethers.utils.formatBytes32String("sampleVault")
        };

        const svg = await svgGenerator.generateSvg(3, sampleStatus);
        const svgDataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
        expect(svgDataUrl).to.not.be.undefined;
        // TODO uncomment to test svg in browser
        // console.log(`Open the following URL in your browser to see the SVG: \n \n ${svgDataUrl}`);
    });
})
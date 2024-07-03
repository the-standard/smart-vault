const {ethers} = require("hardhat");
const {expect} = require('chai');

const getSvgMintConfog = (minted, maxMintable, totalCollateralValue) => {
    return {
        vaultAddress: "0x1234567890123456789012345678901234567890",
        minted: ethers.BigNumber.from(ethers.utils.parseUnits(minted, 18)),
        maxMintable: ethers.BigNumber.from(ethers.utils.parseUnits(maxMintable, 18),),
        totalCollateralValue: ethers.BigNumber.from(ethers.utils.parseUnits(totalCollateralValue, 18)),
        collateral: [],
        liquidated: false,
        version: 1,
        vaultType: ethers.utils.formatBytes32String("sampleVault")
    }
};

describe.only('SVG Generator', async () => {
    // uncomment to show svg
    let printViewableSvgInTest = true;
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
        svgGenerator = await svgGenerator.deploy();
        await svgGenerator.deployed();
    });

    it('should create an svg', async function () {
        const config = getSvgMintConfog("900", "1000", "10000");
        const svg = await svgGenerator.generateSvg(1, config);
        const svgDataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
        expect(svgDataUrl).to.not.be.undefined;
        if (printViewableSvgInTest) {
            console.log(`Open the following URL in your browser to see the SVG: \n \n ${svgDataUrl}`);
        }
    });

    it('should create an svg with token id 5', async function () {
        const config = getSvgMintConfog("2500", "1000", "10000");
        const svg = await svgGenerator.generateSvg(5, config);
        const svgDataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
        expect(svgDataUrl).to.not.be.undefined;
    });

    it('should create an svg with token id 1234', async function () {
        const config = getSvgMintConfog("2500", "1000", "10000");
        const svg = await svgGenerator.generateSvg(1234, config);
        const svgDataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
        expect(svgDataUrl).to.not.be.undefined;
    });

    it('should work with different configurations', async function () {
        const config = getSvgMintConfog("100", "50", "2000");
        const svg = await svgGenerator.generateSvg(1234, config);
        const svgDataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
        expect(svgDataUrl).to.not.be.undefined;
    });
})
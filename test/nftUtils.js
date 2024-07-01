const {ethers} = require("hardhat");
const {expect} = require('chai');

describe('NFT Utils', function () {
    let nftUtils;
    beforeEach(async () => {
        const NFTUtils = await ethers.getContractFactory("NFTUtils");
        nftUtils = await NFTUtils.deploy();
        await nftUtils.deployed();
    });


    it('should consider edge cases for bar percentage calculation', async () => {
        const testTotalValue = 10_000
        const fullWidth = 690;
        // all zero
        expect(await nftUtils.calculateCollateralLockedWidth(0, 0, fullWidth)).to.eq(0)
        // 100% case
        expect(await nftUtils.calculateCollateralLockedWidth(testTotalValue, 10_000, fullWidth)).to.eq(0);
        // 99% case
        expect(await nftUtils.calculateCollateralLockedWidth(testTotalValue, 9_999, fullWidth)).to.eq(7)
        // 75% case
        expect(await nftUtils.calculateCollateralLockedWidth(testTotalValue, 7_500, fullWidth)).to.eq(173)
        // 50% case
        expect(await nftUtils.calculateCollateralLockedWidth(testTotalValue, 5_000, fullWidth)).to.eq(fullWidth / 2)
        // 25% case
        expect(await nftUtils.calculateCollateralLockedWidth(testTotalValue, 2_500, fullWidth)).to.eq(518);
        // 1% case
        expect(await nftUtils.calculateCollateralLockedWidth(testTotalValue, 1, fullWidth)).to.eq(fullWidth);
    });
});
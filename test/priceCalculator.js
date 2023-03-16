const { expect } = require('chai');
const { ethers } = require("hardhat");

describe('PriceCalculator', async () => {
  describe('tokenToEur', async () => {
    it('calculates price based on chainlink average over 4 hours', async () => {
      const now = Math.floor(new Date / 1000);
      const fourHours = 4 * 60 * 60;
      const ethPrices = [[now - fourHours, 150000000000], [now, 100000000000], ];
      const clEthUsd = await (await ethers.getContractFactory('ChainlinkMockV2')).deploy();
      for (const round of ethPrices) {
        await clEthUsd.addPriceRound(round[0], round[1]);
      }
      const eurPrices = [[now - fourHours, 103000000], [now, 105000000]];
      const clEurUsd = await (await ethers.getContractFactory('ChainlinkMockV2')).deploy();
      for (const round of eurPrices) {
        await clEurUsd.addPriceRound(round[0], round[1]);
      }
      const PriceCalculator = await (await ethers.getContractFactory('PriceCalculator')).deploy(clEurUsd.address);
      const ETH = {
        symbol: ethers.utils.formatBytes32String('ETH'),
        addr: ethers.constants.AddressZero,
        dec: 18,
        clAddr: clEthUsd.address,
        clDec: 8
      };
      
      // converting 1 ether to usd
      // avg. price eth / usd = 1250
      // 1 ether = 1250 usd
      // avg. price eur / usd = 1.04
      // 1250 usd = ~1201.92 eur
      const etherValue = ethers.utils.parseEther('1');
      const averageEthUsd = ethPrices.reduce((a, b) => a + b[1], 0) / ethPrices.length
      const averageEurUsd = eurPrices.reduce((a, b) => a + b[1], 0) / eurPrices.length
      const expectedEurValue = etherValue.mul(averageEthUsd).div(averageEurUsd);
      const eurValue = await PriceCalculator.tokenToEur(ETH, etherValue);
      expect(eurValue).to.equal(expectedEurValue);
    });
  });
});
const { expect } = require('chai');
const { ethers } = require("hardhat");
const { ETH, DEFAULT_EUR_USD_PRICE } = require('./common');
const { BigNumber } = ethers;

describe('PriceCalculator', async () => {
  describe('tokenToEur', async () => {
    it('calculates price based on chainlink average over 4 hours', async () => {
      const now = Math.floor(new Date / 1000);
      const hour = 60 * 60;
      const ethPrices = [[now - 6 * hour, 200000000000], [now - 4 * hour, 150000000000], [now - 2 * hour, 140000000000], [now, 100000000000]];
      const clEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('ETH / USD');
      for (const round of ethPrices) {
        await clEthUsd.addPriceRound(round[0], round[1]);
      }
      const clEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('EUR / USD');
      await clEurUsd.setPrice(DEFAULT_EUR_USD_PRICE);
      const PriceCalculator = await (await ethers.getContractFactory('PriceCalculator')).deploy(ETH, clEurUsd.address);
      const Ethereum = {
        symbol: ETH,
        addr: ethers.constants.AddressZero,
        dec: 18,
        clAddr: clEthUsd.address,
        clDec: 8
      };
      
      // converting 1 ether to usd
      // avg. price eth / usd = (1500 + 1400 + 1000) / 3 = 1300
      // 1 ether = 1300 usd
      // avg. price eur / usd = (1.03 + 1.06 + 1.06) / 3 = 1.05
      // 1300 usd = ~1238.09 eur
      const etherValue = ethers.utils.parseEther('1');
      const averageEthUsd = BigNumber.from(150000000000).add(140000000000).add(100000000000).div(3);
      const expectedEurValue = etherValue.mul(averageEthUsd).div(DEFAULT_EUR_USD_PRICE);
      const eurValue = await PriceCalculator.tokenToEur(Ethereum, etherValue);
      expect(eurValue).to.equal(expectedEurValue);
    });
  });
});
const { expect } = require('chai');
const { ethers } = require("hardhat");
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE } = require('./common');

let TokenManager, ClEthUsd;

describe('TokenManager', async () => {
  beforeEach(async () => {
    ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ClEthUsd.address, ClEurUsd.address);
  });

  it('defaults with ETH as accepted token', async () => {
    const tokens = await TokenManager.getAcceptedTokens();
    expect(tokens.length).to.equal(1);
    const token = tokens[0];
    expect(token.symbol).to.equal(ethers.utils.formatBytes32String('ETH'));
    expect(token.addr).to.equal(ethers.constants.AddressZero);
    expect(token.clAddr).to.equal(ClEthUsd.address);
    expect(token.clDec).to.equal(8);
  });

  it('will let the owner add and remove accepted ERC20 tokens – cannot remove ETH', async () => {
    [ admin, user ] = await ethers.getSigners();

    const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(100000000);
    const Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
    const USDTBytes = ethers.utils.formatBytes32String('USDT');

    let add = TokenManager.connect(user).addAcceptedToken(Tether.address, ClUsdUsd.address);
    await expect(add).to.be.revertedWith('Ownable: caller is not the owner');

    add = TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
    await expect(add).not.to.be.reverted;

    add = TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
    await expect(add).to.be.revertedWith('err-token-exists');

    const tokens = await TokenManager.getAcceptedTokens();
    expect(tokens.length).to.equal(2);
    
    const token = tokens[1];
    expect(token.symbol).to.equal(USDTBytes);
    expect(token.addr).to.equal(Tether.address);
    expect(token.dec).to.equal(6);
    expect(token.clAddr).to.equal(ClUsdUsd.address);
    expect(token.clDec).to.equal(8);

    let remove = TokenManager.connect(user).removeAcceptedToken(USDTBytes);
    await expect(remove).to.be.revertedWith('Ownable: caller is not the owner');

    remove = TokenManager.removeAcceptedToken(ethers.utils.formatBytes32String('USDT'));
    await expect(remove).not.to.be.reverted;

    expect((await TokenManager.getAcceptedTokens()).length).to.equal(1);

    remove = TokenManager.removeAcceptedToken(ethers.utils.formatBytes32String('ETH'));
    await expect(remove).to.be.reverted;

    expect((await TokenManager.getAcceptedTokens()).length).to.equal(1);
  });
});
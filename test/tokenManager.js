const { expect } = require('chai');
const { ethers } = require("hardhat");

describe('TokenManager', async () => {
  it('will let the owner add and remove accepted ERC20 tokens', async () => {
    [ admin, user ] = await ethers.getSigners();

    const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(100000000);
    const Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
    const TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy();

    expect((await TokenManager.getAcceptedTokens()).length).to.equal(0);

    let add = TokenManager.connect(user).addAcceptedToken(Tether.address, ClUsdUsd.address);
    await expect(add).to.be.revertedWith('Ownable: caller is not the owner');

    add = TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
    await expect(add).not.to.be.reverted;

    add = TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
    await expect(add).to.be.revertedWith('err-token-exists');

    const tokens = await TokenManager.getAcceptedTokens();
    expect(tokens.length).to.equal(1);
    
    const token = tokens[0];
    expect(token.symbol).to.equal(ethers.utils.formatBytes32String('USDT'));
    expect(token.addr).to.equal(Tether.address);
    expect(token.dec).to.equal(6);
    expect(token.clAddr).to.equal(ClUsdUsd.address);
    expect(token.clDec).to.equal(8);

    let remove = TokenManager.connect(user).removeAcceptedToken('USDT');
    await expect(remove).to.be.revertedWith('Ownable: caller is not the owner');

    remove = TokenManager.removeAcceptedToken('USDT');
    await expect(remove).not.to.be.reverted;

    expect((await TokenManager.getAcceptedTokens()).length).to.equal(0);
  });
});
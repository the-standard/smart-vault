const { ethers, upgrades } = require("hardhat");
const { PROTOCOL_FEE_RATE, DEFAULT_EUR_USD_PRICE, ETH } = require("../test/common");

async function main() {
  const managerAddress = '0xba169cceCCF7aC51dA223e04654Cf16ef41A68CC';
  const tokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(
    '0x4554480000000000000000000000000000000000000000000000000000000000',
    '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612'
  );
  await tokenManager.deployed();

  let add = await tokenManager.addAcceptedToken('0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f', '0xd0C7101eACbB49F3deCcCc166d238410D6D46d57');
  await add.wait();
  add = await tokenManager.addAcceptedToken('0x912CE59144191C1204E64559FE8253a0e49E6548', '0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6');
  await add.wait();
  add = await tokenManager.addAcceptedToken('0xf97f4df75117a78c1A5a0DBb814Af92458539FB4', '0x86E53CF1B870786351Da77A57575e79CB55812CB');
  await add.wait();
  add = await tokenManager.addAcceptedToken('0xfEb4DfC8C4Cf7Ed305bb08065D08eC6ee6728429', '0x2BA975D4D7922cD264267Af16F3bD177F206FE3c');
  await add.wait();
  add = await tokenManager.addAcceptedToken('0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a', '0xDB98056FecFff59D032aB628337A4887110df3dB');
  await add.wait();
  add = await tokenManager.addAcceptedToken('0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612');
  await add.wait();
  add = await tokenManager.addAcceptedToken('0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9', '0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7');
  await add.wait();

  const V52 = await upgrades.upgradeProxy(managerAddress,
    await ethers.getContractFactory('SmartVaultManagerV52'));
  

  const set = await V52.setTokenManager(tokenManager.address);
  await set.wait();

  await new Promise(resolve => setTimeout(resolve, 60000));
  
  await run(`verify:verify`, {
    address: managerAddress,
    constructorArguments: []
  });
  
  await run(`verify:verify`, {
    address: tokenManager.address,
    constructorArguments: [
      '0x4554480000000000000000000000000000000000000000000000000000000000',
      '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612'
    ]
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
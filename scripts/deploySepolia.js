const { ethers } = require("hardhat");
const { ETH, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, DEFAULT_ETH_USD_PRICE } = require("../test/common");

async function main() {

  // const [ me ] = await ethers.getSigners();
  // const USDs = await (await ethers.getContractFactory('USDsMock')).deploy();
  // await USDs.deployed();
  // const USDC = await (await ethers.getContractFactory('LimitedERC20')).deploy('USD Coin', 'USDC', 6);
  // await USDC.deployed();
  // const WETH = await (await ethers.getContractFactory('MockWETH')).deploy();
  // await WETH.deployed();
  // const WBTC = await (await ethers.getContractFactory('LimitedERC20')).deploy('Wrapped Bitcoin', 'WBTC', 8);
  // await WBTC.deployed();
  // const uniproxy = await (await ethers.getContractFactory('UniProxyMock')).deploy();
  // await uniproxy.deployed();
  // const swapRouter = await (await ethers.getContractFactory('MockSwapRouter')).deploy();
  // await swapRouter.deployed();
  // const usdHypervisor = await (await ethers.getContractFactory('HypervisorMock')).deploy(
  //   'xUSDs-USDC', 'xUSDs-USDC', USDs.address, USDC.address
  // );
  // await usdHypervisor.deployed();
  // const protocolGateway = me.address; // TODO replace this once deployed
  // const tokenManager = await ethers.getContractAt('TokenManager', '0x18f413879A00Db35A4Ea22300977924E613F3D88');
  const USDS6 = '0xb7269723576B20ed2C3DaBBBe39911402669a395'
  const USDS18 = '0xA977E34e4B8583C6928453CC9572Ae032Cc3200a'

  // const YieldManager = await (await ethers.getContractFactory('SmartVaultYieldManager')).deploy(
  //   USDs.address, USDC.address, WETH.address, uniproxy.address, swapRouter.address, usdHypervisor.address, swapRouter.address
  // );
  // await YieldManager.deployed();

  // const PriceCalculator = await (await ethers.getContractFactory('PriceCalculator')).deploy(ETH);
  // await PriceCalculator.deployed();

  // const Deployer = await (await ethers.getContractFactory('SmartVaultDeployerV4')).deploy(ETH, PriceCalculator.address);
  // await Deployer.deployed();

  // const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
  // await SmartVaultIndex.deployed();
  // console.log('what')

  // const NFTUtils = await (await ethers.getContractFactory('NFTUtils')).deploy();
  // await NFTUtils.deployed();

  // console.log('hi')

  // const NFTMetadataGenerator = await (await ethers.getContractFactory('NFTMetadataGenerator', {
  //   libraries: {
  //     NFTUtils: NFTUtils.address,
  //   },
  // })).deploy();
  // await NFTMetadataGenerator.deployed();
  // console.log('wat')

  // const SmartVaultManager = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManagerV6', me), [
  //   DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, USDs.address, protocolGateway,
  //   protocolGateway, tokenManager.address, Deployer.address, SmartVaultIndex.address,
  //   NFTMetadataGenerator.address, 1000
  // ]);

  // await USDs.grantRole(await USDs.DEFAULT_ADMIN_ROLE(), SmartVaultManager.address);

  // await (await SmartVaultIndex.setVaultManager(SmartVaultManager.address)).wait();
  // await (await SmartVaultManager.setYieldManager(YieldManager.address)).wait();
  // await (await SmartVaultManager.setSwapRouter(swapRouter.address)).wait();
  // await (await SmartVaultManager.setWethAddress(WETH.address)).wait();
  
  // console.log('hey')
  
  // const WETHWBTCHypervisor = await (await ethers.getContractFactory('HypervisorMock')).deploy(
  //   'xWETH-WBTC', 'xWETH-WBTC', WETH.address, WBTC.address
  // );
  // await WETHWBTCHypervisor.deployed();

  // const WETHUSDS6Hypervisor = await (await ethers.getContractFactory('HypervisorMock')).deploy(
  //   'xWETH-USDS6', 'xWETH-USDS6', WETH.address, USDS6
  // );
  // await WETHUSDS6Hypervisor.deployed();

  // const WETHUSDS18Hypervisor = await (await ethers.getContractFactory('HypervisorMock')).deploy(
  //   'xWETH-USDS18', 'xWETH-USDS18', WETH.address, USDS18
  // );
  // await WETHUSDS18Hypervisor.deployed();

  // await (await uniproxy.setRatio(usdHypervisor.address, USDC.address, ethers.utils.parseUnits('1', 30))).wait();
  // await (await uniproxy.setRatio(WETHWBTCHypervisor.address, WETH.address, ethers.utils.parseUnits('0.05',8))).wait();
  // await (await uniproxy.setRatio(WETHWBTCHypervisor.address, WBTC.address, ethers.utils.parseUnits('20',28))).wait();
  // await (await uniproxy.setRatio(WETHUSDS6Hypervisor.address, USDS6, ethers.utils.parseUnits('5', 26))).wait();
  // await (await uniproxy.setRatio(WETHUSDS18Hypervisor.address, USDS18, ethers.utils.parseUnits('5', 14))).wait();

  // // weth (+ wbtc)
  // await (await swapRouter.setRate(WETH.address, USDC.address, DEFAULT_ETH_USD_PRICE.div(100))).wait();
  // await (await swapRouter.setRate(USDC.address, WETH.address, ethers.utils.parseEther('1').div(DEFAULT_ETH_USD_PRICE).mul(ethers.utils.parseUnits('1', 20)))).wait();
  // await (await swapRouter.setRate(WETH.address, WBTC.address, ethers.utils.parseUnits('0.05',8))).wait();
  // await (await swapRouter.setRate(WBTC.address, WETH.address, ethers.utils.parseUnits('20',28))).wait();
  // // wbtc
  // await (await swapRouter.setRate(WBTC.address, USDC.address, ethers.utils.parseUnits('4',20))).wait();
  // await (await swapRouter.setRate(USDC.address, WBTC.address, ethers.utils.parseUnits('2.5',15))).wait();
  // // usds / usdc
  // await (await swapRouter.setRate(USDC.address, USDs.address, ethers.utils.parseUnits('1', 30))).wait();
  // await (await swapRouter.setRate(USDs.address, USDC.address, ethers.utils.parseUnits('1', 6))).wait();
  // // usds6
  // await (await swapRouter.setRate(USDS6, USDC.address, ethers.utils.parseEther('1'))).wait();
  // await (await swapRouter.setRate(USDC.address, USDS6, ethers.utils.parseEther('1'))).wait();
  // // usds18
  // await (await swapRouter.setRate(USDS18, USDC.address, ethers.utils.parseUnits('1', 6))).wait();
  // await (await swapRouter.setRate(USDC.address, USDS18, ethers.utils.parseUnits('1', 30))).wait();
  // // usds 6 + 18
  // await (await swapRouter.setRate(USDS6, USDS18, ethers.utils.parseUnits('1', 30))).wait();
  // await (await swapRouter.setRate(USDS18, USDS6, ethers.utils.parseUnits('1', 6))).wait();
  
  // console.log('hello')
  
  // await (await tokenManager.addAcceptedToken(WETH.address, '0x1DD905cb0a5aCEFF9E050eB8FAEB9b54d6C09940')).wait();
  // const CL_WBTC_USD = await (await ethers.getContractFactory('ChainlinkMock')).deploy('WBTC / USD');
  // await CL_WBTC_USD.deployed();
  // await (await CL_WBTC_USD.setPrice(DEFAULT_ETH_USD_PRICE.mul(20))).wait();
  // await (await tokenManager.addAcceptedToken(WBTC.address, CL_WBTC_USD.address)).wait();

  // await (await YieldManager.addHypervisorData(
  //   WETH.address, WETHWBTCHypervisor.address, 500,
  //   new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [WETH.address, 3000, USDC.address]),
  //   new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDC.address, 3000, WETH.address])
  // )).wait()

  // await (await YieldManager.addHypervisorData(
  //   WBTC.address, WETHWBTCHypervisor.address, 500,
  //   new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [WBTC.address, 3000, USDC.address]),
  //   new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDC.address, 3000, WBTC.address])
  // )).wait()

  const YieldManager = await ethers.getContractAt('SmartVaultYieldManager', '0x6A0CE0c90d260Bf47690B68B00527C339f4092AA')

  await (await YieldManager.addHypervisorData(
    USDS6, '0xc82B4793564719b55AA645c45AD9ee0Fa574E07D', 500,
    new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDS6, 500, '0xC305a98F34feD6cfFA7B920D26031372B64Fa74E']),
    new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], ['0xC305a98F34feD6cfFA7B920D26031372B64Fa74E', 500, USDS6])
  )).wait()

  await (await YieldManager.addHypervisorData(
    USDS18, '0x0881d58b146208230D720656320624c386661795', 500,
    new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDS18, 500, '0xC305a98F34feD6cfFA7B920D26031372B64Fa74E']),
    new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], ['0xC305a98F34feD6cfFA7B920D26031372B64Fa74E', 500, USDS18])
  )).wait()

  // console.log({
  //   USDs: USDs.address,
  //   Deployer: Deployer.address,
  //   SmartVaultIndex: SmartVaultIndex.address,
  //   NFTMetadataGenerator: NFTMetadataGenerator.address,
  //   SmartVaultManager: SmartVaultManager.address,
  //   YieldManager: YieldManager.address
  // });

  // await new Promise(resolve => setTimeout(resolve, 60000));

  // await run(`verify:verify`, {
  //   address: PriceCalculator.address,
  //   constructorArguments: [ETH],
  // });

  // await run(`verify:verify`, {
  //   address: Deployer.address,
  //   constructorArguments: [ETH, PriceCalculator.address],
  // });

  // await run(`verify:verify`, {
  //   address: SmartVaultManager.address,
  //   constructorArguments: [],
  // });

  // await run(`verify:verify`, {
  //   address: SmartVaultIndex.address,
  //   constructorArguments: [],
  // });

  // await run(`verify:verify`, {
  //   address: USDs.address,
  //   constructorArguments: [],
  // });

  // await run(`verify:verify`, {
  //   address: USDC.address,
  //   constructorArguments: ['USD Coin', 'USDC', 6],
  // });

  // await run(`verify:verify`, {
  //   address: WETH.address,
  //   constructorArguments: [],
  // });

  // await run(`verify:verify`, {
  //   address: WBTC.address,
  //   constructorArguments: ['Wrapped Bitcoin', 'WBTC', 8],
  // });

  // await run(`verify:verify`, {
  //   address: uniproxy.address,
  //   constructorArguments: [],
  // });

  // await run(`verify:verify`, {
  //   address: swapRouter.address,
  //   constructorArguments: [],
  // });

  // await run(`verify:verify`, {
  //   address: usdHypervisor.address,
  //   constructorArguments: ['xUSDs-USDC', 'xUSDs-USDC', USDs.address, USDC.address],
  // });

  // await run(`verify:verify`, {
  //   address: CL_WBTC_USD.address,
  //   constructorArguments: ['WBTC / USD'],
  // });

  // await run(`verify:verify`, {
  //   address: '0x6A0CE0c90d260Bf47690B68B00527C339f4092AA',
  //   constructorArguments: [
  //     '0x0173184A51CF807Cc386B3F5Dc5689Cae09B81fb', '0xC305a98F34feD6cfFA7B920D26031372B64Fa74E', '0x081eE2A9FE23b69036C5136437Fa2426fD2d7650', '0x18C398cbde7FE73e26571c7cAaFD43C5Fa1953fF', '0xF25B5aCD77370ED8d32b6c6A9efe237FD6036e2f', '0xc5B84d2f09094f72B79FE906d21c933c2DF27448', '0xF25B5aCD77370ED8d32b6c6A9efe237FD6036e2f'
  //   ],
  // });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
const { ethers, upgrades } = require("hardhat");
const { PROTOCOL_FEE_RATE, DEFAULT_EUR_USD_PRICE, ETH } = require("../test/common");
const hypervisorABI = require('./hypervisorABI.json');
const uniproxyABI = require('./uniproxyABI.json');

async function main() {
  const [signer] = await ethers.getSigners();
  const hypervisor = await ethers.getContractAt(hypervisorABI, '0xfa392dbefd2d5ec891ef5aeb87397a89843a8260');
  const uniproxy = await ethers.getContractAt(uniproxyABI, '0x82FcEB07a4D01051519663f6c1c919aF21C27845');
  const swapRouter = await ethers.getContractAt('ISwapRouter', '0xE592427A0AEce92De3Edee1F18E0157C05861564');
  const WETH = await ethers.getContractAt('IWETH', '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1');
  const LINK = await ethers.getContractAt('IERC20', '0xf97f4df75117a78c1A5a0DBb814Af92458539FB4');

  const amount = ethers.utils.parseEther('0.1');
  const ethSwapInput = ethers.utils.parseEther('0.5');

  await WETH.deposit({ value: amount });
  const requiredLINK = (await uniproxy.getDepositAmount(hypervisor.address, WETH.address, amount)).amountEnd

  const tx = await swapRouter.exactOutputSingle({
    tokenIn: WETH.address,
    tokenOut: LINK.address,
    fee: 3000,
    recipient: signer.address,
    deadline: Math.floor(new Date() / 1000) + 300,
    amountOut: requiredLINK,
    amountInMaximum: ethSwapInput,
    sqrtPriceLimitX96: 0
  }, {value: ethSwapInput});

  await WETH.approve(hypervisor.address, await WETH.balanceOf(signer.address));
  await LINK.approve(hypervisor.address, await LINK.balanceOf(signer.address));
  const {amountStart,amountEnd} = await uniproxy.getDepositAmount(hypervisor.address, WETH.address, amount)

  let WETHbalance = await WETH.balanceOf(signer.address);
  let LINKbalance = await LINK.balanceOf(signer.address);

  await uniproxy.deposit(amount, amountStart.add(amountEnd).div(2), signer.address, hypervisor.address, [0,0,0,0]);

  const WETHdeposited = WETHbalance.sub(await WETH.balanceOf(signer.address))
  const LINKdeposited = LINKbalance.sub(await LINK.balanceOf(signer.address))
  console.log('weth deposited', WETHdeposited)
  console.log('link deposited', LINKdeposited)
  const sharesBalance = await hypervisor.balanceOf(signer.address);
  const totalSupply = await hypervisor.totalSupply();
  const { total0, total1 } = await hypervisor.getTotalAmounts();
  console.log('underlying weth', sharesBalance.mul(total0).div(totalSupply));
  console.log('underlying link', sharesBalance.mul(total1).div(totalSupply));

  WETHbalance = await WETH.balanceOf(signer.address);
  LINKbalance = await LINK.balanceOf(signer.address);
  
  const amounts = await hypervisor.withdraw(sharesBalance, signer.address, signer.address, [0,0,0,0]);
  console.log(amounts);

  console.log('withdrawn weth',(await WETH.balanceOf(signer.address)).sub(WETHbalance));
  console.log('withdrawn link',(await LINK.balanceOf(signer.address)).sub(LINKbalance));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
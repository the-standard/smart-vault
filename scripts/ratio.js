const { ethers } = require("hardhat");
const abi = '[{"inputs":[{"internalType":"address","name":"_clearance","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"clearance","outputs":[{"internalType":"contract IClearing","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"deposit0","type":"uint256"},{"internalType":"uint256","name":"deposit1","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"address","name":"pos","type":"address"},{"internalType":"uint256[4]","name":"minIn","type":"uint256[4]"}],"name":"deposit","outputs":[{"internalType":"uint256","name":"shares","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"pos","type":"address"},{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"_deposit","type":"uint256"}],"name":"getDepositAmount","outputs":[{"internalType":"uint256","name":"amountStart","type":"uint256"},{"internalType":"uint256","name":"amountEnd","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"owner","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"newClearance","type":"address"}],"name":"transferClearance","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"newOwner","type":"address"}],"name":"transferOwnership","outputs":[],"stateMutability":"nonpayable","type":"function"}]'

async function main() {
  const WETH = await ethers.getContractAt('IWETH', '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1');
  const WBTC = await ethers.getContractAt('IERC20', '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f');
  const uniproxy = await ethers.getContractAt(JSON.parse(abi), '0x82FcEB07a4D01051519663f6c1c919aF21C27845');
  const router = await ethers.getContractAt('ISwapRouter', '0xE592427A0AEce92De3Edee1F18E0157C05861564');
  const hypervisor = await ethers.getContractAt('IERC20', '0x52ee1ffba696c5e9b0bc177a9f8a3098420ea691');
  const [ signer ] = await ethers.getSigners();

  const amount = ethers.utils.parseEther('0.5');
  // await router.exactOutput({
  //   path: ethers.utils.solidityPack(['address', 'uint24', 'address'], [WBTC.address, 500, WETH.address]),
  //   recipient: signer.address,
  //   deadline: Math.floor(new Date / 1000) + 60,
  //   amountOut: 2000000,
  //   amountInMaximum: amount
  // }, {value: amount});

  // await WETH.deposit({value: amount})
  
  // let {amountStart, amountEnd} = await uniproxy.getDepositAmount(hypervisor, WETH.address, await WETH.balanceOf(signer.address));
  // let wbtcBalance = await WBTC.balanceOf(signer.address);
  // let divver = 10;
  // while (wbtcBalance.lt(amountStart)) {
  //   const toSwapOut = amountEnd.sub(wbtcBalance).div(divver);
  //   const maxSwapIn = await WETH.balanceOf(signer.address);
  //   await WETH.approve(router.address, maxSwapIn);
  //   await router.exactOutput({
  //     path: ethers.utils.solidityPack(['address', 'uint24', 'address'], [WBTC.address, 500, WETH.address]),
  //     recipient: signer.address,
  //     deadline: Math.floor(new Date / 1000) + 60,
  //     amountOut: toSwapOut,
  //     amountInMaximum: maxSwapIn
  //   });

  //   ({amountStart, amountEnd} = await uniproxy.getDepositAmount(hypervisor, WETH.address, await WETH.balanceOf(signer.address)));
  //   wbtcBalance = await WBTC.balanceOf(signer.address);
  //   if (divver > 2) divver--;
  //   console.log('amountStart', amountStart);
  //   console.log('amountEnd', amountEnd);
  //   console.log('wbtcBalance', wbtcBalance);
  //   console.log('divver', divver)
  //   console.log('---')
  // }

  // console.log(await WETH.balanceOf(signer.address));
  // console.log(await uniproxy.getDepositAmount(hypervisor, WETH.address, await WETH.balanceOf(signer.address)));
  // console.log(await WBTC.balanceOf(signer.address));


  // ---------
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
const { ethers, upgrades, network } = require("hardhat");

async function main() {
  // const [user] = await ethers.getSigners()
  // const userAddress = '0xCa17e2A2264f4Cf721a792d771A4021c37538049'
  // await network.provider.request({
  //   method: "hardhat_impersonateAccount",
  //   params: [userAddress],
  // });
  const vaultManager = await ethers.getContractAt('SmartVaultManagerV2','0x2342755a637451e9af75545e257Cb007EaC930B1')
  // const user = await ethers.getSigner(userAddress)
  const vault = await ethers.getContractAt('SmartVaultV2','0xa78B06899b99381B12037ebEDdE177Ac3DCb486c');
  // const router = await ethers.getContractAt('ISwapRouter', await vaultManager.swapRouter());
  const tokens = await (await ethers.getContractAt('TokenManager', '0x08A9Aae3Fb5581D57fbE509451042cb446495b57')).getAcceptedTokens();
  // await vault.connect(user).mint(userAddress, ethers.utils.parseEther('1'));
  console.log(await vault.status())
  // await vault.swap(
  //   tokens[0].symbol,
  //   tokens[1].symbol,
  //   '100000000000000'
  // )

  // const router = await ethers.getContractAt('MockSwapRouter', '0x66462401Dd4b40EFF1f5891bC5D916Ce0c754AE2');
  // console.log(await router.receivedSwap())
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
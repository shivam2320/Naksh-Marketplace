// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const Naksh = await hre.ethers.getContractFactory("NakshNFTMarketplace");
  const naksh = await Naksh.deploy("Naksh", "nksh", "0xA4c1CfC730b65239B6242A239E082afB46C1d33f", "0x7b64a3Da11e7EC6DAD92e75516Fa68eC9819D6c4");

  await naksh.deployed();

  console.log("Naksh deployed to:", naksh.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

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
  const naksh = await Naksh.deploy("Naksh", "nksh", "0x4e7f624C9f2dbc3bcf97D03E765142Dd46fe1C46", "0x4e7f624C9f2dbc3bcf97D03E765142Dd46fe1C46");

  await naksh.deployed();

  console.log("Naksh deployed to:", naksh.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

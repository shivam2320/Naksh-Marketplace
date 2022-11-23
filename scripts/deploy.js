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
  const Naksh = await hre.ethers.getContractFactory("Naksh721Marketplace");
  const naksh = await Naksh
    .deploy
    // [
    //   "Naksh",
    //   "0x752759Fa51103DA478DCa2dc96B91D051C201351",
    //   "https://naksh-dev.s3.ap-south-1.amazonaws.com/artist/c706f408-2c6c-4c67-9dae-4e1f1315a785",
    // ],
    // [
    //   "Marketplace",
    //   "NKSH",
    //   "An NFT marketplace fuelled by art communities from all over India",
    //   "https://naksh-dev.s3.ap-south-1.amazonaws.com/artist/c706f408-2c6c-4c67-9dae-4e1f1315a785",
    //   ["linear-gradient(90.14deg, #FFC149 0.11%, #FF3C8E 99.88%)", true],
    //   ["", "", "https://twitter.com/NakshMarket", ""],
    // ],
    // "0x752759Fa51103DA478DCa2dc96B91D051C201351",
    // [],
    // []
    ();

  await naksh.deployed();

  console.log("Naksh deployed to:", naksh.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

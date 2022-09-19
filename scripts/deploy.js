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
  const Naksh = await hre.ethers.getContractFactory("NakshNFT");
  const naksh = await Naksh.deploy(
    ["artist", "0x3f6C3Bc1679731825d457541bD27C1d713698306", "imags"],
    [
      "Test1",
      "TST1",
      "assa",
      "saza",
      ["saa", false],
      ["ins", "fb", "sa", "saxs"],
    ],
    "0x3f6C3Bc1679731825d457541bD27C1d713698306",
    "0x3f6C3Bc1679731825d457541bD27C1d713698306",
    "600",
    ["0x3f6C3Bc1679731825d457541bD27C1d713698306"]
  );

  await naksh.deployed();

  console.log("Naksh deployed to:", naksh.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

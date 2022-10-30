const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Naksh Factory", () => {
  let owner;
  let org;
  let admin;
  let addr1;
  let addr2;
  let addr3;
  let creator;
  let Naksh;
  let naksh;

  beforeEach(async () => {
    [owner, org, admin, addr1, addr2, addr3, creator] =
      await ethers.getSigners();
    Naksh = await ethers.getContractFactory("Naksh721Factory");
    naksh = await Naksh.deploy();

    await naksh.deployed();
  });

  describe("Deploying collection", () => {
    it("Should deploy NFT collection", async () => {
      await naksh
        .connect(creator)
        .deployNftCollection(
          ["Shivam", creator.address, "IMGURL"],
          [
            "Collection1",
            "C1",
            "Some about info",
            "LOGO",
            ["some uri", "false"],
            ["INSTA", "FB", "TWITR", "Website"],
          ],
          admin.address,
          [500],
          [creator.address]
        );

      console.log(await naksh.getArtistCollections(creator.address));
    });
  });
});

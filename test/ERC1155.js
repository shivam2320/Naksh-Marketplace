const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Naksh ERC1155 NFT", () => {
  let org;
  let admin;
  let addr1;
  let addr2;
  let creator;
  let Naksh;
  let naksh;

  beforeEach(async () => {
    [owner, org, admin, addr1, addr2, creator] = await ethers.getSigners();
    Naksh = await ethers.getContractFactory("Naksh1155NFT");
    naksh = await Naksh.deploy(
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
      [500, 600],
      [addr1.address, addr2.address]
    );

    await naksh.deployed();
  });

  describe("Royalty fees", () => {
    it("Should show royalty", async () => {
      expect(await naksh.totalCreatorFees()).to.equal(1100);
      expect(await naksh.orgFee()).to.equal(500);
      expect(await naksh.orgFeeInitial()).to.equal(500);
      expect(await naksh.TotalSplits()).to.equal(2);
      expect(await naksh.sellerFeeInitial()).to.equal(9500);
      expect(await naksh.sellerFee()).to.equal(8400);
      // console.log(await naksh.getCollectionDetails());
      // console.log(await naksh.fetchArtist(creator.address));
    });
  });

  describe("Minting", () => {
    it("Should single mint", async () => {
      await naksh
        .connect(creator)
        .mintByArtistOrAdmin(
          creator.address,
          "tokenuri1",
          10,
          "title1",
          "desc1",
          "artistName1",
          "artistImg1"
        );
      // console.log(await naksh.tokenURI(1));

      await naksh
        .connect(admin)
        .mintByArtistOrAdmin(
          creator.address,
          "tokenuri2",
          20,
          "title2",
          "desc2",
          "artistName2",
          "artistImg2"
        );

      // console.log(await naksh.getNFTData(2));

      expect(await naksh.totalSupply()).to.be.equals(2);
      expect(await naksh.balanceOf(creator.address, 1)).to.be.equals(10);
      await naksh.connect(admin).burn(creator.address, 1, 5);
      await naksh.connect(creator).burn(creator.address, 2, 10);
    });
  });
});

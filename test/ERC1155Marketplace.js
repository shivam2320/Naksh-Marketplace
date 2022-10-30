const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Naksh Marketplace", () => {
  let owner;
  let org;
  let admin;
  let addr1;
  let addr2;
  let addr3;
  let creator;
  let NakshMarket;
  let nakshM;
  let NakshNFT;
  let nakshNft;

  beforeEach(async () => {
    [owner, org, admin, addr1, addr2, addr3, creator] =
      await ethers.getSigners();
    NakshMarket = await ethers.getContractFactory("Naksh1155Marketplace");
    nakshM = await NakshMarket.connect(owner).deploy();

    await nakshM.deployed();
    await nakshM.connect(owner).changeOrgAddress(org.address);

    NakshNFT = await ethers.getContractFactory("Naksh1155NFT");
    nakshNft = await NakshNFT.connect(owner).deploy(
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

    await nakshNft.deployed();
  });

  describe("Put on sale", () => {
    it("Should put on sale", async () => {
      expect(
        await nakshNft
          .connect(admin)
          .mintByArtistOrAdmin(
            creator.address,
            "data:application/json;base64,eyJ0aXRsZSI6ICJ0aXRsZSIsICJkZXNjcmlwdGlvbiI6ICJkZXNjIiwgImltYWdlIjogInVyaSIsICJhcnRpc3QgbmF",
            "10",
            "Nakshhhhhh",
            "some descriptionnnnn",
            "Artistttt",
            "ArtistImg"
          )
      );
      await nakshNft.connect(creator).setApprovalForAll(nakshM.address, true);
      await nakshM.connect(creator).setSale(nakshNft.address, 1, 10, 1000);
      expect(
        await nakshM.isTokenFirstSale(nakshNft.address, 1, creator.address)
      ).to.equal(false);
      // await nakshM.connect(creator).cancelSale(nakshNft.address, 1, 10);
      await nakshM
        .connect(addr1)
        .buyTokenOnSale(1, nakshNft.address, creator.address, 10, {
          value: ethers.utils.parseEther("1"),
        });
      // expect(
      //   await nakshM.getSalePrice(nakshNft.address, 1, creator.address)
      // ).to.equal(1000);

      console.log(await nakshM.getNFTonSale());
    });
  });

  //   describe("Buy NFT on sale", () => {
  //     it("Should", async () => {
  //       await naksh
  //         .connect(admin)
  //         .mintByAdmin(creator.address, "tokenuri", "title", "desc", "artist");
  //       await naksh.connect(creator).setSale(1, 1);
  //       await naksh.connect(addr1).buyTokenOnSale(1, naksh.address, {
  //         value: ethers.utils.parseEther("1"),
  //       });
  //       expect(await naksh.isTokenFirstSale(1)).to.equal(true);
  //     });
  //   });
});

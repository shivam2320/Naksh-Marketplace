const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("Naksh Marketplace", () => {
  let owner;
  let org;
  let admin;
  let addr1;
  let addr2;
  let addr3;
  let addr4;
  let addr5;
  let creator;
  let NakshMarket;
  let nakshM;
  let NakshNFT;
  let nakshNft;

  beforeEach(async () => {
    [owner, org, admin, addr1, addr2, addr3, addr4, addr5, creator] =
      await ethers.getSigners();
    NakshMarket = await ethers.getContractFactory("Naksh721Marketplace");
    nakshM = await NakshMarket.connect(owner).deploy();

    await nakshM.deployed();
    await nakshM.connect(owner).changeOrgAddress(org.address);

    NakshNFT = await ethers.getContractFactory("Naksh721DefaultNFT");
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
      [],
      []
    );

    await nakshNft.deployed();
  });

  describe("Put on sale", () => {
    it("Should put on sale", async () => {
      await nakshNft
        .connect(admin)
        .mintByArtistOrAdmin(
          creator.address,
          "data:application/json;base64,eyJ0aXRsZSI6ICJ0aXRsZSIsICJkZXNjcmlwdGlvbiI6ICJkZXNjIiwgImltYWdlIjogInVyaSIsICJhcnRpc3QgbmF",
          "",
          "Nakshhhhhh",
          "some descriptionnnnn",
          "Artistttt",
          "ArtistImg",
          false
        );

      await nakshNft.connect(creator).setApprovalForAll(nakshM.address, true);
      await nakshM.connect(creator).setSale(nakshNft.address, 1, 1);
      console.log("1st owner", creator.address);
      expect(await nakshM.isTokenFirstSale(nakshNft.address, 1)).to.equal(
        false
      );
      // await nakshM.connect(creator).cancelSale(nakshNft.address, 1);
      expect(await nakshM.getSalePrice(nakshNft.address, 1)).to.equal(1);
      // console.log(
      //   "1st sale data",
      //   await nakshM.getSaleData(nakshNft.address, 1)
      // );
      await nakshM.connect(addr4).buyTokenOnSale(1, nakshNft.address, {
        value: ethers.utils.parseEther("1"),
      });
      console.log("addr4", addr4.address);
      console.log("1st working");
      await nakshNft.connect(addr4).setApprovalForAll(nakshM.address, true);
      await nakshM.connect(addr4).setSale(nakshNft.address, 1, 1);
      // expect(await nakshM.isTokenFirstSale(nakshNft.address, 1)).to.equal(true);
      // console.log(
      //   "2nd sale data",
      //   await nakshM.getSaleData(nakshNft.address, 1)
      // );

      await nakshM.connect(addr5).buyTokenOnSale(1, nakshNft.address, {
        value: ethers.utils.parseEther("1"),
      });
      console.log("addr5", addr5.address);
      console.log("2nd working");
      // console.log(await nakshM.getSaleData(nakshNft.address, 1));
      const provider = waffle.provider;
      // console.log(await provider.getBalance(creator.address));
    });
  });

  describe("Buy NFT on sale", () => {
    it("Should", async () => {
      await nakshNft
        .connect(admin)
        .mintByArtistOrAdmin(
          creator.address,
          "data:application/json;base64,eyJ0aXRsZSI6ICJ0aXRsZSIsICJkZXNjcmlwdGlvbiI6ICJkZXNjIiwgImltYWdlIjogInVyaSIsICJhcnRpc3QgbmF",
          "",
          "Nakshhhhhh",
          "some descriptionnnnn",
          "Artistttt",
          "ArtistImg",
          false
        );

      await nakshNft.connect(creator).setApprovalForAll(nakshM.address, true);
      await nakshM.connect(creator).setSale(nakshNft.address, 1, 1);
      expect(await nakshM.isTokenFirstSale(nakshNft.address, 1)).to.equal(
        false
      );
      await nakshM.connect(creator).cancelSale(nakshNft.address, 1);
      // expect(await nakshM.getSalePrice(nakshNft.address, 1)).to.equal(1);

      // await nakshM.buyTokenOnSale(1, nakshNft.address, {
      //   value: ethers.utils.parseEther("1"),
      // });

      // console.log(await nakshM.getSaleData(nakshNft.address, 1));
      const provider = waffle.provider;
      // console.log(await provider.getBalance(creator.address));
    });
  });

  describe("Auction", () => {
    it("Should start and end auction", async () => {
      await nakshNft
        .connect(admin)
        .mintByArtistOrAdmin(
          creator.address,
          "data:application/json;base64,eyJ0aXRsZSI6ICJ0aXRsZSIsICJkZXNjcmlwdGlvbiI6ICJkZXNjIiwgImltYWdlIjogInVyaSIsICJhcnRpc3QgbmF",
          "",
          "Nakshhhhhh",
          "some descriptionnnnn",
          "Artistttt",
          "ArtistImg",
          false
        );

      await nakshNft.connect(creator).setApprovalForAll(nakshM.address, true);
      await nakshM.connect(creator).startAuction(nakshNft.address, 1, 1, 60);

      await nakshM
        .connect(addr2)
        .bid(nakshNft.address, 1, { value: ethers.utils.parseEther("1") });
      await nakshM
        .connect(addr3)
        .bid(nakshNft.address, 1, { value: ethers.utils.parseEther("2") });
      await nakshM
        .connect(addr3)
        .bid(nakshNft.address, 1, { value: ethers.utils.parseEther("3") });
      await nakshM
        .connect(addr3)
        .bid(nakshNft.address, 1, { value: ethers.utils.parseEther("4") });

      // console.log(
      //   "Bid History: ",
      //   await nakshM.getBidHistory(nakshNft.address, 1)
      // );
      // console.log(await nakshM.getSaleData(nakshNft.address, 1));
      await nakshM.connect(creator).endAuction(nakshNft.address, 1);
      console.log("2nd auction");
      await nakshNft.connect(creator).setApprovalForAll(nakshM.address, true);
      await nakshM.connect(creator).startAuction(nakshNft.address, 1, 1, 60);

      await nakshM.connect(creator).endAuction(nakshNft.address, 1);
      expect(await nakshNft.ownerOf(1)).to.equal(creator.address);
    });
  });
});

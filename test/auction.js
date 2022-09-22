const { ethers, waffle } = require("hardhat");
const { expect } = require("chai");

describe("Naksh Marketplace", () => {
  let owner;
  let org;
  let admin;
  let addr1;
  let addr2;
  let addr3;
  let addr4;
  let creator;
  let NFT;
  let naksh;
  let Marketplace;
  let market;

  beforeEach(async () => {
    [owner, org, admin, addr1, addr2, addr3, addr4, creator] =
      await ethers.getSigners();
    NFT = await ethers.getContractFactory("NakshNFT");
    naksh = await NFT.deploy(
      ["artist", owner.address, "imags"],
      [
        "Test1",
        "TST1",
        "assa",
        "saza",
        ["saa", false],
        ["ins", "fb", "sa", "saxs"],
      ],
      owner.address,
      owner.address,
      ["600"],
      [owner.address],
      600
    );
    await naksh.deployed();

    Marketplace = await ethers.getContractFactory("NakshMarketplace");
    market = await Marketplace.deploy();
    await market.deployed();
  });

  describe("Buy NFT on sale", () => {
    it("Should", async () => {
      await naksh
        .connect(owner)
        .mintByArtistOrAdmin(creator.address, "uri", "title", "desc", "name");
      await naksh.connect(creator).setApprovalForAll(market.address, true);
      await market.connect(creator).setSale(naksh.address, 1, 1);
      await market.connect(addr1).buyTokenOnSale(1, naksh.address, {
        value: ethers.utils.parseEther("1"),
      });
      //   expect(await naksh.isTokenFirstSale(1)).to.equal(true);
    });
  });

  describe("Auction", () => {
    it("Should start and end auction", async () => {
      const provider = waffle.provider;
      await naksh
        .connect(owner)
        .mintByArtistOrAdmin(creator.address, "uri", "title", "desc", "name");
      await naksh.connect(creator).setApprovalForAll(market.address, true);

      await market.connect(creator).startAuction(naksh.address, 1, 1, 600);

      await market
        .connect(addr1)
        .bid(naksh.address, 1, { value: ethers.utils.parseEther("1000") });
      await market
        .connect(addr2)
        .bid(naksh.address, 1, { value: ethers.utils.parseEther("2000") });
      await market
        .connect(addr3)
        .bid(naksh.address, 1, { value: ethers.utils.parseEther("3000") });
      await market
        .connect(addr4)
        .bid(naksh.address, 1, { value: ethers.utils.parseEther("4000") });

      //   console.log(
      //     "Bid History: ",
      //     await market.getBidHistory(naksh.address, 1)
      //   );
    });
  });
});

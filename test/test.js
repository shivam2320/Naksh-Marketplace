const { ethers } = require('hardhat');
const { expect } = require('chai');

describe("Naksh Marketplace", () => {

  let owner;
  let org;
  let admin;
  let addr1;
  let addr2;
  let addr3;
  let creator;
  let Naksh;
  let naksh;

  beforeEach(async() => {
    [owner, org, admin, addr1, addr2, addr3, creator] = await ethers.getSigners();
    Naksh = await ethers.getContractFactory("NakshNFTMarketplace");
    naksh = await Naksh.deploy("Naksh", "nk", org.address, admin.address);

    await naksh.deployed();
  });

  describe("Admin minting", () => {
    it("Should mint by admin", async() => {
      await expect(naksh.connect(addr1).mintByAdmin(creator.address, "tokenuri", "title", "desc", "artist")).to.be.reverted;
      expect(await naksh.totalSupply()).to.equal(0);

      expect(await naksh.connect(admin).mintByAdmin(creator.address, "tokenuri", "title", "desc", "artist"));
      expect(await naksh.totalSupply()).to.equal(1);

    });
  });

  describe("Artist Minting", () => {
    it("Should mint by artist", async() => {
      await naksh.createArtist("name", creator.address, "img");
      console.log(await naksh.fetchArtist(creator.address));
      await naksh.connect(creator).mintByArtist("uri", "title", "desc", "name");
      console.log(await naksh.tokenURI(1));
    });
  });

  describe("Put on sale", ()=> {
    it("Should put on sale", async() => {
      expect(await naksh.connect(admin).mintByAdmin(creator.address, "tokenuri", "title", "desc", "artist"));
      await naksh.connect(creator).setSale(1, 1);
      expect(await naksh.isTokenFirstSale(1)).to.equal(false);
      expect(await naksh.getSalePrice(1)).to.equal(1);

      console.log(await naksh.getNFTonSale());
    });
  });

  describe("Buy NFT on sale", () => {
    it("Should", async() => {
      await naksh.connect(admin).mintByAdmin(creator.address, "tokenuri", "title", "desc", "artist");
      await naksh.connect(creator).setSale(1, 1);
      await naksh.connect(addr1).buyTokenOnSale(1, naksh.address, {value : ethers.utils.parseEther("1")});
      expect(await naksh.isTokenFirstSale(1)).to.equal(true);

    });
  });

  describe("Bulk Mint by Admin", () => {
    it("Should", async() => {
      await naksh.connect(admin).bulkMintByAdmin([creator.address, addr1.address], ["uri1", "uri2"], ["title1", "title2"], ["desc1", "desc2"], ["name1", "name2"]);
    });
  });

  describe("Bulk Mint by Artist", () => {
    it("Should", async() => {
      await naksh.createArtist("name", creator.address, "img");
      await naksh.connect(creator).bulkMintByArtist(["uri1", "uri2"], ["title1", "title2"], ["desc1", "desc2"], "name2");
    });
  });

  describe("Auction", () => {
    it("Should start and end auction", async() => {
      await naksh.createArtist("name", creator.address, "img");
      await naksh.connect(creator).mintByArtist("uri", "title", "desc", "name");
      await naksh.connect(creator).approve(naksh.address, 1);
      await naksh.connect(creator).startAuction(1, 1, 60);

      await naksh.connect(addr2).bid(1, {value: ethers.utils.parseEther('1')});
      await naksh.connect(addr3).bid(1, {value: ethers.utils.parseEther('2')});

      await expect(naksh.connect(creator).endAuction(1, naksh.address)).to.be.reverted;
    });
  });



});

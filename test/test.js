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

  describe("Put on sale", ()=> {
    it("Should put on sale", async() => {
      expect(await naksh.connect(admin).mintByAdmin(creator.address, "tokenuri", "title", "desc", "artist"));
      await naksh.connect(creator).setSale(1, 1);
      expect(await naksh.getSalePrice(1)).to.equal(1);

      console.log(await naksh.getNFTonSale());
    });
  });

//   describe("", () => {
//     it("Should", async() => {

//     });
//   });

//  describe("", () => {
//     it("Should", async() => {

//     });
//   });


});
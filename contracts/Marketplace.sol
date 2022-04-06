// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**  
* @title An NFT Marketplace contract for Naksh NFTs
* @notice This is the Naksh Marketplace contract for Minting NFTs and Direct Sale + Auction.
* @dev Most function calls are currently implemented with access control
*/

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/* 
* This is the Naksh Marketplace contract for Minting NFTs and Direct Sale only.
*/
contract NakshNFT is ERC721URIStorage {

    using SafeMath for uint256;
    mapping(uint256 => uint256) private salePrice;
    mapping(address => bool) public creatorWhitelist;
    mapping(uint256 => address) private tokenOwner;
    mapping(uint256 => address) private tokenCreator;
    mapping(address => uint[]) private creatorTokens;
    mapping(uint => bool) private tattooRedeemed;
    //This is to determine the platform royalty for the first sale made by the creator
    mapping(uint => bool) private tokenFirstSale;
    mapping(uint => NFTAuction) public auctionData;
    mapping(address => uint) public bids;

    event SalePriceSet(uint256 indexed _tokenId, uint256 indexed _price);
    event Sold(address indexed _buyer, address indexed _seller, uint256 _amount, uint256 indexed _tokenId);
    event WhitelistCreator(address indexed _creator);
    event DelistCreator(address indexed _creator);
    event OwnershipGranted(address indexed newOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Mint(address indexed creator,uint indexed tokenId, string indexed tokenURI);
    event startedAuction(uint startTime, uint endTime, uint indexed tokenId, address indexed owner, uint indexed price);
    event stoppedAuction();
    event bidded();

    uint constant FLOAT_HANDLER_TEN_4 = 10000;

    address owner;
    address _grantedOwner;
    address admin;
    uint256 sellerFee;
    uint256 orgFee;
    uint256 creatorFee;
    uint256 sellerFeeInitial;
    uint256 orgFeeInitial;
    address payable Naksh_org;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    enum minter{
        Admin,
        Artist
    }

    struct NFTData {
        uint tokenId;
        string title;
        string description;
        string artistName;
        address creator;
        minter mintedBy;
    }

    NFTData[] mintedNfts;

    struct NFTAuction {
        uint startTime;
        uint endTime;
        uint tokenId;
        address owner;
        uint price;
        uint highestBid;
        address highestBidder;
    }

    NFTAuction[] auctionedNFTs;

    /**
    * Modifier to allow only minters to mint
    */
    modifier onlyArtist() virtual {
        require(creatorWhitelist[msg.sender] == true);
        _;
    }

    /**
    * Modifier to allow only owners of a token to perform certain actions 
    */
    modifier onlyOwnerOf(uint256 _tokenId) {
        require(ownerOf(_tokenId) == msg.sender);
        _;
    }

    /**
    * Modifier to allow only owner of the contract to perform certain actions 
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    /**
    * Modifier to allow only admin of the organization to perform certain actions 
    */
    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    constructor(string memory _name, 
        string memory _symbol,
        address payable org,
        address payable _admin
        )
        ERC721(_name, _symbol)
    {
        owner = msg.sender;
        admin = _admin;
        Naksh_org = org;
        //Multiply all the three % variables by 100, to kepe it uniform
        orgFee = 500;
        creatorFee = 1500;
        sellerFee = 10000 - orgFee - creatorFee;
        // Fees for first sale only
        orgFeeInitial = 500;
        sellerFeeInitial = 10000 - orgFeeInitial;
    }

    /**
    * @dev Owner can transfer the ownership of the contract to a new account (`_grantedOwner`).
    * Can only be called by the current owner.
    */
    function grantContractOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        emit OwnershipGranted(newOwner);
        _grantedOwner = newOwner;
    }
    
    /**
    * @dev Claims granted ownership of the contract for a new account (`_grantedOwner`).
    * Can only be called by the currently granted owner.
    */
    function claimContractOwnership() public virtual {
        require(_grantedOwner == msg.sender, "Ownable: caller is not the granted owner");
        emit OwnershipTransferred(owner, _grantedOwner);
        owner = _grantedOwner;
        _grantedOwner = address(0);
    }

    /** 
    *@dev Current admin can transfer admin rights to a new account.
    */
    function grantAdminRights(address newAdmin) public virtual onlyAdmin {
        require(newAdmin != address(0), "New Admin cannot be zero address");
        admin = newAdmin;
    }

    /**
    * @dev Organisation address can be updated to another address in case of attack or compromise(`newOrg`)
    * Can be done only by the contract owner.
    */
    function changeOrgAddress(address _newOrg) public onlyOwner {
        require(_newOrg != address(0), "New organization cannot be zero address");
        Naksh_org = payable(_newOrg);
    }

    /**
    * @dev This function is used to get the seller percentage. 
    * This refers to the amount of money that would be distributed to the seller 
    * after the reduction of royalty and platform fees.
    * The values are multipleied by 100, in order to work easily 
    * with floating point percentages.
    */
    function getSellerFee() public view returns (uint256) {
        //Returning % multiplied by 100 to keep it uniform across contract
        return sellerFee;
    }


     /** @dev Calculate the royalty distribution for organisation/platform and the
    * creator/artist.
    * Each of the organisation, creator royalty and the parent organsation fees
    * are set in this function.
    * The 'sellerFee' indicates the final amount to be sent to the seller.
    */
    function setRoyaltyPercentage(uint256 _orgFee, uint _creatorFee) public onlyOwner returns (bool) {
        //Sum of org fee and creator fee should be 100%
        require(10000 > _orgFee+_creatorFee, "Sum of creator fee and org fee should be 100%");
        orgFee = _orgFee;
        creatorFee = _creatorFee;
        sellerFee = 10000 - orgFee - creatorFee;
        return true; 
    }

    /** @dev Calculate the royalty distribution for organisation/platform and the
    * creator/artist(who would be the seller) on the first sale.
    * The first iteration of whitepaper has the following stats:
    * orgFee = 2%
    * artist royalty/creator fee = 0%
    * The above numbers can be updated later by the DAO
    * @notice _creatorFeeInitial should be sellerFeeInitial - seller fees on first sale
    */
    function setRoyaltyPercentageFirstSale(uint256 _orgFeeInitial, uint _creatorFeeInitial) public onlyOwner returns (bool) {
        orgFeeInitial = _orgFeeInitial;
        sellerFeeInitial = _creatorFeeInitial;
        return true;
    }

    /** @dev Return all the royalties including first sale and subsequent sale values
    * orgFee - % of fees that would go to the org from the total royalty
    * creatorRoyalty - % of fees that would go to the artist/creator
    * orgInitialRoyalty - % of fees that would go to the organisation on first sale
    * sellerFeeInitial - % of fees for seller on the first sale
    */
    function getRoyalties() public view returns (uint _orgFee, uint256 _creatorRoyalty, 
    uint256 _orgInitialRoyalty, uint256 _sellerFeeInitial) {
        
        return (orgFee, creatorFee, orgFeeInitial, sellerFeeInitial);
    }


    /**
    * This function is used to change the price of a token
    * @notice Only token owner is allowed to change the price of a token
    */
    function changePrice(uint256 _tokenId, uint256 price) public onlyOwnerOf(_tokenId) {
        require(price > 0, "changePrice: Price cannot be changed to less than 0");
        salePrice[_tokenId] = price;
    }

    /**
    * This function is used to check if it is the first sale of a token
    * on the Naksh marketplace.
    */
    function isTokenFirstSale(uint tokenId) external view returns(bool){
        return tokenFirstSale[tokenId];
    }

    /**
    * This function is used to mint an NFT for the Naksh marketplace.
    * @dev The basic information related to the NFT needs to be passeed to this function,
    * in order to store it on chain to avoid disputes in future.
    */
    function mintByArtist(string memory _tokenURI, string memory title,
    string memory description, string memory artistName) public virtual onlyArtist returns (uint256 _tokenId) {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        tokenOwner[tokenId] = msg.sender;

       
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        tokenCreator[tokenId] = msg.sender;
        
        NFTData memory nftNew = NFTData(tokenId, title, description, artistName, msg.sender, minter.Artist);
        mintedNfts.push(nftNew);
        
        creatorTokens[msg.sender].push(tokenId);
        emit Mint(msg.sender, tokenId, _tokenURI);
        return tokenId;
    }

    /**
    * This function is used to mint an NFT for the Naksh marketplace.
    * @dev The basic information related to the NFT needs to be passeed to this function,
    * in order to store it on chain to avoid disputes in future.
    */
    function mintByAdmin(address _creator, string memory _tokenURI, string memory title,
    string memory description, string memory artistName) public virtual onlyAdmin returns (uint256 _tokenId) {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        tokenOwner[tokenId] = _creator;

       
        _mint(_creator, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        tokenCreator[tokenId] = _creator;
        
        NFTData memory nftNew = NFTData(tokenId, title, description, artistName, _creator, minter.Admin);
        mintedNfts.push(nftNew);
        
        creatorTokens[_creator].push(tokenId);
        emit Mint(_creator,tokenId, _tokenURI);
        return tokenId;
    }
    
    /**
    * This function is used to set an NFT on sale. 
    * @dev The sale price set in this function will be used to perform the sale transaction
    * once the buyer wants to buy an NFT.
    */
    function setSale(uint256 _tokenId, uint256 price) public virtual onlyOwnerOf(_tokenId) {
        address tOwner = ownerOf(_tokenId);
        require(tOwner != address(0), "setSale: nonexistent token");
        salePrice[_tokenId] = price;
        emit SalePriceSet(_tokenId, price);
    }

    /**
    * This function is used to buy an NFT which is on sale.
    */
    function buyTokenOnSale(uint256 tokenId)
        public
        payable
    {

        uint256 price = salePrice[tokenId];
        uint256 sellerFees = getSellerFee();
        uint256 creatorRoyalty = creatorFee;
        uint256 platformFees = orgFee;

        require(price != 0, "buyToken: price equals 0");
        require(
            msg.value == price,
            "buyToken: price doesn't equal salePrice[tokenId]"
        );
        address tOwner = ownerOf(tokenId);

        safeTransferFrom(tOwner, msg.sender, tokenId);
        salePrice[tokenId] = 0;

        if(tokenFirstSale[tokenId] == false) {
            /* Platform takes 5% on each artist's first sale
            *  All values are multiplied by 100 to deal with floating points
            */
            platformFees = orgFeeInitial;
            sellerFees = sellerFeeInitial;
            // No creator royalty/royalties when artist is minting for the first time
            creatorRoyalty = 0;

            tokenFirstSale[tokenId] = true;
        }   
        
        //Dividing by 100*100 as all values are multiplied by 100
        uint256 toSeller = (msg.value * sellerFees) / FLOAT_HANDLER_TEN_4;
        
        //Dividing by 100*100 as all values are multiplied by 100
        uint256 toCreator = (msg.value*creatorRoyalty) / FLOAT_HANDLER_TEN_4;
        uint256 toPlatform = (msg.value*platformFees) / FLOAT_HANDLER_TEN_4;
        
        address tokenCreatorAddress = tokenCreator[tokenId];
        
        payable(tOwner).transfer(toSeller);
        if(toCreator != 0) {
            payable(tokenCreatorAddress).transfer(toCreator);
        }
        
        Naksh_org.transfer(toPlatform);

        
        emit Sold(msg.sender, tOwner, msg.value, tokenId);
    }

    /**
    * This function is used to return all the tokens created by a specific creator
    */
    function tokenCreators(address _creator) external view onlyOwner returns(uint[] memory) {
            return creatorTokens[_creator];
    }

    /**
    * This function is used to whitelist a creator/ an artist on the platform
    */
    function whitelistCreator(address[] memory _creators) public onlyOwner {
        for(uint i = 0; i < _creators.length; i++){
            if(creatorWhitelist[_creators[i]]){
                //Do nothing if address is already whitelisted
            }
            else {
                creatorWhitelist[_creators[i]] = true;
                emit WhitelistCreator(_creators[i]);
            }
        }
        
    }

    /**
    * This function is used to unlist/delist a creator from the platform
    */
    function delistCreator(address[] memory _creators) public onlyOwner {
        for(uint i = 0; i < _creators.length; i++){
            if (creatorWhitelist[_creators[i]] == true){
                creatorWhitelist[_creators[i]] = false;
                emit DelistCreator(_creators[i]);
            }
        }
        
    }

    /**
    * This is a getter function to get the current price of an NFT.
    */
    function getSalePrice(uint256 tokenId) public view returns (uint256) {
        return salePrice[tokenId];
    }

     /**
    * This function returns if a creator is whitelisted on the platform or no
    */
    function isWhitelisted(address _creator) external view returns (bool) {
        return creatorWhitelist[_creator];
    }

    /**
    * This returns the total number of NFTs minted on the platform
    */
    function totalSupply() public view virtual returns (uint256) {
        return _tokenIds.current();
    }

    /**
    *This function is used to burn NFT, only Admin is allowed
    */
    function burn(uint256 tokenId) public onlyAdmin {
        _burn(tokenId);
    }

    /**
    *This function allows to bulk mint NFTs
    */
    function bulkMintByArtist(string[] memory _tokenURI, string[] memory title,
    string[] memory description, string[] memory artistName) public virtual onlyArtist returns (uint256[] memory _tokenId) {
        
        uint256[] memory tokenIds;

        uint256 length = title.length;

        for(uint i = 0; i < length;)
        {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        tokenOwner[tokenId] = msg.sender;
        
        tokenIds[i] = tokenId;
   
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI[i]);

        tokenCreator[tokenId] = msg.sender;
        
        NFTData memory nftNew = NFTData(tokenId, title[i], description[i], artistName[i], msg.sender, minter.Artist);
        mintedNfts.push(nftNew);
        
        creatorTokens[msg.sender].push(tokenId);

        unchecked { ++i; }

        emit Mint(msg.sender, tokenId, _tokenURI[i]);
        }
        return tokenIds;
    }

    /**
    *This function allows to bulk mint NFTs
    */
    function bulkMintByAdmin(address[] memory _creator, string[] memory _tokenURI, string[] memory title,
    string[] memory description, string[] memory artistName) public virtual onlyAdmin returns (uint256[] memory _tokenId) {
        
        uint256[] memory tokenIds;

        uint256 length = _creator.length;

        for(uint i = 0; i < length;)
        {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        tokenOwner[tokenId] = _creator[i];
        
        tokenIds[i] = tokenId;
   
        _mint(_creator[i], tokenId);
        _setTokenURI(tokenId, _tokenURI[i]);

        tokenCreator[tokenId] = _creator[i];
        
        NFTData memory nftNew = NFTData(tokenId, title[i], description[i], artistName[i], _creator[i], minter.Admin);
        mintedNfts.push(nftNew);
        
        creatorTokens[_creator[i]].push(tokenId);

        unchecked { ++i; }

        emit Mint(_creator[i],tokenId, _tokenURI[i]);
        }
        return tokenIds;
    }

    function startAuction(uint _tokenId, uint _price, uint _auctionTime) external onlyOwnerOf(_tokenId) returns (bool) {
        uint _startTime = block.timestamp;

        transferFrom(msg.sender, address(this), _tokenId);

        uint _endTime = block.timestamp + _auctionTime;

        NFTAuction memory nftAuction = NFTAuction(_startTime, _endTime, _tokenId, msg.sender, _price, 0, address(0));
        auctionData[_tokenId] = nftAuction;
        auctionedNFTs.push(nftAuction);

        emit startedAuction(_startTime, _endTime, _tokenId, msg.sender, _price);

        return true;
    }

    function bid(uint _tokenId) external payable returns (bool) {
        NFTAuction memory nftAuction = auctionData[_tokenId];

        require(nftAuction.endTime >= block.timestamp, "Auction has ended");
        require(nftAuction.price <= msg.value, "Pay more than base price");
        require(nftAuction.highestBid <= msg.value, "Pay more than highest bid");

        if(nftAuction.highestBidder != address(0)) {
            uint bal = bids[nftAuction.highestBidder];
            bids[nftAuction.highestBidder] = 0;
            payable(nftAuction.highestBidder).transfer(bal);
            nftAuction.highestBid = msg.value;
            bids[msg.sender] = nftAuction.highestBid;
            nftAuction.highestBidder = msg.sender;
        }

        nftAuction.highestBidder = msg.sender;
        nftAuction.highestBid = msg.value;
        
        return true;
    }


    function endAuction(uint _tokenId) external onlyOwnerOf(_tokenId) {
        NFTAuction memory nftAuction = auctionData[_tokenId];

        require(nftAuction.endTime <= block.timestamp, "Auction has not yet ended");

        if (nftAuction.highestBidder != address(0)) {
            uint256 price = salePrice[_tokenId];
            uint256 sellerFees = getSellerFee();
            uint256 creatorRoyalty = creatorFee;
            uint256 platformFees = orgFee;

            safeTransferFrom(address(this), nftAuction.highestBidder, _tokenId);
            payable(msg.sender).transfer(nftAuction.highestBid);
        } else {
            safeTransferFrom(address(this), msg.sender, _tokenId);
        }

    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**  
* @title An NFT Marketplace contract for Naksh NFTs
* @notice This is the Naksh Marketplace contract for Minting NFTs and Direct Sale + Auction.
* @dev Most function calls are currently implemented with access control
*/

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./Structs.sol";

/* 
* This is the Naksh Marketplace contract for Minting NFTs and Direct Sale + Auction.
*/
contract NakshNFT is ERC721URIStorage {

    using SafeMath for uint256;
    mapping(address => bool) public creatorWhitelist;
    mapping(uint256 => address) private tokenOwner;
    mapping(uint256 => address) private tokenCreator;
    mapping(address => uint[]) private creatorTokens;
    mapping(address => CollectionDetails) private collectionData;
    
    mapping(uint => NFTData) public nftData;
    mapping(address => artistDetails) artistData;

    event WhitelistCreator(address indexed _creator);
    event DelistCreator(address indexed _creator);
    event OwnershipGranted(address indexed newOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Mint(address indexed creator,uint indexed tokenId, string indexed tokenURI);

    uint constant FLOAT_HANDLER_TEN_4 = 10000;

    address public owner;
    address _grantedOwner;
    address public admin;
    uint256 public sellerFee;
    uint256 public orgFee;
    uint256 public creatorFee;
    address payable[] public creators;
    uint256 public TotalSplits = creators.length;
    uint256 public sellerFeeInitial;
    uint256 public orgFeeInitial;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct artistDetails {
        string name;
        address artistAddress;
        string imageUrl;
    }

    NFTData[] mintedNfts;

    /**
    * Modifier to allow only minters to mint
    */
    modifier onlyArtist() virtual {
        require(creatorWhitelist[msg.sender] == true);
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

    constructor(CollectionDetails memory collection,
        address _owner,
        address payable _admin,
        uint16 _creatorFee,
        address payable[] memory _creators
        )
        ERC721(collection.name, collection.symbol)
    {
        collectionData[address(this)] = collection;
        owner = _owner;
        admin = _admin;
        //Multiply all the three % variables by 100, to kepe it uniform
        orgFee = 500;
        creatorFee = _creatorFee;
        creators = _creators;
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

    function getCollectionDetails() external view returns (CollectionDetails memory) {
        return collectionData[address(this)];
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

    function createArtist(string memory _name, address _artist, string memory _image) public onlyOwner returns (bool) {
        require(_artist != address(0), "Artist is address(0)");
        artistDetails memory artist = artistDetails(_name, _artist, _image);
        artistData[_artist] = artist;
        creatorWhitelist[_artist] = true;

        return true;
    }

    function fetchArtist(address _artist) public view returns (artistDetails memory) {
        require(_artist != address(0), "Artist is address(0)");
        require(creatorWhitelist[_artist] == true, "Given address is not artist");
        return artistData[_artist];
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
    * orgFee = 5%
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

    function getNFTData(uint _tokenId) public view returns (NFTData memory) {
        return nftData[_tokenId];
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

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"title": "',title ,'", "description": "',description ,'", "image": "',_tokenURI ,'", "artist name": "',artistName ,'"}'
                    )
                )
            )
        );

        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
       
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, finalTokenUri);

        tokenCreator[tokenId] = msg.sender;
        
        NFTData memory nftNew = NFTData(address(this), tokenId, _tokenURI, title, description, artistName, artistData[msg.sender].imageUrl, msg.sender, minter.Artist);
        nftData[tokenId] = nftNew;
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

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"title": "',title ,'", "description": "',description ,'", "image": "',_tokenURI ,'", "artist name": "',artistName ,'"}'
                    )
                )
            )
        );

        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        _mint(_creator, tokenId);
        _setTokenURI(tokenId, finalTokenUri);

        tokenCreator[tokenId] = _creator;
        
        NFTData memory nftNew = NFTData(address(this), tokenId, _tokenURI, title, description, artistName, artistData[msg.sender].imageUrl, admin, minter.Admin);
        nftData[tokenId] = nftNew;
        mintedNfts.push(nftNew);
        
        creatorTokens[_creator].push(tokenId);
        emit Mint(_creator,tokenId, _tokenURI);
        return tokenId;
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
    string[] memory description, string memory artistName) public virtual onlyArtist returns (uint256[] memory _tokenId) {
        
        uint256[] memory tokenIds;

        uint256 length = title.length;

        for(uint i = 0; i < length;)
        {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        tokenOwner[tokenId] = msg.sender;

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"title": "',title[i] ,'", "description": "',description[i] ,'", "image": "',_tokenURI[i] ,'", "artist name": "',artistName ,'"}'
                    )
                )
            )
        );

        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
   
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, finalTokenUri);

        tokenCreator[tokenId] = msg.sender;
        
        NFTData memory nftNew = NFTData(address(this), tokenId, _tokenURI[i], title[i], description[i], artistName, artistData[msg.sender].imageUrl, msg.sender, minter.Artist);
        nftData[tokenId] = nftNew;
        mintedNfts.push(nftNew);
        
        creatorTokens[msg.sender].push(tokenId);

        emit Mint(msg.sender, tokenId, _tokenURI[i]);

        unchecked { ++i; }
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

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"title": "',title[i] ,'", "description": "',description[i] ,'", "image": "',_tokenURI[i] ,'", "artist name": "',artistName[i] ,'"}'
                    )
                )
            )
        );

        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
   
        _mint(_creator[i], tokenId);
        _setTokenURI(tokenId, finalTokenUri);

        tokenCreator[tokenId] = _creator[i];
        
        NFTData memory nftNew = NFTData(address(this), tokenId, _tokenURI[i], title[i], description[i], artistName[i], artistData[msg.sender].imageUrl, admin, minter.Admin);
        nftData[tokenId] = nftNew;
        mintedNfts.push(nftNew);
        
        creatorTokens[_creator[i]].push(tokenId);

        emit Mint(_creator[i],tokenId, _tokenURI[i]);

        unchecked { ++i; }
        }
        return tokenIds;
    }

}
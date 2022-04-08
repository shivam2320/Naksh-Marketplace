pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NakshNFT is ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address marketplace;
    address owner;
    address admin;

    event WhitelistCreator(address indexed _creator);
    event DelistCreator(address indexed _creator);
    event Mint(address indexed creator,uint indexed tokenId, string indexed tokenURI);

    mapping(address => bool) public creatorWhitelist;
    mapping(uint256 => address) private tokenCreator;
    mapping(uint256 => address) private tokenOwner;
    mapping(address => uint[]) private creatorTokens;

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

    constructor(address _marketplace, address _admin) ERC721("NAKSH", "NKSH") {
        marketplace = _marketplace;
        owner = msg.sender;
        admin = _admin;
    }

    /**
    * Modifier to allow only minters to mint
    */
    modifier onlyArtist() virtual {
        require(creatorWhitelist[msg.sender] == true);
        _;
    }

    /**
    * Modifier to allow only admin of the organization to perform certain actions 
    */
    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
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
        function totalSupply() public view virtual returns (uint256) {
        return _tokenIds.current();
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

}
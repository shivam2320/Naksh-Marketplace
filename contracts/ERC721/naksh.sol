// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title An NFT Marketplace contract for Naksh NFTs
 * @notice This is the Naksh Marketplace contract for Minting NFTs and Direct Sale + Auction.
 * @dev Most function calls are currently implemented with access control
 */

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "../Structs.sol";

/*
 * This is the Naksh Marketplace contract for Minting NFTs and Direct Sale + Auction.
 */
contract NakshDefaultNFT is ERC721URIStorage {
    // using SafeMath for uint256;
    mapping(address => bool) public creatorWhitelist;
    mapping(uint256 => address) private tokenOwner;
    mapping(address => uint256[]) private creatorTokens;
    mapping(address => CollectionDetails) private collectionData;

    mapping(uint256 => NFTData) public nftData;
    mapping(address => artistDetails) internal artistData;

    event WhitelistCreator(address _creator);
    event DelistCreator(address _creator);
    event OwnershipGranted(address newOwner);
    event OwnershipTransferred(address oldOwner, address newOwner);
    event Mint(
        address creator,
        uint256 tokenId,
        string tokenURI,
        string title,
        string description,
        string artistName,
        string artistImg
    );

    uint256 constant FLOAT_HANDLER_TEN_4 = 10000;

    address public owner;
    address _grantedOwner;
    address public admin;
    uint256 public sellerFee;
    uint256 public orgFee;
    uint16[] public creatorFees;
    uint256 public totalCreatorFees;
    address payable[] public creators;
    uint256 public TotalSplits = creators.length;
    uint256 public sellerFeeInitial;
    uint256 public orgFeeInitial;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    NFTData[] internal mintedNfts;

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

    constructor(
        artistDetails memory artist,
        CollectionDetails memory collection,
        address _owner,
        address payable _admin,
        uint16[] memory _creatorFees,
        address payable[] memory _creators,
        uint256 _totalCreatorFees
    ) ERC721(collection.name, collection.symbol) {
        artistData[artist.artistAddress] = artist;
        creatorWhitelist[artist.artistAddress] = true;
        collectionData[address(this)] = collection;
        owner = _owner;
        admin = _admin;
        //Multiply all the three % variables by 100, to kepe it uniform
        orgFee = 500;
        creatorFees = _creatorFees;
        creators = _creators;
        totalCreatorFees = _totalCreatorFees;
        sellerFee = 10000 - orgFee - totalCreatorFees;
        // Fees for first sale only
        orgFeeInitial = 500;
        sellerFeeInitial = 10000 - orgFeeInitial;
    }

    /**
     * @dev Owner can transfer the ownership of the contract to a new account (`_grantedOwner`).
     * Can only be called by the current owner.
     */
    function grantContractOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0));
        emit OwnershipGranted(newOwner);
        _grantedOwner = newOwner;
    }

    function getCollectionDetails()
        external
        view
        returns (CollectionDetails memory)
    {
        return collectionData[address(this)];
    }

    /**
     * @dev Claims granted ownership of the contract for a new account (`_grantedOwner`).
     * Can only be called by the currently granted owner.
     */
    function claimContractOwnership() public virtual {
        require(
            _grantedOwner == msg.sender,
            "Ownable: caller is not the granted owner"
        );
        emit OwnershipTransferred(owner, _grantedOwner);
        owner = _grantedOwner;
        _grantedOwner = address(0);
    }

    /**
     *@dev Current admin can transfer admin rights to a new account.
     */
    function grantAdminRights(address newAdmin) public virtual onlyAdmin {
        require(newAdmin != address(0));
        admin = newAdmin;
    }

    function fetchArtist(address _artist)
        public
        view
        returns (artistDetails memory)
    {
        require(_artist != address(0));
        require(
            creatorWhitelist[_artist] == true,
            "Given address is not artist"
        );
        return artistData[_artist];
    }

    /** @dev Calculate the royalty distribution for organisation/platform and the
     * creator/artist(who would be the seller) on the first sale.
     * The first iteration of whitepaper has the following stats:
     * orgFee = 5%
     * artist royalty/creator fee = 0%
     * The above numbers can be updated later by the DAO
     * @notice _creatorFeeInitial should be sellerFeeInitial - seller fees on first sale
     */
    function setRoyaltyPercentageFirstSale(
        uint256 _orgFeeInitial,
        uint256 _creatorFeeInitial
    ) public onlyOwner returns (bool) {
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
    function getRoyalties()
        public
        view
        returns (
            uint256 _orgFee,
            uint256 _creatorRoyalty,
            uint256 _orgInitialRoyalty,
            uint256 _sellerFeeInitial
        )
    {
        return (orgFee, totalCreatorFees, orgFeeInitial, sellerFeeInitial);
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

    function getTotalCreatorFees() public view returns (uint256) {
        return totalCreatorFees;
    }

    function getCreatorFees() public view returns (uint16[] memory) {
        return creatorFees;
    }

    function getNFTData(uint256 _tokenId) public view returns (NFTData memory) {
        return nftData[_tokenId];
    }

    /**
     * This function is used to mint an NFT for the Naksh marketplace.
     * @dev The basic information related to the NFT needs to be passeed to this function,
     * in order to store it on chain to avoid disputes in future.
     */
    function mintByArtistOrAdmin(
        address _creator,
        string memory _tokenURI,
        string memory title,
        string memory description,
        string memory artistName,
        string memory artistImg
    ) public returns (uint256 _tokenId) {
        minter mintedBy;
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        tokenOwner[tokenId] = _creator;

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"title": "',
                        title,
                        '", "description": "',
                        description,
                        '", "image": "',
                        _tokenURI,
                        '", "artist name": "',
                        artistName,
                        '"}'
                    )
                )
            )
        );

        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        _mint(_creator, tokenId);
        _setTokenURI(tokenId, finalTokenUri);

        if (msg.sender == admin) {
            mintedBy = minter.Admin;
        } else {
            mintedBy = minter.Artist;
        }

        NFTData memory nftNew = NFTData(
            address(this),
            tokenId,
            _tokenURI,
            title,
            description,
            artistData[_creator],
            mintedBy
        );
        nftData[tokenId] = nftNew;
        mintedNfts.push(nftNew);

        creatorTokens[_creator].push(tokenId);
        emit Mint(
            _creator,
            tokenId,
            _tokenURI,
            title,
            description,
            artistName,
            artistImg
        );
        return tokenId;
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
    function bulkMintByArtist(
        string[] memory _tokenURI,
        string[] memory title,
        string[] memory description,
        string memory artistName,
        string memory artistImg
    ) public returns (uint256[] memory _tokenId) {
        uint256[] memory tokenIds;

        uint256 length = title.length;

        for (uint256 i = 0; i < length; ) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            tokenOwner[tokenId] = msg.sender;

            string memory json = Base64.encode(
                bytes(
                    string(
                        abi.encodePacked(
                            '{"title": "',
                            title[i],
                            '", "description": "',
                            description[i],
                            '", "image": "',
                            _tokenURI[i],
                            '", "artist name": "',
                            artistName,
                            '"}'
                        )
                    )
                )
            );

            string memory finalTokenUri = string(
                abi.encodePacked("data:application/json;base64,", json)
            );

            _mint(msg.sender, tokenId);
            _setTokenURI(tokenId, finalTokenUri);

            NFTData memory nftNew = NFTData(
                address(this),
                tokenId,
                _tokenURI[i],
                title[i],
                description[i],
                artistData[msg.sender],
                minter.Artist
            );
            nftData[tokenId] = nftNew;
            mintedNfts.push(nftNew);

            creatorTokens[msg.sender].push(tokenId);

            emit Mint(
                msg.sender,
                tokenId,
                _tokenURI[i],
                title[i],
                description[i],
                artistName,
                artistImg
            );

            unchecked {
                ++i;
            }
        }
        return tokenIds;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title An NFT contract for Naksh ERC1155 NFTs
 * @notice This is the Naksh NFT contract for Minting ERC1155 NFTs .
 * @dev Most function calls are currently implemented with access control
 */

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./Structs.sol";

/*
 * This is the Naksh NFT contract for Minting ERC1155 NFTs.
 */
contract Naksh1155NFT is ERC1155 {
    mapping(address => bool) internal creatorWhitelist;
    mapping(address => uint256[]) public creatorTokens;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => NFTData) internal nftData;
    mapping(address => artistDetails) internal artistData;

    CollectionDetails internal collectionData;
    NFTData[] internal mintedNfts;

    event WhitelistCreator(address _creator);
    event DelistCreator(address _creator);
    event OwnershipGranted(address newOwner);
    event OwnershipTransferred(address oldOwner, address newOwner);
    event Mint(
        address creator,
        uint256 tokenId,
        uint256 amount,
        string tokenURI,
        string title,
        string description,
        string artistName,
        string artistImg,
        bool isVideo
    );

    uint256 constant FLOAT_HANDLER_TEN_4 = 10000;

    string public name;
    string public symbol;
    address public admin;
    uint256 public sellerFee;
    uint256 public orgFee = 500;
    uint16[] public creatorFees;
    uint256 public totalCreatorFees;
    address payable[] public creators;
    uint256 public TotalSplits;
    uint256 public sellerFeeInitial;
    uint256 public orgFeeInitial = 500;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    /**
     * Modifier to allow only admin or artist of the organization to perform certain actions
     */
    modifier onlyArtistOrAdmin() virtual {
        require(creatorWhitelist[msg.sender] == true || msg.sender == admin);
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
        address payable _admin,
        uint16[] memory _creatorFees,
        address payable[] memory _creators
    ) ERC1155("") {
        name = collection.name;
        symbol = collection.symbol;
        artistData[artist.artistAddress] = artist;
        creatorWhitelist[artist.artistAddress] = true;
        collectionData = collection;
        admin = _admin;
        //Multiply all the three % variables by 100, to kepe it uniform

        creatorFees = _creatorFees;
        creators = _creators;
        totalCreatorFees = TotalCreatorFees();
        sellerFee = 10000 - orgFee - totalCreatorFees;
        // Fees for first sale only

        sellerFeeInitial = 10000 - orgFeeInitial;
        TotalSplits = _creators.length;
    }

    function getCollectionDetails()
        external
        view
        returns (CollectionDetails memory)
    {
        return collectionData;
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

    function TotalCreatorFees() private returns (uint256) {
        uint256 _length = creators.length;
        for (uint8 i; i < _length; ) {
            totalCreatorFees += creatorFees[i];
            unchecked {
                ++i;
            }
        }
        return totalCreatorFees;
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
    ) public onlyAdmin returns (bool) {
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

    function uri(uint256 tokenId) public view override returns (string memory) {
        return (_tokenURIs[tokenId]);
    }

    function _setTokenURI(uint256 tokenId, string memory tokenURI) private {
        _tokenURIs[tokenId] = tokenURI;
    }

    function getNFTData(uint256 _tokenId) public view returns (NFTData memory) {
        return nftData[_tokenId];
    }

    function constructJSON(
        string memory title,
        string memory description,
        string memory _imgURI,
        uint256 _tokenId,
        string memory artistName,
        bool isVideo
    ) internal pure returns (string memory) {
        if (isVideo == false) {
            string memory json = Base64.encode(
                bytes(
                    string(
                        abi.encodePacked(
                            '{"title": "',
                            title,
                            '", "description": "',
                            description,
                            '", "image": "',
                            _imgURI,
                            '", "tokenId": "',
                            toString(_tokenId),
                            '", "artist_name": "',
                            artistName,
                            '"}'
                        )
                    )
                )
            );
            return json;
        } else {
            string memory json = Base64.encode(
                bytes(
                    string(
                        abi.encodePacked(
                            '{"title": "',
                            title,
                            '", "description": "',
                            description,
                            '", "image": "',
                            _imgURI,
                            '", "tokenId": "',
                            toString(_tokenId),
                            '", "artist_name": "',
                            artistName,
                            '", "animation_url": "',
                            _imgURI,
                            '"}'
                        )
                    )
                )
            );
            return json;
        }
    }

    /**
     * This function is used to mint an NFT for the Naksh marketplace.
     * @dev The basic information related to the NFT needs to be passeed to this function,
     * in order to store it on chain to avoid disputes in future.
     */
    function mintByArtistOrAdmin(
        address _creator,
        string memory _imgURI,
        uint256 _amount,
        string memory title,
        string memory description,
        string memory artistName,
        string memory artistImg,
        bool isVideo
    ) public onlyArtistOrAdmin {
        minter mintedBy;
        _tokenIds.increment();

        string memory json = constructJSON(
            title,
            description,
            _imgURI,
            _tokenIds.current(),
            artistName,
            isVideo
        );

        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        _mint(_creator, _tokenIds.current(), _amount, "");
        _setTokenURI(_tokenIds.current(), finalTokenUri);

        if (msg.sender == admin) {
            mintedBy = minter.Admin;
        } else {
            mintedBy = minter.Artist;
        }

        NFTData memory nftNew = NFTData(
            address(this),
            _tokenIds.current(),
            _amount,
            _imgURI,
            title,
            description,
            isVideo,
            artistData[_creator],
            mintedBy
        );
        nftData[_tokenIds.current()] = nftNew;
        mintedNfts.push(nftNew);

        creatorTokens[_creator].push(_tokenIds.current());
        emit Mint(
            _creator,
            _tokenIds.current(),
            _amount,
            _imgURI,
            title,
            description,
            artistName,
            artistImg,
            isVideo
        );
    }

    /**
     * This returns the total number of NFTs minted on the platform
     */
    function totalSupply() public view virtual returns (uint256) {
        return _tokenIds.current();
    }

    /**
     *This function is used to burn NFT, only Admin or Artist is allowed
     */
    function burn(
        address _from,
        uint256 _tokenId,
        uint256 _amount
    ) public onlyArtistOrAdmin {
        _burn(_from, _tokenId, _amount);
    }

    /**
     * This function is used to convert uint to string
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

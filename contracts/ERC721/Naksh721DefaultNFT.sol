// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title An NFT  contract for Naksh ERC721 NFTs
 * @notice This is the Naksh NFT contract for Minting ERC721 NFTs .
 * @dev Most function calls are currently implemented with access control
 */

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./Structs.sol";

/*
 * This is the Naksh NFT contract for Minting ERC721 NFTs.
 */
contract Naksh721DefaultNFT is ERC721URIStorage {
    mapping(address => uint256[]) public creatorTokens;
    mapping(uint256 => NFTData) internal nftData;
    mapping(address => artistDetails) internal artistData;

    NFTData[] internal mintedNfts;
    CollectionDetails internal collectionData;

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

    uint256 internal constant FLOAT_HANDLER_TEN_4 = 10000;

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
     * Modifier to allow only admin of the organization to perform certain actions
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only Admin allowed");
        _;
    }

    constructor(
        CollectionDetails memory collection,
        address payable _admin,
        uint16[] memory _creatorFees,
        address payable[] memory _creators
    ) ERC721(collection.name, collection.symbol) {
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
    function grantAdminRights(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0));
        admin = newAdmin;
    }

    function fetchArtist(address _artist)
        public
        view
        returns (artistDetails memory)
    {
        require(_artist != address(0));

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
        external
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
    function getSellerFee() external view returns (uint256) {
        //Returning % multiplied by 100 to keep it uniform across contract
        return sellerFee;
    }

    /**
     * @dev This function is used to get the creators percentage.
     * This refers to the amount of money that would be distributed to the creators
     * after the reduction of royalty and platform fees.
     * The values are multipleied by 100, in order to work easily
     * with floating point percentages.
     */
    function getTotalCreatorFees() external view returns (uint256) {
        return totalCreatorFees;
    }

    function getCreatorFees() external view returns (uint16[] memory) {
        return creatorFees;
    }

    /**
     * @dev This function is used to get the details of particular NFT by passing its tokenId.
     */
    function getNFTData(uint256 _tokenId)
        external
        view
        returns (NFTData memory)
    {
        return nftData[_tokenId];
    }

    /**
     * @dev This function is used to get the details of minted NFTs.
     */
    function getMintedNFTs() external view returns (NFTData[] memory) {
        return mintedNfts;
    }

    /**
     * This function is used to mint an NFT for the Naksh marketplace.
     * @dev The basic information related to the NFT needs to be passeed to this function,
     * in order to store it on chain to avoid disputes in future.
     */
    function mintByArtistOrAdmin(
        artistDetails memory artist,
        string memory _tokenURI,
        string memory title,
        string memory description,
        string memory artistName,
        string memory artistImg
    ) external {
        minter mintedBy;
        artistData[artist.artistAddress] = artist;
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

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
                        '", "tokenId": "',
                        toString(tokenId),
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

        _mint(artist.artistAddress, tokenId);
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
            artistData[artist.artistAddress],
            mintedBy
        );
        nftData[tokenId] = nftNew;
        mintedNfts.push(nftNew);

        creatorTokens[artist.artistAddress].push(tokenId);
        emit Mint(
            artist.artistAddress,
            tokenId,
            _tokenURI,
            title,
            description,
            artistName,
            artistImg
        );
    }

    /**
     * This returns the total number of NFTs minted on the platform
     */
    function totalSupply() external view virtual returns (uint256) {
        return _tokenIds.current();
    }

    /**
     *This function is used to burn NFT, only Admin or Artist is allowed
     */
    function burn(uint256 tokenId) external onlyAdmin {
        _burn(tokenId);
    }

    /**
     * This function is used to bulk mint NFTs for the Naksh marketplace.
     * @dev The basic information related to the NFT needs to be passeed to this function,
     * in order to store it on chain to avoid disputes in future.
     */
    function bulkMintByArtistorAdmin(
        artistDetails memory artist,
        string[] memory _tokenURI,
        string[] memory title,
        string[] memory description,
        string memory artistName,
        string memory artistImg
    ) external {
        minter mintedBy;

        for (uint256 i = 0; i < title.length; ) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();

            string memory json = Base64.encode(
                bytes(
                    string(
                        abi.encodePacked(
                            '{"title": "',
                            title[i],
                            '", "description": "',
                            description[i],
                            '", "tokenId": "',
                            tokenId,
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

            _mint(artist.artistAddress, tokenId);
            _setTokenURI(tokenId, finalTokenUri);
            if (msg.sender == admin) {
                mintedBy = minter.Admin;
            } else {
                mintedBy = minter.Artist;
            }

            NFTData memory nftNew = NFTData(
                address(this),
                tokenId,
                _tokenURI[i],
                title[i],
                description[i],
                artistData[artist.artistAddress],
                mintedBy
            );
            nftData[tokenId] = nftNew;
            mintedNfts.push(nftNew);

            creatorTokens[artist.artistAddress].push(tokenId);

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

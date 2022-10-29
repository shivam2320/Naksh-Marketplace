//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title An NFT Factory contract for Naksh NFTs
 * @notice This is the NFT Factory contract for deploying new NFT collections.
 */

import "./Naksh721NFT.sol";

contract NakshFactory {
    /**
     * Mapping to get deployed collection addresses by a artist
     */
    mapping(address => address[]) internal artistCollections;

    event CollectionCreated(
        address creator,
        string artistName,
        string artistImg,
        string collectionName,
        string symbol,
        address nftAddress
    );

    /**
     * This function is used to deploy new NFT collection.
     * @dev The basic information related to the NFT collection needs to be passed to this function,
     * in order to store it on chain to avoid disputes in future.
     * @param artist: Artist details including name, image and address
     * @param collection: Collection details including name, symbol, about etc.
     * @param _admin: address of admin
     * @param _creatorFees: Royalties for creators
     * @param _creators: Address of creators
     */
    function deployNftCollection(
        artistDetails memory artist,
        CollectionDetails memory collection,
        address payable _admin,
        uint16[] calldata _creatorFees,
        address payable[] calldata _creators
    ) external returns (address) {
        require(_creatorFees.length <= 6, "Maximum 6 creators allowed");

        uint256 _totalCreatorFees;
        uint256 _length = _creators.length;
        for (uint8 i; i < _length; ) {
            _totalCreatorFees += _creatorFees[i];
            unchecked {
                ++i;
            }
        }
        NakshNFT nft = new NakshNFT(
            artist,
            collection,
            msg.sender,
            _admin,
            _creatorFees,
            _creators,
            _totalCreatorFees
        );

        artistCollections[msg.sender].push(address(nft));

        emit CollectionCreated(
            msg.sender,
            artist.name,
            artist.imageUrl,
            collection.name,
            collection.symbol,
            address(nft)
        );
        return address(nft);
    }

    /**
     * @dev This function returns addresses of collections deployed by a particular artist
     */
    function getArtistCollections(address _artist)
        external
        view
        returns (address[] memory)
    {
        return artistCollections[_artist];
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./NakshNFT.sol";

contract NakshFactory {
    mapping(address => address[]) public artistCollections;

    event CollectionCreated(
        address creator,
        string name,
        string symbol,
        address nftAddress
    );

    function deployNftCollection(
        artistDetails memory artist,
        CollectionDetails memory collection,
        address payable _admin,
        uint16 _creatorFee,
        address payable[] memory _creators
    ) public returns (address) {
        NakshNFT nft = new NakshNFT(
            artist,
            collection,
            msg.sender,
            _admin,
            _creatorFee,
            _creators
        );

        artistCollections[msg.sender].push(address(nft));

        emit CollectionCreated(
            msg.sender,
            collection.name,
            collection.symbol,
            address(nft)
        );
        return address(nft);
    }

    function getArtistCollections(address _artist)
        public
        view
        returns (address[] memory)
    {
        return artistCollections[_artist];
    }
}

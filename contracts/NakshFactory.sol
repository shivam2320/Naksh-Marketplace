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
        uint16[] memory _creatorFees,
        address payable[] memory _creators
    ) public returns (address) {
        require(_creatorFees.length <= 6, "Maximum 6 allowed");

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

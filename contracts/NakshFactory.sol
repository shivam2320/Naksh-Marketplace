//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./NakshNFT.sol";

contract NakshFactory {

    mapping (address => address[]) public artist;

    event CollectionCreated(string indexed name, string indexed symbol, string about, string logo, string uri, bool isGradient, string instagram, string facebook, string twitter, string website, address indexed nftAddress);
    
    function deployNftCollection(
        CollectionDetails memory collection,
        address payable _admin,
        uint16 _creatorFee,
        address payable[] memory  _creators)
        public returns (address) {
            NakshNFT nft = new NakshNFT(collection, msg.sender, _admin, _creatorFee, _creators);

            artist[msg.sender].push(address(nft));

            emit CollectionCreated(collection.name, collection.symbol, collection.about, collection.logo, collection.cover.uri, collection.cover.isGradient, collection.social.instagram, collection.social.facebook, collection.social.twitter, collection.social.website, address(nft));
            return address(nft);
    }

    function getArtistCollections(address _orgniser) public view returns (address[] memory) {
        return artist[_orgniser];
    }

}
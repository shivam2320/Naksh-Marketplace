//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./NakshNFT.sol";

contract NakshFactory {

    mapping (address => address[]) public artist;

    event CollectionCreated(string indexed name, string indexed symbol, address indexed nftAddress);
    
    function deployNftCollection(
        string memory _name,
        string memory _symbol,
        address payable _admin,
        uint16 _creatorFee,
        address payable[] memory  _creators)
         public returns (address) {
            NakshNFT nft = new NakshNFT(_name, _symbol, msg.sender, _admin, _creatorFee, _creators);

            artist[msg.sender].push(address(nft));

            emit CollectionCreated(_name, _symbol, address(nft));
            return address(nft);
    }

    function getArtistCollections(address _orgniser) public view returns (address[] memory) {
        return artist[_orgniser];
    }

}
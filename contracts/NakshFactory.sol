//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./NakshNFT.sol";

contract NakshFactory {

    using Counters for Counters.Counter;
    Counters.Counter private _organiserId;

    mapping (address => address[]) public organiser;

    event CollectionCreated(string indexed name, string indexed symbol, address indexed nftAddress);
    
    function deployNftCollection(
        string memory _name,
        string memory _symbol,
        address payable _org,
        address payable _admin,
        uint16 _creatorFee,
        address payable[] memory  _creators)
         public returns (address) {
            NakshNFT nft = new NakshNFT(_name, _symbol, _org, _admin, _creatorFee, _creators);

            organiser[msg.sender].push(address(nft));

            emit CollectionCreated(_name, _symbol, address(nft));
            return address(nft);
    }

    function getOrganiserCollections(address _orgniser) public view returns (address[] memory) {
        return organiser[_orgniser];
    }

}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NakshNFT.sol";
import "./NakshMarketplace.sol";

contract NakshAuction {

    uint constant FLOAT_HANDLER_TEN_4 = 10000;

    struct NFTAuction {
        uint startTime;
        uint endTime;
        uint tokenId;
        address owner;
        uint price;
        uint highestBid;
        address highestBidder;
    }

    NFTAuction[] auctionedNFTs;

    struct bidHistory {
        address bidder;
        uint amount;
        uint timestamp;
    }

    bidHistory[] previousBids;

    mapping(uint => NFTAuction) public auctionData;
    mapping(uint => bidHistory[]) public prevBidData;
    mapping(address => uint) public bids;

    event StartedAuction(uint startTime, uint endTime, uint indexed tokenId, address indexed owner, uint indexed price);
    event EndedAuction(uint indexed _tokenId, address indexed _buyer, uint indexed highestBID);
    event Bidding(uint indexed _tokenId, address indexed _bidder, uint indexed _amount);

    modifier onlyOwnerOf(address _nftAddress, uint256 _tokenId) {
        require(IERC721(_nftAddress).ownerOf(_tokenId) == msg.sender);
        _;
    }

        function startAuction(address _nftAddress, uint _tokenId, uint _price, uint _auctionTime) external onlyOwnerOf(_nftAddress, _tokenId) returns (bool) {
        uint _startTime = block.timestamp;

        IERC721(_nftAddress).transferFrom(msg.sender, address(this), _tokenId);

        uint _endTime = block.timestamp + _auctionTime;

        NFTAuction memory nftAuction = NFTAuction(_startTime, _endTime, _tokenId, msg.sender, _price, 0, address(0));
        auctionData[_tokenId] = nftAuction;
        auctionedNFTs.push(nftAuction);

        emit StartedAuction(_startTime, _endTime, _tokenId, msg.sender, _price);

        return true;
    }

    function bid(uint _tokenId) external payable returns (bool) {

        require(auctionData[_tokenId].endTime >= block.timestamp, "Auction has ended");
        require(auctionData[_tokenId].price <= msg.value, "Pay more than base price");
        require(auctionData[_tokenId].highestBid <= msg.value, "Pay more than highest bid");

        if(auctionData[_tokenId].highestBidder != address(0)) {
            bidHistory memory addBid = bidHistory( msg.sender, msg.value, block.timestamp);
            prevBidData[_tokenId].push(addBid);
            uint bal = bids[auctionData[_tokenId].highestBidder];
            bids[auctionData[_tokenId].highestBidder] = 0;
            payable(auctionData[_tokenId].highestBidder).transfer(bal);
            auctionData[_tokenId].highestBid = msg.value;
            bids[msg.sender] = auctionData[_tokenId].highestBid;
            auctionData[_tokenId].highestBidder = msg.sender;
            
        } else {
        auctionData[_tokenId].highestBidder = msg.sender;
        auctionData[_tokenId].highestBid = msg.value;
        bidHistory memory addBid = bidHistory(msg.sender, msg.value, block.timestamp);
        prevBidData[_tokenId].push(addBid);
        }
        
        emit Bidding(_tokenId, msg.sender, msg.value);
        return true;
    }

    function getBidHistory(uint _tokenId) external view returns (bidHistory[] memory) {
        return prevBidData[_tokenId];
    }


    function endAuction(uint _tokenId, address _nftAddress) external{
        NFTAuction memory nftAuction = auctionData[_tokenId];

        require(nftAuction.owner == msg.sender, "Only owner of nft can call this");
        require(nftAuction.endTime <= block.timestamp, "Auction has not yet ended");

        if (nftAuction.highestBidder != address(0)) {

            payable(msg.sender).transfer(nftAuction.highestBid);

            IERC721(_nftAddress).safeTransferFrom(address(this), nftAuction.highestBidder, _tokenId);
            
        } else {
            IERC721(_nftAddress).safeTransferFrom(address(this), msg.sender, _tokenId);
        }

        emit EndedAuction(_tokenId, nftAuction.highestBidder, nftAuction.highestBid);

    }
}
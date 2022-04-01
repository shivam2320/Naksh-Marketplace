//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract NFTBidding {
    
    using Counters for Counters.Counter;
    Counters.Counter private _bids;
        
    enum NFTState {
	    ONBID,
	    FREE
	}
  
  mapping(uint256 => NFTState) tokenState;
  mapping(uint256 => address) tokenBids;
  
  event nftOnBid(address, uint256, address);
  event bidLog(address, uint256, uint256, address);
  
  function putOnBid(address nftAddress, uint256 tokenId) public returns(bool){
      ERC721 nftContract = ERC721(nftAddress);
      require(msg.sender == nftContract.ownerOf(tokenId), "Only the owner of the NFT can call the put on bid function"); 
      
      Bidding bidding = new Bidding(tokenId, block.timestamp, nftAddress,msg.sender);
      tokenBids[tokenId] = address(bidding);
      tokenState[tokenId] = NFTState.ONBID;
      
      nftContract.transferFrom(nftContract.ownerOf(tokenId), address(this), tokenId);
      
      emit nftOnBid(nftAddress, tokenId, msg.sender);
      
      return true;
  } 
  
  function closeBidding(uint256 _tokenId) public returns(bool){
       tokenState[_tokenId] = NFTState.FREE;
       return true;
  }
  
  function getBiddingContractAddress(uint256 _tokenId) public view returns(address)  {
      return tokenBids[_tokenId];
  }
  
  function getNFTState(uint256 _tokenId) public view returns(NFTState){
      return tokenState[_tokenId];
  }
  
}


/* 
* This is the bidding contract 
*/

contract Bidding {
    // Parameters of the auction. Times are either
    // absolute unix timestamps (seconds since 1970-01-01)
    // or time periods in seconds.

    uint public auctionEnd;
    uint public tokenId;
    address public parentNftAddress;
    uint public tokenURI;
    uint bidCounter;
    address public selectedBidder;
    address public owner;

    struct Bid {
        address bidder;
        address nftAddress;
        uint tokenId;
        string  tokenURI;
        uint rewardPoints;
        string expiry;
    }
   
    // Set to true at the end, disallows any change
    bool ended;
    
    // Recording all the bids
    mapping(uint => Bid) bids;

     event bidLog(address, uint256, uint256, address);
    // Events that  will be fired on changes.
    event AuctionEnded(address winner, address nftAddress);

    /*
    * Create a simple bidding contract
    * @param _tokenId: tokenId for which the bid is created
    * @param _biddingTime: Time period for the bidding to be kept open
    */
    constructor(
       
        uint256 _tokenId,
        uint _biddingTime,
        address _nftAddress,
        address _owner
    ) {

        tokenId = _tokenId;
        bidCounter = 0;
        auctionEnd = block.timestamp + _biddingTime;
        //Explicitly setting the owner to our address for now
        // msg.sender is coming as the address of the contract
        parentNftAddress = _nftAddress;
        owner = _owner;
        
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    //ONLY FOR TESTING
    function getOwner() public view returns(address){
      return owner;
    }


    function bid(address _nftAddress, uint256 _tokenId, string memory _tokenURI, uint256 _rewardPoints, string memory _expiryDate) public {
        
        require(
            block.timestamp <= auctionEnd,
            "Auction already ended."
        );

   
       Bid storage newBid = bids[bidCounter+1];
       newBid.bidder = msg.sender;
       newBid.nftAddress = _nftAddress;
       newBid.tokenId = _tokenId;
       newBid.tokenURI = _tokenURI;
       newBid.rewardPoints = _rewardPoints;
       newBid.expiry = _expiryDate;
       
       ERC721 nftContract = ERC721(_nftAddress);
       address nftOwner = nftContract.ownerOf(_tokenId);
       nftContract.transferFrom(nftOwner, address(this), _tokenId);
       
       emit bidLog(newBid.nftAddress, newBid.tokenId , block.timestamp, msg.sender);
       
       bidCounter = bidCounter+1;
    }
    
    /*
    * Get the address of the highest bidder
    */
    function selectBidderAndClose(address nftAddress) onlyOwner public returns(bool) {

        selectedBidder = nftAddress;
        
        for(uint i = 0; i < bidCounter; i ++ ){
            
             if(bids[i].nftAddress !=  selectedBidder){
                  ERC721 nftContract = ERC721(bids[i].nftAddress);
                  address nftOwner = nftContract.ownerOf(bids[i].tokenId);
                  nftContract.transferFrom(nftOwner, bids[i].bidder, bids[i].tokenId);
             }
             else if(bids[i].nftAddress ==  selectedBidder){
                 ERC721 selectedNftContract = ERC721(bids[i].nftAddress);
                 ERC721 parentContract = ERC721(parentNftAddress);
                 address selectedOwner = selectedNftContract.ownerOf(bids[i].tokenId);
                 address bidOwner = parentContract.ownerOf(tokenId);
                 selectedNftContract.transferFrom(selectedOwner, bidOwner, bids[i].tokenId);
                 parentContract.transferFrom(bidOwner, selectedOwner, tokenId);
             }
            
        }
        
        return true;
        
    }
    
    //  function transferNFT(address nftAddress, uint256 _tokenId) public {
    //   ERC721 nftContract = ERC721(nftAddress);
    //   address nftOwner = nftContract.ownerOf(_tokenId);
    //   nftContract.transferFrom(nftOwner, address(this), _tokenId);
    // }
  
    // function transferNFTBack(address nftAddress, uint256 _tokenId, address to) public {
    //   ERC721 nftContract = ERC721(nftAddress);
    //   address nftOwner = nftContract.ownerOf(_tokenId);
    //   nftContract.transferFrom(nftOwner, to, _tokenId);
    // }
    
    
}
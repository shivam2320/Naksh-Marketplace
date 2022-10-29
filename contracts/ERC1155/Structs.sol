// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

enum minter {
    Admin,
    Artist
}

struct SocialMediaData {
    string instagram;
    string facebook;
    string twitter;
    string website;
}

struct CoverImage {
    string uri;
    bool isGradient;
}

struct CollectionDetails {
    string name;
    string symbol;
    string about;
    string logo;
    CoverImage cover;
    SocialMediaData social;
}

struct NFTData {
    address nftAddress;
    uint256 tokenId;
    uint256 amount;
    string tokenUri;
    string title;
    string description;
    artistDetails artist;
    minter mintedBy;
}

struct artistDetails {
    string name;
    address artistAddress;
    string imageUrl;
}

enum saleType {
    DirectSale,
    Auction
}

struct SaleData {
    NFTData nft;
    address _owner;
    bool isOnSale;
    uint256 onSaleAmount;
    bool tokenFirstSale;
    uint256 salePrice;
    saleType saletype;
}

struct NFTAuction {
    uint256 startTime;
    uint256 endTime;
    uint256 tokenId;
    uint256 _amount;
    address owner;
    uint256 price;
    uint256 highestBid;
    address highestBidder;
}

struct bidHistory {
    address bidder;
    uint256 amount;
    uint256 timestamp;
}

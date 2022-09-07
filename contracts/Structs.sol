// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

    enum minter{
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
        uint tokenId;
        string tokenUri;
        string title;
        string description;
        string artistName;
        string artistImg;
        address creator;
        minter mintedBy;
    }

    enum saleType {
        DirectSale,
        Auction
    }

    struct SaleData {
        NFTData nft;
        bool isOnSale;
        bool tokenFirstSale;
        uint salePrice;
        saleType saletype;
    }

    struct NFTAuction {
        uint startTime;
        uint endTime;
        uint tokenId;
        address owner;
        uint price;
        uint highestBid;
        address highestBidder;
    }

    struct bidHistory {
        address bidder;
        uint amount;
        uint timestamp;
    }


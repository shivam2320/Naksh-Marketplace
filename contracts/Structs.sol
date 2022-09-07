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


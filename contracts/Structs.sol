// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

enum minter{
        Admin,
        Artist
    }

    struct NFTData {
        uint tokenId;
        string tokenUri;
        string title;
        string description;
        string artistName;
        string artistImg;
        address creator;
        minter mintedBy;
    }
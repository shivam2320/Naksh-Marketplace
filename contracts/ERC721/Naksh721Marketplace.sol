//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Naksh721NFT.sol";
import "hardhat/console.sol";
import "./Structs.sol";

contract Naksh721Marketplace is Ownable, ERC721Holder, ReentrancyGuard {
    address payable public Naksh_org;

    SaleData[] internal OnSaleNFTs;

    uint256 internal constant FLOAT_HANDLER_TEN_4 = 10000;

    mapping(address => mapping(uint256 => SaleData)) internal saleData;

    event SalePriceSet(
        address _nft,
        uint256 _tokenId,
        uint256 _price,
        uint256 currentTimestamp,
        bool tokenFirstSale,
        saleType saletype
    );
    event Sold(
        address _nft,
        address _buyer,
        address _seller,
        uint256 _amount,
        uint256 _tokenId,
        uint256 timestamp
    );
    event StartedAuction(
        address _nft,
        uint256 currentTimestamp,
        uint256 startTime,
        uint256 endTime,
        uint256 tokenId,
        address owner,
        uint256 price
    );
    event EndedAuction(
        address _nft,
        uint256 _tokenId,
        address _buyer,
        uint256 highestBID,
        uint256 timestamp
    );
    event Bidding(
        address _nft,
        uint256 _tokenId,
        address _bidder,
        uint256 _amount,
        uint256 timestamp
    );

    /**
     * Modifier to allow only owner of a particular token to perform certain actions
     */
    modifier onlyOwnerOf(address _nftAddress, uint256 _tokenId) {
        require(IERC721(_nftAddress).ownerOf(_tokenId) == msg.sender);
        _;
    }

    /**
     * @dev Organisation address can be updated to another address in case of attack or compromise(`newOrg`)
     * Can be done only by the contract owner.
     */
    function changeOrgAddress(address _newOrg) public onlyOwner {
        require(
            _newOrg != address(0),
            "New organization cannot be zero address"
        );
        Naksh_org = payable(_newOrg);
    }

    /**
     * This function is used to set an ERC721 NFT on sale.
     * @dev The sale price set in this function will be used to perform the sale transaction
     * once the buyer wants to buy an NFT.
     */
    function setSale(
        address _nft,
        uint256 _tokenId,
        uint256 price
    ) public onlyOwnerOf(_nft, _tokenId) {
        require(
            saleData[_nft][_tokenId].isOnSale == false,
            "NFT is already on sale"
        );
        address tOwner = IERC721(_nft).ownerOf(_tokenId);
        require(tOwner != address(0), "setSale: nonexistent token");

        IERC721(_nft).safeTransferFrom(msg.sender, address(this), _tokenId);
        saleData[_nft][_tokenId].nft = Naksh721NFT(_nft).getNFTData(_tokenId);
        saleData[_nft][_tokenId].isOnSale = true;
        saleData[_nft][_tokenId].owner = msg.sender;
        saleData[_nft][_tokenId].salePrice = price;
        saleData[_nft][_tokenId].saletype = saleType.DirectSale;
        OnSaleNFTs.push(saleData[_nft][_tokenId]);
        emit SalePriceSet(
            _nft,
            _tokenId,
            price,
            block.timestamp,
            saleData[_nft][_tokenId].tokenFirstSale,
            saleData[_nft][_tokenId].saletype
        );
    }

    function getNFTonSale() public view returns (SaleData[] memory) {
        return OnSaleNFTs;
    }

    function updateSaleData(address _nftAddress, uint256 _tokenId) internal {
        uint256 leng = OnSaleNFTs.length;
        saleData[_nftAddress][_tokenId].isOnSale = false;
        SaleData memory _saleData;
        _saleData = saleData[_nftAddress][_tokenId];

        for (uint256 i = 0; i < leng; ) {
            if (
                OnSaleNFTs[i].nft.nftAddress == _nftAddress &&
                OnSaleNFTs[i].nft.tokenId == _tokenId
            ) {
                _saleData = OnSaleNFTs[i];
                OnSaleNFTs[i] = OnSaleNFTs[leng - 1];
                OnSaleNFTs[leng - 1] = _saleData;
            }
            OnSaleNFTs.pop();
            unchecked {
                ++i;
            }
        }
    }

    function cancelSale(address _nft, uint256 _tokenId) public {
        require(
            saleData[_nft][_tokenId].owner == msg.sender,
            "Only NFT Owner allowed"
        );
        require(
            saleData[_nft][_tokenId].isOnSale == true,
            "NFT is not on sale"
        );

        IERC721(_nft).safeTransferFrom(address(this), msg.sender, _tokenId);

        updateSaleData(_nft, _tokenId);
    }

    function getSaleData(address _nft, uint256 _tokenId)
        external
        view
        returns (SaleData memory)
    {
        require(
            saleData[_nft][_tokenId].isOnSale == true,
            "NFT is not on sale"
        );
        console.log(_nft);
        console.log(_tokenId);
        return saleData[_nft][_tokenId];
    }

    /**
     * This function is used to buy an NFT which is on sale.
     */
    function buyTokenOnSale(uint256 _tokenId, address _nftAddress)
        public
        payable
        nonReentrant
    {
        require(
            saleData[_nftAddress][_tokenId].isOnSale == true,
            "NFT is not on sale"
        );
        Naksh721NFT _nft = Naksh721NFT(_nftAddress);
        uint256 price = saleData[_nftAddress][_tokenId].salePrice;
        uint256 sellerFees = _nft.getSellerFee();
        uint16[] memory creatorRoyalty = _nft.getCreatorFees();
        uint256 totalCreatorFees = _nft.getTotalCreatorFees();
        uint256 platformFees = _nft.orgFee();

        require(price != 0, "buyToken: price equals 0");
        require(msg.value >= price, "buyToken: price doesn't equal salePrice");
        address tOwner = saleData[_nftAddress][_tokenId]
            .nft
            .artist
            .artistAddress;

        IERC721(_nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );

        if (saleData[_nftAddress][_tokenId].tokenFirstSale == false) {
            platformFees = _nft.orgFeeInitial();
            sellerFees = _nft.sellerFeeInitial();
            // No creator royalty/royalties when artist is minting for the first time
            totalCreatorFees = 0;

            saleData[_nftAddress][_tokenId].tokenFirstSale = true;
        } else {
            totalCreatorFees = _nft.getTotalCreatorFees();
        }

        //Dividing by 100*100 as all values are multiplied by 100
        uint256 toSeller = (msg.value * sellerFees) / FLOAT_HANDLER_TEN_4;

        uint256 toPlatform = (msg.value * platformFees) / FLOAT_HANDLER_TEN_4;

        payable(tOwner).transfer(toSeller);

        if (totalCreatorFees != 0) {
            splitCreatorRoyalty(address(_nft), creatorRoyalty);
        }

        Naksh_org.transfer(toPlatform);

        updateSaleData(_nftAddress, _tokenId);

        emit Sold(
            _nftAddress,
            msg.sender,
            tOwner,
            msg.value,
            _tokenId,
            block.timestamp
        );
    }

    function splitCreatorRoyalty(
        address _nftAddress,
        uint16[] memory creatorRoyalty
    ) internal {
        Naksh721NFT _nft = Naksh721NFT(_nftAddress);
        uint256 _TotalSplits = _nft.TotalSplits();
        uint256[] memory toCreators;
        for (uint8 i = 0; i < _TotalSplits; ) {
            toCreators[i] =
                (msg.value * creatorRoyalty[i]) /
                FLOAT_HANDLER_TEN_4;
            payable(_nft.creators(i)).transfer(toCreators[i]);
        }
    }

    /**
     * This is a getter function to get the current price of an NFT.
     */
    function getSalePrice(address _nft, uint256 _tokenId)
        public
        view
        returns (uint256)
    {
        require(
            saleData[_nft][_tokenId].isOnSale == true,
            "NFT is not on Sale"
        );
        return saleData[_nft][_tokenId].salePrice;
    }

    /**
     * This function is used to change the price of a token
     * @notice Only token owner is allowed to change the price of a token
     */
    function changePrice(
        address _nft,
        uint256 _tokenId,
        uint256 price
    ) public {
        require(
            saleData[_nft][_tokenId].owner == msg.sender,
            "Only NFT Owner allowed"
        );
        require(
            saleData[_nft][_tokenId].isOnSale == true,
            "NFT is not on sale"
        );
        require(
            price > 0,
            "changePrice: Price cannot be changed to less than 0"
        );
        saleData[_nft][_tokenId].salePrice = price;
    }

    /**
     * This function is used to check if it is the first sale of a token
     * on the Naksh marketplace.
     */
    function isTokenFirstSale(address _nftAddress, uint256 _tokenId)
        public
        view
        returns (bool)
    {
        return saleData[_nftAddress][_tokenId].tokenFirstSale;
    }

    NFTAuction[] auctionedNFTs;

    bidHistory[] previousBids;

    mapping(address => mapping(uint256 => NFTAuction)) public auctionData;

    mapping(address => mapping(uint256 => bidHistory[])) public prevBidData;
    mapping(address => uint256) internal bids;

    function startAuction(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _auctionTime
    ) external onlyOwnerOf(_nftAddress, _tokenId) returns (bool) {
        require(
            saleData[_nftAddress][_tokenId].isOnSale == false,
            "NFT is already on sale"
        );
        uint256 _startTime = block.timestamp;

        IERC721(_nftAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        uint256 _endTime = block.timestamp + _auctionTime;

        NFTAuction memory nftAuction = NFTAuction(
            _startTime,
            _endTime,
            _tokenId,
            msg.sender,
            _price,
            0,
            address(0)
        );
        auctionData[_nftAddress][_tokenId] = nftAuction;
        auctionedNFTs.push(nftAuction);

        saleData[_nftAddress][_tokenId].nft = Naksh721NFT(_nftAddress)
            .getNFTData(_tokenId);
        saleData[_nftAddress][_tokenId].isOnSale = true;
        saleData[_nftAddress][_tokenId].salePrice = _price;
        saleData[_nftAddress][_tokenId].saletype = saleType.Auction;
        OnSaleNFTs.push(saleData[_nftAddress][_tokenId]);

        emit StartedAuction(
            _nftAddress,
            block.timestamp,
            _startTime,
            _endTime,
            _tokenId,
            msg.sender,
            _price
        );

        return true;
    }

    function bid(address _nftAddress, uint256 _tokenId)
        external
        payable
        returns (bool)
    {
        NFTAuction storage nftAuction = auctionData[_nftAddress][_tokenId];

        require(nftAuction.endTime >= block.timestamp, "Auction has ended");
        require(nftAuction.price <= msg.value, "Pay more than base price");
        require(
            nftAuction.highestBid <= msg.value,
            "Pay more than highest bid"
        );

        if (nftAuction.highestBidder == address(0)) {
            nftAuction.highestBidder = msg.sender;
            nftAuction.highestBid = msg.value;
            bidHistory memory addBid = bidHistory(
                msg.sender,
                msg.value,
                block.timestamp
            );
            prevBidData[_nftAddress][_tokenId].push(addBid);
        } else {
            payable(nftAuction.highestBidder).transfer(nftAuction.highestBid);
            nftAuction.highestBid = msg.value;
            nftAuction.highestBidder = msg.sender;
            bidHistory memory addBid = bidHistory(
                msg.sender,
                msg.value,
                block.timestamp
            );
            prevBidData[_nftAddress][_tokenId].push(addBid);
        }

        emit Bidding(
            _nftAddress,
            _tokenId,
            msg.sender,
            msg.value,
            block.timestamp
        );
        return true;
    }

    function getBidHistory(address _nftAddress, uint256 _tokenId)
        external
        view
        returns (bidHistory[] memory)
    {
        return prevBidData[_nftAddress][_tokenId];
    }

    function endAuction(address _nftAddress, uint256 _tokenId) external {
        NFTAuction storage nftAuction = auctionData[_nftAddress][_tokenId];

        require(
            nftAuction.owner == msg.sender ||
                nftAuction.highestBidder == msg.sender,
            "Only owner of nft can call this"
        );

        require(
            nftAuction.owner == msg.sender ||
                nftAuction.endTime <= block.timestamp,
            "Auction has not yet ended"
        );

        if (nftAuction.highestBidder != address(0)) {
            payable(msg.sender).transfer(nftAuction.highestBid);

            IERC721(_nftAddress).safeTransferFrom(
                address(this),
                nftAuction.highestBidder,
                _tokenId
            );
        } else {
            IERC721(_nftAddress).safeTransferFrom(
                address(this),
                msg.sender,
                _tokenId
            );
        }

        updateSaleData(_nftAddress, _tokenId);

        emit EndedAuction(
            _nftAddress,
            _tokenId,
            nftAuction.highestBidder,
            nftAuction.highestBid,
            block.timestamp
        );
    }
}

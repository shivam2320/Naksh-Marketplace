//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NakshNFT.sol";
import "./Structs.sol";

contract NakshMarketplace is Ownable, ERC721Holder {
    address payable public Naksh_org;

    SaleData[] internal OnSaleNFTs;

    uint256 constant FLOAT_HANDLER_TEN_4 = 10000;

    mapping(address => mapping(uint256 => SaleData)) public saleData;

    event SalePriceSet(address _nft, uint256 _tokenId, uint256 _price);
    event Sold(
        address _nft,
        address _buyer,
        address _seller,
        uint256 _amount,
        uint256 _tokenId
    );
    event StartedAuction(
        address _nft,
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
        uint256 highestBID
    );
    event Bidding(
        address _nft,
        uint256 _tokenId,
        address _bidder,
        uint256 _amount
    );

    /**
     * Modifier to allow only owners of a token to perform certain actions
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

    // function MintAndSetSaleByAdmin(address _nft, address _creator, string memory _tokenURI, string memory title,
    // string memory description, string memory artistName, uint256 price) public {
    //     NakshNFT(_nft).mintByAdmin(_creator, _tokenURI, title, description, artistName);

    // }

    /**
     * This function is used to set an NFT on sale.
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
        saleData[_nft][_tokenId].nft = NakshNFT(_nft).getNFTData(_tokenId);
        saleData[_nft][_tokenId].isOnSale = true;
        saleData[_nft][_tokenId].salePrice = price;
        saleData[_nft][_tokenId].saletype = saleType.DirectSale;
        OnSaleNFTs.push(saleData[_nft][_tokenId]);
        emit SalePriceSet(_nft, _tokenId, price);
    }

    function getNFTonSale() public view returns (SaleData[] memory) {
        return OnSaleNFTs;
    }

    function updateSaleData(address _nftAddress, uint256 _tokenId) internal {
        uint256 leng = OnSaleNFTs.length;
        for (uint256 i = 0; i <= leng; ) {
            if (
                OnSaleNFTs[i].nft.nftAddress == _nftAddress &&
                OnSaleNFTs[i].nft.tokenId == _tokenId
            ) {
                delete OnSaleNFTs[i];
            }
            unchecked {
                ++i;
            }
        }
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
        return saleData[_nft][_tokenId];
    }

    function cancelSale(address _nft, uint256 _tokenId)
        public
        onlyOwnerOf(_nft, _tokenId)
    {
        require(
            saleData[_nft][_tokenId].isOnSale == true,
            "NFT is not on sale"
        );
        IERC721(_nft).safeTransferFrom(address(this), msg.sender, _tokenId);
        delete saleData[_nft][_tokenId];
        updateSaleData(_nft, _tokenId);
    }

    /**
     * This function is used to buy an NFT which is on sale.
     */
    function buyTokenOnSale(uint256 _tokenId, address _nftAddress)
        public
        payable
    {
        NakshNFT _nft = NakshNFT(_nftAddress);
        uint256 price = saleData[_nftAddress][_tokenId].salePrice;
        uint256 sellerFees = _nft.getSellerFee();
        uint256 creatorRoyalty = _nft.creatorFee();
        uint256 platformFees = _nft.orgFee();

        require(price != 0, "buyToken: price equals 0");
        require(
            msg.value >= price,
            "buyToken: price doesn't equal salePrice[tokenId]"
        );
        address tOwner = IERC721(_nftAddress).ownerOf(_tokenId);

        IERC721(_nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );
        delete saleData[_nftAddress][_tokenId];
        updateSaleData(_nftAddress, _tokenId);

        if (saleData[_nftAddress][_tokenId].tokenFirstSale == false) {
            /* Platform takes 5% on each artist's first sale
             *  All values are multiplied by 100 to deal with floating points
             */
            platformFees = _nft.orgFeeInitial();
            sellerFees = _nft.sellerFeeInitial();
            // No creator royalty/royalties when artist is minting for the first time
            creatorRoyalty = 0;

            saleData[_nftAddress][_tokenId].tokenFirstSale = true;
        }

        //Dividing by 100*100 as all values are multiplied by 100
        uint256 toSeller = (msg.value * sellerFees) / FLOAT_HANDLER_TEN_4;

        //Dividing by 100*100 as all values are multiplied by 100
        uint256 toCreator = (msg.value * creatorRoyalty) / FLOAT_HANDLER_TEN_4;
        uint256 toPlatform = (msg.value * platformFees) / FLOAT_HANDLER_TEN_4;

        // address tokenCreatorAddress = tokenCreator[_tokenId];

        payable(tOwner).transfer(toSeller);

        if (toCreator != 0) {
            uint256 _TotalSplits = _nft.TotalSplits();
            uint256 toCreators = toCreator / _TotalSplits;
            for (uint8 i = 0; i < _TotalSplits; ) {
                payable(_nft.creators(i)).transfer(toCreators);
            }
        }

        Naksh_org.transfer(toPlatform);

        emit Sold(_nftAddress, msg.sender, tOwner, msg.value, _tokenId);
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
    ) public onlyOwnerOf(_nft, _tokenId) {
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
    mapping(address => uint256) public bids;

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

        saleData[_nftAddress][_tokenId].nft = NakshNFT(_nftAddress).getNFTData(
            _tokenId
        );
        saleData[_nftAddress][_tokenId].isOnSale = true;
        saleData[_nftAddress][_tokenId].salePrice = _price;
        saleData[_nftAddress][_tokenId].saletype = saleType.Auction;
        OnSaleNFTs.push(saleData[_nftAddress][_tokenId]);

        emit StartedAuction(
            _nftAddress,
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
        NFTAuction memory nftAuction = auctionData[_nftAddress][_tokenId];

        require(nftAuction.endTime >= block.timestamp, "Auction has ended");
        require(nftAuction.price <= msg.value, "Pay more than base price");
        require(
            nftAuction.highestBid <= msg.value,
            "Pay more than highest bid"
        );

        if (nftAuction.highestBidder != address(0)) {
            bidHistory memory addBid = bidHistory(
                msg.sender,
                msg.value,
                block.timestamp
            );
            prevBidData[_nftAddress][_tokenId].push(addBid);
            uint256 bal = bids[nftAuction.highestBidder];
            bids[nftAuction.highestBidder] = 0;
            payable(nftAuction.highestBidder).transfer(bal);
            nftAuction.highestBid = msg.value;
            bids[msg.sender] = nftAuction.highestBid;
            nftAuction.highestBidder = msg.sender;
        } else {
            nftAuction.highestBidder = msg.sender;
            nftAuction.highestBid = msg.value;
            bidHistory memory addBid = bidHistory(
                msg.sender,
                msg.value,
                block.timestamp
            );
            prevBidData[_nftAddress][_tokenId].push(addBid);
        }

        emit Bidding(_nftAddress, _tokenId, msg.sender, msg.value);
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
        NFTAuction memory nftAuction = auctionData[_nftAddress][_tokenId];

        require(
            nftAuction.owner == msg.sender,
            "Only owner of nft can call this"
        );
        require(
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

        delete nftAuction;
        delete saleData[_nftAddress][_tokenId];
        updateSaleData(_nftAddress, _tokenId);

        emit EndedAuction(
            _nftAddress,
            _tokenId,
            nftAuction.highestBidder,
            nftAuction.highestBid
        );
    }
}

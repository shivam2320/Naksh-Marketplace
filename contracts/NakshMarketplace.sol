//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NakshNFT.sol";
import "./Structs.sol";

contract NakshMarketplace is Ownable{

    address payable public Naksh_org;

    struct SaleData {
        bool isOnSale;
        bool tokenFirstSale;
        uint salePrice;
    }

    NFTData[] getOnSaleNFTs;

    uint constant FLOAT_HANDLER_TEN_4 = 10000;

    mapping(address => mapping (uint => SaleData)) public saleData;

    event SalePriceSet(uint256 indexed _tokenId, uint256 indexed _price);
    event Sold(address indexed _buyer, address indexed _seller, uint256 _amount, uint256 indexed _tokenId);

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
        require(_newOrg != address(0), "New organization cannot be zero address");
        Naksh_org = payable(_newOrg);
    }

        /**
    * This function is used to set an NFT on sale. 
    * @dev The sale price set in this function will be used to perform the sale transaction
    * once the buyer wants to buy an NFT.
    */
    function setSale(address _nft, uint256 _tokenId, uint256 price) public virtual onlyOwnerOf(_nft, _tokenId) {
        require(saleData[_nft][_tokenId].isOnSale == false, "NFT is already on sale");
        address tOwner = IERC721(_nft).ownerOf(_tokenId);
        require(tOwner != address(0), "setSale: nonexistent token");
        
       saleData[_nft][_tokenId].isOnSale = true;
        saleData[_nft][_tokenId].salePrice = price;
        getOnSaleNFTs.push(NakshNFT(_nft).getNFTData(_tokenId));
        emit SalePriceSet(_tokenId, price);
    }

    function getNFTonSale() public view returns (NFTData[] memory){
        return getOnSaleNFTs;
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
        uint256 sellerFees =  _nft.getSellerFee();
        uint256 creatorRoyalty = _nft.creatorFee();
        uint256 platformFees = _nft.orgFee();

        require(price != 0, "buyToken: price equals 0");
        require(
            msg.value >= price,
            "buyToken: price doesn't equal salePrice[tokenId]"
        );
        address tOwner = IERC721(_nftAddress).ownerOf(_tokenId);

        IERC721(_nftAddress).safeTransferFrom(tOwner, msg.sender, _tokenId);
        saleData[_nftAddress][_tokenId].isOnSale = false;
        saleData[_nftAddress][_tokenId].salePrice = 0;

        if(saleData[_nftAddress][_tokenId].tokenFirstSale == false) {
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
        uint256 toCreator = (msg.value*creatorRoyalty) / FLOAT_HANDLER_TEN_4;
        uint256 toPlatform = (msg.value*platformFees) / FLOAT_HANDLER_TEN_4;
        
        // address tokenCreatorAddress = tokenCreator[_tokenId];
        
        payable(tOwner).transfer(toSeller);

        if(toCreator != 0) {
            uint256 _TotalSplits = _nft.TotalSplits(); 
            uint256 toCreators = toCreator/_TotalSplits;
            for (uint8 i = 0; i < _TotalSplits;) {
                payable(_nft.creators(i)).transfer(toCreators);
            }
            
        }
        
        Naksh_org.transfer(toPlatform);

        
        emit Sold(msg.sender, tOwner, msg.value, _tokenId);
    }

        /**
    * This is a getter function to get the current price of an NFT.
    */
    function getSalePrice(address _nft, uint256 _tokenId) public view returns (uint256) {
        require(saleData[_nft][_tokenId].isOnSale == true, "NFT is not on Sale");
        return saleData[_nft][_tokenId].salePrice;
    }

        /**
    * This function is used to change the price of a token
    * @notice Only token owner is allowed to change the price of a token
    */
    function changePrice(address _nft, uint256 _tokenId, uint256 price) public onlyOwnerOf(_nft ,_tokenId) {
        require(saleData[_nft][_tokenId].isOnSale == true, "NFT is not on sale");
        require(price > 0, "changePrice: Price cannot be changed to less than 0");
        saleData[_nft][_tokenId].salePrice = price;
    }

    /**
    * This function is used to check if it is the first sale of a token
    * on the Naksh marketplace.
    */
    function isTokenFirstSale(address _nftAddress, uint _tokenId) public view returns(bool){
        return saleData[_nftAddress][_tokenId].tokenFirstSale;
    }
}
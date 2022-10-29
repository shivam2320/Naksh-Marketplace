//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Naksh1155NFT.sol";
import "./Structs.sol";

contract oldNaksh1155Marketplace is Ownable, ERC1155Holder, ReentrancyGuard {
    address payable public Naksh_org;

    SaleData[] internal OnSaleNFTs;

    uint256 internal constant FLOAT_HANDLER_TEN_4 = 10000;

    mapping(address => mapping(uint256 => SaleData[])) public saleData;

    mapping(address => mapping(uint256 => mapping(address => SaleData[])))
        public saleData1;

    event SalePriceSet(
        address _owner,
        address _nft,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        uint256 currentTimestamp,
        bool tokenFirstSale,
        saleType saletype
    );
    event Sold(
        address _nft,
        address _buyer,
        uint256 _amount,
        uint256 _tokenId,
        uint256 timestamp
    );

    /**
     * Modifier to allow only owners of a token to perform certain actions
     */
    modifier onlyOwnerOf(address _nftAddress, uint256 _tokenId) {
        require(IERC1155(_nftAddress).balanceOf(msg.sender, _tokenId) > 0);
        _;
    }

    modifier amountCheck(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _amount
    ) {
        require(
            IERC1155(_nftAddress).balanceOf(msg.sender, _tokenId) >= _amount
        );
        _;
    }

    modifier isListed(
        address _nftAddress,
        uint256 _tokenId,
        address _ownerAdr
    ) {
        bool check = false;
        SaleData[] memory _saleData = saleData[_nftAddress][_tokenId];
        uint256 leng = _saleData.length;

        for (uint256 i = 0; i < leng; ) {
            if (_saleData[i]._owner == _ownerAdr) {
                check = true;
            }

            unchecked {
                ++i;
            }
        }

        if (check = true) {
            _;
        } else {
            revert("Wait for prev sale");
        }
    }

    modifier notListed(
        address _nftAddress,
        uint256 _tokenId,
        address _ownerAdr
    ) {
        bool check = false;
        SaleData[] memory _saleData = saleData[_nftAddress][_tokenId];
        uint256 leng = _saleData.length;

        for (uint256 i = 0; i < leng; ) {
            if (_saleData[i]._owner == _ownerAdr) {
                check = true;
                break;
            }

            unchecked {
                ++i;
            }
        }

        if (check = false) {
            _;
        } else {
            revert("Wait for prev sale");
        }
    }

    function getIndexOfArray(
        address _nftAddress,
        uint256 _tokenId,
        address _ownerAdr
    ) internal view returns (uint256) {
        SaleData[] memory _saleData = saleData[_nftAddress][_tokenId];
        uint256 leng = _saleData.length;
        uint256 index;
        for (uint256 i = 0; i < leng; ) {
            if (_saleData[i]._owner == _ownerAdr) {
                index = i;
            }

            unchecked {
                ++i;
            }
        }
        return index;
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
    //     Naksh1155NFT(_nft).mintByAdmin(_creator, _tokenURI, title, description, artistName);

    // }

    /**
     * This function is used to set an NFT on sale.
     * @dev The sale price set in this function will be used to perform the sale transaction
     * once the buyer wants to buy an NFT.
     */
    function setSale(
        address _nft,
        uint256 _tokenId,
        uint256 _amount,
        uint256 price
    )
        public
        amountCheck(_nft, _tokenId, _amount)
        notListed(_nft, _tokenId, msg.sender)
    {
        IERC1155(_nft).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            ""
        );
        SaleData memory _saleData;
        _saleData.nft = Naksh1155NFT(_nft).getNFTData(_tokenId);
        _saleData._owner = msg.sender;
        _saleData.isOnSale = true;
        _saleData.onSaleAmount = _amount;
        _saleData.salePrice = price;
        _saleData.saletype = saleType.DirectSale;
        OnSaleNFTs.push(_saleData);
        saleData[_nft][_tokenId].push(_saleData);
        emit SalePriceSet(
            msg.sender,
            _nft,
            _tokenId,
            _amount,
            price,
            block.timestamp,
            _saleData.tokenFirstSale,
            saleType.DirectSale
        );
    }

    function getNFTonSale() public view returns (SaleData[] memory) {
        return OnSaleNFTs;
    }

    function updateSaleData(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _amount,
        address _ownerAdr
    ) internal {
        SaleData[] storage _saleData;
        _saleData = saleData[_nftAddress][_tokenId];

        uint256 i = getIndexOfArray(_nftAddress, _tokenId, _ownerAdr);
        if (_saleData[i].onSaleAmount == _amount) {
            delete _saleData[i];
        } else {
            _saleData[i].onSaleAmount -= _amount;
        }
    }

    function getSaleData(address _nft, uint256 _tokenId)
        external
        view
        returns (SaleData[] memory)
    {
        return saleData[_nft][_tokenId];
    }

    function cancelSale(
        address _nft,
        uint256 _tokenId,
        uint256 _amount
    ) public isListed(_nft, _tokenId, msg.sender) {
        SaleData[] memory _saleData;
        _saleData = saleData[_nft][_tokenId];
        uint256 i = getIndexOfArray(_nft, _tokenId, msg.sender);
        require(
            _saleData[i].onSaleAmount >= _amount,
            "Not enough amount on sale"
        );
        IERC1155(_nft).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            _amount,
            ""
        );

        updateSaleData(_nft, _tokenId, _amount, msg.sender);
    }

    /**
     * This function is used to buy an NFT which is on sale.
     */
    function buyTokenOnSale(
        uint256 _tokenId,
        address _nftAddress,
        address _ownerAddr,
        uint256 _amount
    ) public payable {
        Naksh1155NFT _nft = Naksh1155NFT(_nftAddress);

        uint256 i = getIndexOfArray(_nftAddress, _tokenId, msg.sender);
        require(
            saleData[_nftAddress][_tokenId][i].onSaleAmount >= _amount,
            "Not enough amount on sale"
        );
        uint256 price = saleData[_nftAddress][_tokenId][i].salePrice;
        uint256 sellerFees = _nft.getSellerFee();
        uint16[] memory creatorRoyalty = _nft.getCreatorFees();
        uint256 totalCreatorFees = _nft.getTotalCreatorFees();
        uint256 platformFees = _nft.orgFee();

        require(
            (_amount * msg.value) >= price,
            "price doesn't equal salePrice"
        );
        address tOwner = saleData[_nftAddress][_tokenId][i]
            .nft
            .artist
            .artistAddress;

        IERC1155(_nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            _amount,
            ""
        );

        if (saleData[_nftAddress][_tokenId][i].tokenFirstSale == false) {
            platformFees = _nft.orgFeeInitial();
            sellerFees = _nft.sellerFeeInitial();
            // No creator royalty/royalties when artist is minting for the first time
            totalCreatorFees = 0;

            saleData[_nftAddress][_tokenId][i].tokenFirstSale = true;
        }
        payable(tOwner).transfer(
            (_amount * (msg.value * sellerFees)) / FLOAT_HANDLER_TEN_4
        );

        if (totalCreatorFees != 0) {
            splitCreatorRoyalty(address(_nft), creatorRoyalty, _amount);
        }

        Naksh_org.transfer(
            (_amount * (msg.value * platformFees)) / FLOAT_HANDLER_TEN_4
        );

        updateSaleData(_nftAddress, _tokenId, _amount, _ownerAddr);

        emit Sold(
            _nftAddress,
            msg.sender,
            msg.value,
            _tokenId,
            block.timestamp
        );
    }

    function splitCreatorRoyalty(
        address _nftAddress,
        uint16[] memory creatorRoyalty,
        uint256 _amount
    ) internal {
        Naksh1155NFT _nft = Naksh1155NFT(_nftAddress);
        uint256 _TotalSplits = _nft.TotalSplits();
        uint256[] memory toCreators;
        for (uint8 i = 0; i < _TotalSplits; ) {
            toCreators[i] =
                (_amount * (msg.value * creatorRoyalty[i])) /
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
        SaleData[] memory _saleData;
        _saleData = saleData[_nft][_tokenId];
        uint256 i = getIndexOfArray(_nft, _tokenId, msg.sender);
        require(_saleData[i].isOnSale == true, "NFT is not on Sale");
        return _saleData[i].salePrice;
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
        SaleData[] storage _saleData;
        _saleData = saleData[_nft][_tokenId];
        uint256 index = getIndexOfArray(_nft, _tokenId, msg.sender);
        require(_saleData[index].isOnSale == true, "NFT is not on sale");
        require(
            price > 0,
            "changePrice: Price cannot be changed to less than 0"
        );
        _saleData[index].salePrice = price;
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
        SaleData[] memory _saleData;
        _saleData = saleData[_nftAddress][_tokenId];
        uint256 i = getIndexOfArray(_nftAddress, _tokenId, msg.sender);
        return _saleData[i].tokenFirstSale;
    }
}

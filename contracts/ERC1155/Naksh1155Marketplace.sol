//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Naksh1155NFT.sol";
import "./Structs.sol";

contract Naksh1155Marketplace is Ownable, ERC1155Holder, ReentrancyGuard {
    address payable public Naksh_org;

    SaleData[] internal OnSaleNFTs;

    uint256 internal constant FLOAT_HANDLER_TEN_4 = 10000;

    mapping(address => mapping(uint256 => mapping(address => SaleData)))
        public saleData;

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
        address _seller,
        address _buyer,
        uint256 _price,
        uint256 _amount,
        uint256 _tokenId,
        uint256 timestamp
    );

    event Cancelled(address _nft, uint256 _tokenId, address _seller);

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
        SaleData memory _saleData = saleData[_nftAddress][_tokenId][_ownerAdr];

        if (_saleData.onSaleAmount > 0) {
            _;
        } else {
            revert("NFT not on sale");
        }
    }

    modifier notListed(
        address _nftAddress,
        uint256 _tokenId,
        address _ownerAdr
    ) {
        SaleData memory _saleData = saleData[_nftAddress][_tokenId][_ownerAdr];

        if (_saleData.onSaleAmount > 0 && _saleData.isOnSale == true) {
            revert("Wait for prev sale");
        } else {
            _;
        }
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
        if (isTokenFirstSale(_nft, _tokenId, msg.sender) == true) {
            _saleData.tokenFirstSale = true;
        }
        OnSaleNFTs.push(_saleData);
        saleData[_nft][_tokenId][msg.sender] = _saleData;
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
        if (
            (saleData[_nftAddress][_tokenId][_ownerAdr].onSaleAmount -
                _amount) == 0
        ) {
            saleData[_nftAddress][_tokenId][_ownerAdr].isOnSale = false;
            saleData[_nftAddress][_tokenId][_ownerAdr].onSaleAmount = 0;
            SaleData memory _saleData;
            _saleData = saleData[_nftAddress][_tokenId][_ownerAdr];

            for (uint256 i = 0; i < OnSaleNFTs.length; ) {
                if (
                    OnSaleNFTs[i].nft.nftAddress == _nftAddress &&
                    OnSaleNFTs[i].nft.tokenId == _tokenId &&
                    OnSaleNFTs[i]._owner == _ownerAdr
                ) {
                    _saleData = OnSaleNFTs[i];
                    OnSaleNFTs[i] = OnSaleNFTs[OnSaleNFTs.length - 1];
                    OnSaleNFTs[OnSaleNFTs.length - 1] = _saleData;
                }
                OnSaleNFTs.pop();
                unchecked {
                    ++i;
                }
            }
        } else {
            saleData[_nftAddress][_tokenId][_ownerAdr].onSaleAmount -= _amount;
        }
    }

    function getSaleData(
        address _nft,
        uint256 _tokenId,
        address _ownerAddr
    ) external view returns (SaleData memory) {
        return saleData[_nft][_tokenId][_ownerAddr];
    }

    function cancelSale(
        address _nft,
        uint256 _tokenId,
        uint256 _amount
    ) public isListed(_nft, _tokenId, msg.sender) {
        SaleData storage _saleData;
        _saleData = saleData[_nft][_tokenId][msg.sender];

        require(_saleData.onSaleAmount >= _amount, "Not enough amount on sale");
        IERC1155(_nft).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            _amount,
            ""
        );

        updateSaleData(_nft, _tokenId, _amount, msg.sender);
        emit Cancelled(_nft, _tokenId, msg.sender);
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
        SaleData storage _saleData;
        _saleData = saleData[_nftAddress][_tokenId][_ownerAddr];
        require(
            saleData[_nftAddress][_tokenId][_ownerAddr].onSaleAmount >= _amount,
            "Not enough amount on sale"
        );
        uint256 sellerFees = Naksh1155NFT(_nftAddress).getSellerFee();
        uint16[] memory creatorRoyalty = Naksh1155NFT(_nftAddress)
            .getCreatorFees();
        uint256 totalCreatorFees = Naksh1155NFT(_nftAddress)
            .getTotalCreatorFees();
        uint256 platformFees = Naksh1155NFT(_nftAddress).orgFee();

        require(
            msg.value >=
                (_amount *
                    saleData[_nftAddress][_tokenId][_ownerAddr].salePrice),
            "price doesn't equal salePrice"
        );
        address tOwner = saleData[_nftAddress][_tokenId][_ownerAddr]._owner;

        IERC1155(_nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            _amount,
            ""
        );

        if (
            saleData[_nftAddress][_tokenId][_ownerAddr].tokenFirstSale == false
        ) {
            platformFees = Naksh1155NFT(_nftAddress).orgFeeInitial();
            sellerFees = Naksh1155NFT(_nftAddress).sellerFeeInitial();
            // No creator royalty/royalties when artist is minting for the first time
            totalCreatorFees = 0;

            saleData[_nftAddress][_tokenId][_ownerAddr].tokenFirstSale = true;
        } else {
            totalCreatorFees = Naksh1155NFT(_nftAddress).getTotalCreatorFees();
        }
        payable(tOwner).transfer(
            (msg.value * sellerFees) / FLOAT_HANDLER_TEN_4
        );

        if (totalCreatorFees != 0) {
            splitCreatorRoyalty(
                address(Naksh1155NFT(_nftAddress)),
                creatorRoyalty,
                msg.value
            );
        }

        Naksh_org.transfer((msg.value * platformFees) / FLOAT_HANDLER_TEN_4);

        updateSaleData(_nftAddress, _tokenId, _amount, _ownerAddr);

        emit Sold(
            _nftAddress,
            _ownerAddr,
            msg.sender,
            msg.value,
            _amount,
            _tokenId,
            block.timestamp
        );
    }

    function splitCreatorRoyalty(
        address _nftAddress,
        uint16[] memory creatorRoyalty,
        uint256 value
    ) internal {
        Naksh1155NFT _nft = Naksh1155NFT(_nftAddress);
        uint256 _TotalSplits = _nft.TotalSplits();
        uint256[] memory toCreators = new uint256[](_TotalSplits);
        for (uint8 i = 0; i < _TotalSplits; ) {
            toCreators[i] = (value * creatorRoyalty[i]) / FLOAT_HANDLER_TEN_4;
            payable(_nft.creators(i)).transfer(toCreators[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * This is a getter function to get the current price of an NFT.
     */
    function getSalePrice(
        address _nft,
        uint256 _tokenId,
        address _ownerAddr
    ) public view returns (uint256) {
        SaleData storage _saleData;
        _saleData = saleData[_nft][_tokenId][_ownerAddr];
        require(_saleData.isOnSale == true, "NFT is not on Sale");
        return _saleData.salePrice;
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
        SaleData storage _saleData;
        _saleData = saleData[_nft][_tokenId][msg.sender];
        require(_saleData.isOnSale == true, "NFT is not on sale");
        require(
            price > 0,
            "changePrice: Price cannot be changed to less than 0"
        );
        _saleData.salePrice = price;
    }

    /**
     * This function is used to check if it is the first sale of a token
     * on the Naksh marketplace.
     */
    function isTokenFirstSale(
        address _nftAddress,
        uint256 _tokenId,
        address _ownerAddr
    ) public view returns (bool) {
        SaleData storage _saleData;
        _saleData = saleData[_nftAddress][_tokenId][_ownerAddr];
        return _saleData.tokenFirstSale;
    }
}

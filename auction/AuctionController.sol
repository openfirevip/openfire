pragma solidity ^0.8.0;

import "../auction/AuctionData.sol";
import "../common/Pausable.sol";
import "../common/DataOwnable.sol";
import "../hrc721/Earth.sol";
import "../hrc20/ofe.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {

        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

contract AuctionController is AuctionData, Pausable, DataOwnable {
    
    using SafeMath for uint256;
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
    
    using Counters for Counters.Counter;
    Counters.Counter private _auctionIndex;
    
    event AuctionCreated(uint256 tokenId, uint256 startingPrice, uint256 auctionType);
    event AuctionSuccessful(uint256 tokenId, uint256 totalPrice, address winner);
    event AuctionCancelled(uint256 tokenId);

    function createAuction(
        uint256 _tokenId,
        uint256 _startingPrice,
        uint64 _auctionType,
        uint64 _payType,
        uint256 _endTime
    )
        public
        whenNotPaused returns(bool)
    {
        require(_payType < payContract.length, "Auction: pay type is error");
        require(_auctionType == 0 || _auctionType == 1, "Auction: auction type is error");
        
        // transfer token to this
        Earth earth = Earth(nftContract);
        earth.transferFrom(msg.sender, address(this), _tokenId);
        
        // add auction
        _addAuction(_tokenId, msg.sender, _auctionType, _payType, _startingPrice, address(0), 0, _endTime);
        
        emit AuctionCreated(_tokenId, _startingPrice, _auctionType);
        
        return true;
    }
    
    function cancelAuction(uint256 _tokenId) public whenNotPaused returns(bool) {
       _cancelAuction(_tokenId);
        
        return true;
    }
    
    function _cancelAuction(uint256 _tokenId) private returns(bool) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(auction.seller != address(0), "Auction: auction isn't esists");
        require(msg.sender == auction.seller, "Auction: token isn't operator");
        require(auction.state == 0, "Auction: is over or cancel");
        require(auction.finalAccount == address(0), "Auction: is on auction");
        
        auction.state = 2;
        
        // transfer token to seller
        Earth earth = Earth(nftContract);
        earth.transferFrom(address(this), auction.seller, _tokenId);
        
        auctionRecords[auction.index].auction.state = 2;
        auctionRecords[auction.index].operateTime = block.timestamp;
        
        emit AuctionCancelled(_tokenId);
        
        return true;
    }
    
    // type: 0
    function priceAuction(uint256 _tokenId) public whenNotPaused returns(bool) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(auction.seller != address(0), "Auction: auction isn't exists");
        require(auction.auctionType == 0, "Auction: auction type error");
        require(auction.state == 0, "Auction: auction not carried out");
        
        ofe tokenInstance = ofe(payContract[auction.payType]);
        tokenInstance.transferFrom(msg.sender, auction.seller, auction.startingPrice);
        
        Earth earth = Earth(nftContract);
        earth.transferFrom(address(this), msg.sender, _tokenId);
        
        auction.state = 1;
        auction.finalAccount = msg.sender;
        auction.finalPrice = auction.startingPrice;
        
        auctionRecords[auction.index].auction.state = 1;
        auctionRecords[auction.index].auction.finalAccount = msg.sender;
        auctionRecords[auction.index].auction.finalPrice = auction.startingPrice;
        auctionRecords[auction.index].operateTime = block.timestamp;
        
        return true;
    }
    
    // type: 1
    function englandAuction(uint256 _tokenId, uint256 _auctionPrice) public whenNotPaused returns(bool) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(auction.seller != address(0), "Auction: auction isn't exists");
        require(auction.auctionType == 1, "Auction: auction type error");
        require(auction.state == 0, "Auction: auction not carried out");
        require(auction.endTime >= block.timestamp, "Auction: auction is over");
        
        if(auction.finalAccount != address(0)) {
            require(_auctionPrice > auction.finalPrice, "Auction: price le current final");
        } else {
            require(_auctionPrice > auction.startingPrice, "Auction: price le current starting");
        }
        
        // auctioneer transfer
        ofe tokenInstance = ofe(payContract[auction.payType]);
        tokenInstance.transferFrom(msg.sender, address(this), _auctionPrice);
        
        // refund of last auctioneer transfer
        if(auction.finalAccount != address(0)) {
            tokenInstance.transfer(auction.finalAccount, auction.finalPrice);
        }
        
        auction.finalAccount = msg.sender;
        auction.finalPrice = _auctionPrice;
        
        // add records
        auctionRecords[auction.index].account.push(msg.sender);
        auctionRecords[auction.index].price.push(_auctionPrice);
        auctionRecords[auction.index].time.push(block.timestamp);
        auctionRecords[auction.index].auction.finalAccount = msg.sender;
        auctionRecords[auction.index].auction.finalPrice = _auctionPrice;
        auctionRecords[auction.index].operateTime = block.timestamp;
        
        // account bid history
        accountBidHistory[msg.sender][auction.index][_tokenId] = _auctionPrice;
        
        return true;
    }
    
    function _addAuction(uint256 _tokenId, address _seller, uint64 _auctionType, uint64 _payType,
                        uint256 _startingPrice, address _finalAccount, uint256 _finalPrice, uint256 _endTime) private {
        _auctionIndex.increment();
        uint256 newAuctionIndex = _auctionIndex.current();
        
        Auction memory auction = Auction({
            index: newAuctionIndex,
            seller: _seller,
            auctionType: _auctionType,
            payType: _payType,
            startingPrice: _startingPrice,
            finalAccount: _finalAccount,
            finalPrice: _finalPrice,
            endTime: _endTime,
            sellingTime: block.timestamp,
            state: 0
        });
        tokenIdToAuction[_tokenId] = auction;
        
        auctionTokenIds[newAuctionIndex] = _tokenId;
        
        auctionRecords[newAuctionIndex].auction = auction;
        auctionRecords[newAuctionIndex].operateTime = block.timestamp;
    }
    
    // ===================================== interface ====================================
    function queryByIndex(uint256 _index) public view returns(Auction memory auctionRecord) {
        auctionRecord = tokenIdToAuction[auctionTokenIds[_index]];
    }
    
    function totalSynthesisRecord() public view returns(uint256 total) {
        total = _auctionIndex.current();
    }
    
    function checkOver(uint256 _tokenId) public view returns(bool) {
        Auction memory auction = tokenIdToAuction[_tokenId];
        if(auction.seller == address(0)) {
            return false;
        }
        
        if(auction.endTime > block.timestamp) {
            return false;
        }
        
        if(auction.auctionType == 0) {
            return false;
        }
        
        if(auction.state != 0) {
            return false;
        }
        
        return true;
    }
    
    function auctionOverOperate(uint256 _tokenId) public onlyInterfaceOwner returns(bool) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(auction.seller != address(0), "Auction: isn't exists");
        require(auction.endTime <= block.timestamp, "Auction: isn't over");
        require(auction.state == 0, "Auction: state is over or cancel");
        require(auction.auctionType == 1, "Auction: type is error");
        
        Earth earth = Earth(nftContract);
        if(auction.finalAccount != address(0)) {
            // transfer price to seller
            ofe tokenInstance = ofe(payContract[auction.payType]);
            tokenInstance.transfer(auction.seller, auction.finalPrice);
            
            // transfer nft to finalAccount
            earth.transferFrom(address(this), auction.finalAccount, _tokenId);
        } else {
            // refund nft to seller
            earth.transferFrom(address(this), auction.seller, _tokenId);
        }
        
        // update info 
        auction.state = 1;
        
        auctionRecords[auction.index].auction.state = 1;
        auctionRecords[auction.index].operateTime = block.timestamp;
        
        return true;
    }
    
    function queryAuctionRecordAccountInfo(uint256 _index, uint256 _arrIndex) public view returns(address account, uint256 total) {
        account = auctionRecords[_index].account[_arrIndex];
        total = auctionRecords[_index].account.length;
    }
    
    function queryAuctionRecordPriceInfo(uint256 _index, uint256 _arrIndex) public view returns(uint256 price, uint256 total) {
        price = auctionRecords[_index].price[_arrIndex];
        total = auctionRecords[_index].price.length;
    }
    
    function queryAuctionRecordTimeInfo(uint256 _index, uint256 _arrIndex) public view returns(uint256 time, uint256 total) {
        time = auctionRecords[_index].time[_arrIndex];
        total = auctionRecords[_index].time.length;
    }
    
    // ======================================= data =======================================
    address public nftContract;
    address[] public payContract;
    function setContract(address _nftContract, address[] memory _payContract) public onlyOwner returns(bool) {
        nftContract = _nftContract;
        payContract = _payContract;
        return true;
    }
    
    /**
    * @dev called by the owner to pause, triggers stopped state
    */
    function pause() public onlyOwner whenNotPaused returns (bool) {
        paused = true;
        emit Pause();
        return true;
    }
    
    /**
    * @dev called by the owner to unpause, returns to normal state
    */
    function unpause() public onlyOwner whenPaused returns (bool) {
        paused = false;
        emit Unpause();
        return true;
    }

}
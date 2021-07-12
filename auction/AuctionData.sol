pragma solidity ^0.8.0;

contract AuctionData {
    
    struct Auction {
        uint256 index;
        address seller;
        uint64 auctionType; // 0: Price; 1: English system;
        uint64 payType; // 0: ofe; 1: usdt; 
        uint256 startingPrice;
        address finalAccount;
        uint256 finalPrice;
        uint256 endTime;
        uint256 sellingTime;
        uint64 state; // 0: at auction; 1: aution over; 2: aution cancel;
    }
    mapping(uint256 => Auction) public tokenIdToAuction; // tokenId => Auction
    mapping(uint256 => uint256) public auctionTokenIds; // index => tokenId
    
    struct AuctionRecord {
        address[] account;
        uint256[] price;
        uint256[] time;
        Auction auction;
        uint256 operateTime;
    }
    mapping(uint256 => AuctionRecord) public auctionRecords; // index => records
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public accountBidHistory;
    
}
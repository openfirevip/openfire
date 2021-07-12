pragma solidity ^0.8.0;

contract HrcData {
    
    struct BaseData {
        uint256 tokenId;
        uint256 toolsId;
        uint256 getTime;
        bool isDecorate;
    }
    mapping(uint256 => BaseData) tokenBaseDataMapping; // hrcNo => BaseData
    mapping(uint256 => address) hrcNoAccountMapping; // hrcNo => address
    mapping(uint256 => uint256) tokenIdHrcNoMapping; // tokenId => hrcNo
    
    mapping(uint256 => mapping(uint256 => uint256)) minerOpens; // minerIndex => minerNum => hrcNo
    struct MinerOpen {
        uint256 minerIndex;
        uint256 minerNum;
    }
    mapping(uint256 => MinerOpen) hrcNoMinerOpens; // hrcNo => MinerOpen
    
    struct UrlHistory {
        address belongAddress;
        string url;
        uint256 uploadTime;
    }
    mapping(uint256 => UrlHistory[]) urlHistorys; // tokenId => UrlHistory
    
}
pragma solidity ^0.8.0;

import "../common/DataOwnable.sol";
import "./HrcData.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HrcDataController is DataOwnable, HrcData {
    
    using Counters for Counters.Counter;
    Counters.Counter private _hrcNos;
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
    
    // ================================== BaseData operate ==================================
    function queryBaseData(uint256 _hrcNo) public view returns(BaseData memory baseData) {
        baseData = tokenBaseDataMapping[_hrcNo];
    }
    function queryBaseDataByTokenId(uint256 _tokenId) public view returns(BaseData memory baseData) {
        baseData = tokenBaseDataMapping[tokenIdHrcNoMapping[_tokenId]];
    }
    function queryToolsId(uint256 _hrcNo) public view returns(uint256 toolsId) {
        toolsId = tokenBaseDataMapping[_hrcNo].toolsId;
    }
    function addOrUpdBaseData(uint256 _hrcNo, uint256 _toolsId, bool _isDecorate) public onlyDataOperater returns(bool) {
        tokenBaseDataMapping[_hrcNo].toolsId = _toolsId;
        tokenBaseDataMapping[_hrcNo].getTime = block.timestamp;
        tokenBaseDataMapping[_hrcNo].isDecorate = _isDecorate;
        return true;
    }
    function delBaseData(uint256 _hrcNo) public onlyDataOperater returns(bool) {
        delete tokenBaseDataMapping[_hrcNo];
        return true;
    }
    
    // ================================== UrlHistory operate ==================================
    function queryUrlHistory(uint256 _tokenId, uint256 _historyIndex) public view returns(UrlHistory memory urlHistory, uint256 total) {
        urlHistory = urlHistorys[_tokenId][_historyIndex];
        total = urlHistorys[_tokenId].length;
    }
    function addUrlHistory(uint256 _tokenId, address _belongAddress, string memory _url) public onlyDataOperater returns(bool) {
        UrlHistory[] storage urlHistoryArr = urlHistorys[_tokenId];
        UrlHistory memory urlHistory = UrlHistory({
            belongAddress: _belongAddress,
            url: _url,
            uploadTime: block.timestamp
        });
        urlHistoryArr.push(urlHistory);
        tokenBaseDataMapping[tokenIdHrcNoMapping[_tokenId]].isDecorate = true;
        return true;
    }
    function updUrlHistory(uint256 _tokenId, uint256 _historyIndex, 
                            address _belongAddress, string memory _url, bool _isDecorate) public onlyDataOperater returns(bool) {
        UrlHistory storage urlHistory = urlHistorys[_tokenId][_historyIndex];
        urlHistory.belongAddress = _belongAddress;
        urlHistory.url = _url;
        urlHistory.uploadTime = block.timestamp;
        tokenBaseDataMapping[tokenIdHrcNoMapping[_tokenId]].isDecorate = _isDecorate;
        return true;
    }
    function delUrlHistory(uint256 _tokenId, uint256 _historyIndex) public onlyDataOperater returns(bool) {
        delete urlHistorys[_tokenId][_historyIndex];
        return true;
    }
    function delAllUrlHistory(uint256 _tokenId) public onlyDataOperater returns(bool) {
        delete urlHistorys[_tokenId];
        return true;
    }
    
    // ================================== minerOpens operate ==================================
    function queryMinerOpens(uint256 _minerIndex, uint256 _minerNum) public view returns(uint256 minerNum) {
        minerNum = minerOpens[_minerIndex][_minerNum];
    }
    function updMinerOpens(uint256 _minerIndex, uint256 _minerNum, uint256 _tokenId) public onlyDataOperater returns(bool) {
        minerOpens[_minerIndex][_minerNum] = _tokenId;
        return true;
    }
    function delMinerOpens(uint256 _minerIndex, uint256 _minerNum) public onlyDataOperater returns(bool) {
        delete minerOpens[_minerIndex][_minerNum];
        return true;
    }
    function queryHrcNoMinerOpens(uint256 _hrcNo) public view returns(MinerOpen memory minerOpen) {
        minerOpen = hrcNoMinerOpens[_hrcNo];
    }
    
    // ================================== interface ==================================
    function addAllData(uint256 _toolsId, 
                            uint256 _minerIndex, uint256 _minerNum, address _account) public onlyInterfaceOwner returns(bool) {
                                
        _hrcNos.increment();
        uint256 hrcNo = _hrcNos.current();
        
        tokenBaseDataMapping[hrcNo].toolsId = _toolsId;
        tokenBaseDataMapping[hrcNo].getTime = block.timestamp;
        tokenBaseDataMapping[hrcNo].isDecorate = false;
        
        minerOpens[_minerIndex][_minerNum] = hrcNo;
        MinerOpen memory minerOpen = MinerOpen({
            minerIndex: _minerIndex,
            minerNum: _minerNum
        });
        hrcNoMinerOpens[hrcNo] = minerOpen;
        
        hrcNoAccountMapping[hrcNo] = _account;
        
        return true;
    }
    
    function uploadUrl(uint256 _tokenId, string memory _url, address _belongAddress, uint256 _hrcNo) public onlyInterfaceOwner returns(bool) {
        UrlHistory[] storage urlHistoryArr = urlHistorys[_tokenId];
        UrlHistory memory urlHistory = UrlHistory({
            belongAddress: _belongAddress,
            url: _url,
            uploadTime: block.timestamp
        });
        urlHistoryArr.push(urlHistory);
        tokenIdHrcNoMapping[_tokenId] = _hrcNo;
        tokenBaseDataMapping[_hrcNo].isDecorate = true;
        tokenBaseDataMapping[_hrcNo].tokenId = _tokenId;
        
        return true;
    }
    
    function queryGrantCheckData(uint256 _minerIndex, uint256 _minerNum) public view returns(uint256 hrcNo, uint256 tokenId) {
        hrcNo = minerOpens[_minerIndex][_minerNum];
        tokenId = tokenBaseDataMapping[hrcNo].tokenId;
    }
    
    function moreDecorate(uint256 _tokenId, address _belongAddress, string memory _url) public onlyInterfaceOwner returns(bool) {
        addUrlHistory(_tokenId, _belongAddress, _url);
        return true;
    }
    
    function queryhrcNoAccountMapping(uint256 _hrcNo) public view returns(address) {
        return hrcNoAccountMapping[_hrcNo];
    }
}
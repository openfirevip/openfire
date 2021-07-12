pragma solidity ^0.8.0;

import "../common/DataOwnable.sol";
import "./MapData.sol";

contract MapDataController is DataOwnable, MapData {
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
    
    function queryMapBaseData(uint256 _toolsId) public view returns(MapBaseData memory mapBaseData) {
        mapBaseData = mapBaseDatas[_toolsId];
    }
    
    function addOrUpdMapBaseData(uint256 _toolsId, uint256 _uperToolsId, uint256 _level, 
                            string memory _abbreviation, string memory _fullName,
                            string memory _url, uint256[] memory _synthesisNeedToolsId) public onlyDataOperater returns(bool) {
        mapBaseDatas[_toolsId].flag = true;
        mapBaseDatas[_toolsId].toolsId = _toolsId;
        mapBaseDatas[_toolsId].uperToolsId = _uperToolsId;
        mapBaseDatas[_toolsId].level = _level;
        mapBaseDatas[_toolsId].abbreviation = _abbreviation;
        mapBaseDatas[_toolsId].fullName = _fullName;
        mapBaseDatas[_toolsId].url = _url;
        mapBaseDatas[_toolsId].synthesisNeedToolsId = _synthesisNeedToolsId;
        
        return true;
    }
    function delMapBaseData(uint256 _toolsId) public onlyDataOperater returns(bool) {
        delete mapBaseDatas[_toolsId];
        
        return true;
    }
    
    function queryLevelMoney(uint256 _level) public view returns(LevelMoney memory levelMoney) {
        levelMoney = levelMoneys[_level];
    }
    function addOrUpdLevelMoney(uint256 _level, uint256 _recoveryMoney, address _capitalAccount) public onlyDataOperater returns(bool) {
        levelMoneys[_level].recoveryMoney = _recoveryMoney;
        levelMoneys[_level].capitalAccount = _capitalAccount;
        
        return true;
    }
    function delRecoveryMoney(uint256 _level) public onlyDataOperater returns(bool) {
        delete levelMoneys[_level];
        
        return true;
    }
    
    function queryOpenBoxLimitNum(uint256 _level) public view returns(uint256 openBoxLimitNum) {
        openBoxLimitNum = openBoxLimitNums[_level];
    }
    function addOrUpdOpenBoxLimitNum(uint256 _level, uint256 _openBoxLimitNum) public onlyDataOperater returns(bool) {
        openBoxLimitNums[_level] = _openBoxLimitNum;
        
        return true;
    }
    function delOpenBoxLimitNum(uint256 _level) public onlyDataOperater returns(bool) {
        delete openBoxLimitNums[_level];
        
        return true;
    }
    
    function queryOpenProductNum(uint256 _toolsId) public view returns(uint256 openProductNum) {
        openProductNum = openProductNums[_toolsId];
    }
    function addOrUpdOpenProductNum(uint256 _toolsId, uint256 _openProductNum) public onlyDataOperater returns(bool) {
        openProductNums[_toolsId] = _openProductNum;
        
        return true;
    }
    function delOpenProductNum(uint256 _toolsId) public onlyDataOperater returns(bool) {
        delete openProductNums[_toolsId];
        
        return true;
    }
    
    function queryOpenLevelProductNum(uint256 _level) public view returns(uint256 openLevelProductNum) {
        openLevelProductNum = openLevelProductNums[_level];
    }
    function addOrUpdOpenLevelProductNum(uint256 _level, uint256 _openLevelProductNum) public onlyDataOperater returns(bool) {
        openLevelProductNums[_level] = _openLevelProductNum;
        
        return true;
    }
    function delOpenLevelProductNum(uint256 _level) public onlyDataOperater returns(bool) {
        delete openLevelProductNums[_level];
        
        return true;
    }
    
    // ==================================== interface ====================================
    function isOverLimit(uint256 _toolsId) public view onlyInterfaceOwner returns(bool) {
        MapBaseData memory mapBaseData = mapBaseDatas[_toolsId];
        if(!mapBaseData.flag) { // map isn't exists
            return false;
        }
        if(mapBaseData.level == 1) {
            if(openProductNums[_toolsId]+1 > openBoxLimitNums[1]) {
                return false;
            }
        } else {
            if(openLevelProductNums[mapBaseData.level]+1 > openBoxLimitNums[mapBaseData.level]) {
                return false;
            }
        }
        
        return true;
    }
    
    function changeProductNum(uint256 _toolsId) public onlyInterfaceOwner returns(bool) {
        MapBaseData storage mapBaseData = mapBaseDatas[_toolsId];
        openProductNums[_toolsId] += 1;
        openLevelProductNums[mapBaseData.level] += 1;
        
        return true;
    }
    
    function uploadUrl(uint256 _toolsId, string memory _url) public onlyInterfaceOwner returns(bool) {
        MapBaseData storage mapBaseData = mapBaseDatas[_toolsId];
        mapBaseData.url = _url;
        
        return true;
    }
    
    function getLevelByToolsId(uint256 _toolsId) public view returns(LevelMoney memory levelMoney) {
        levelMoney = levelMoneys[mapBaseDatas[_toolsId].level];
    }
    
}
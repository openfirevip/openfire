pragma solidity ^0.8.0;

contract MapData {
    
    struct MapBaseData {
        bool flag;
        uint256 toolsId;
        uint256 uperToolsId;
        uint256 level; // 1: township; 2: county; 3: city; 4: province;
        string abbreviation;
        string fullName;
        string url;
        uint256[] synthesisNeedToolsId;
    }
    mapping(uint256 => MapBaseData) mapBaseDatas; // toolsId => MapBaseData
    
    struct LevelMoney {
        uint256 recoveryMoney;
        address capitalAccount;
    }
    mapping(uint256 => LevelMoney) levelMoneys; // level => LevelMoney
    mapping(uint256 => uint256) openBoxLimitNums; // level => openBoxLimitNum
    
    mapping(uint256 => uint256) openProductNums; // toolsId => openProductNum
    mapping(uint256 => uint256) openLevelProductNums; // level => openLevelProductNum
    
}
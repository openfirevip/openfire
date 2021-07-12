pragma solidity ^0.8.0;

import "../common/DataOwnable.sol";
import "../hrc721/Earth.sol";
import "../hrc721/HrcData.sol";
import "../hrc721/HrcDataController.sol";
import "../miner/MinerController.sol";
import "../miner/Miner.sol";
import "../mapdata/MapData.sol";
import "../mapdata/MapDataController.sol";

contract OpenBlindBoxController is DataOwnable, Miner, MapData, HrcData {
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
        
    // minerInfo: uint256 _minerIndex, uint256 _minerNum, uint256 _systemNo
    function openAndGrantMap(address _to, uint256 _toolsId, uint256[] memory _minerInfo) 
                            public onlyInterfaceOwner returns(bool) {
        
        require(_minerInfo.length == 3, "miner info error");
        string memory result = openAddGrantCheck(_minerInfo[0], _to, _minerInfo[1], _minerInfo[2], _toolsId);
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked("0")), result);
        
        // add token data
        MinerController minerController = MinerController(minerContract);
        (MinerRecords memory miner, uint256 total) = minerController.getSystemMinerRecord(_minerInfo[2], _minerInfo[0]);
        require(addTokenData(_toolsId, _minerInfo[0], _minerInfo[1], miner.account), "add token data fail");
        
        return true;
        
    }
    
    function openAddGrantCheck(uint256 _minerIndex, address _to, uint256 _minerNum, uint256 _systemNo, uint256 _toolsId) 
            public view onlyInterfaceOwner returns(string memory) {
        MinerController minerController = MinerController(minerContract);
        // miner is exists
        (MinerRecords memory miner, uint256 total) = minerController.getSystemMinerRecord(_systemNo, _minerIndex);
        if(miner.account == address(0)) {
            return "1"; // miner isn't exists
        }
        if(_to != miner.account) {
            return "2"; // miner isn't owner
        }
        
        // check miner num
        if(_minerNum <= 0 || _minerNum > miner.num) {
            return "3"; // miner num is error
        }
        
        // check miner state
        if(miner.overTime > block.timestamp) {
            return "4"; // miner isn't over
        }
        
        // check miner is open
        HrcDataController hrcData = HrcDataController(hrcDataContract);
        uint256 systemOpenMinerHrcNo = hrcData.queryMinerOpens(_minerIndex, _minerNum);
        if(systemOpenMinerHrcNo != 0) {
            return "5"; // miner is opened
        }
        
        // check map num
        MapDataController mapData = MapDataController(mapDataContract);
        if(!mapData.isOverLimit(_toolsId)) {
            return "6";
        }
        
        return "0";
    }
    
    // string memory _abbreviation, string memory _fullName,
    // uint256 _minerIndex, uint256 _minerNum
    function addTokenData(uint256 _toolsId, uint256 _minerIndex, uint256 _minerNum, address _account) private onlyInterfaceOwner returns(bool) {
        HrcDataController hrcData = HrcDataController(hrcDataContract);
        // add open box data(basedata, tokentransferpath, mineropen)
        require(hrcData.addAllData(_toolsId, _minerIndex, _minerNum, _account), "add open box data fail");
        
        MapDataController mapData = MapDataController(mapDataContract);
        
        // update limit num
        require(mapData.changeProductNum(_toolsId), "change product num fail");
        
        return true;
    }
    
    
    // ======================================= data =======================================
    address public hrcDataContract;
    address public earthContract;
    address public mapDataContract;
    address public minerContract;
    function setContract(address _hrcDataContract, address _earthContract, 
                        address _mapDataContract, address _minerContract) public onlyOwner returns(bool) {
		require(_hrcDataContract != address(0), "_hrcDataContract is a zero-address");
		require(_earthContract != address(0), "_earthContract is a zero-address");
		require(_mapDataContract != address(0), "_mapDataContract is a zero-address");
		require(_minerContract != address(0), "_minerContract is a zero-address");
		
        hrcDataContract = _hrcDataContract;
        earthContract = _earthContract;
        mapDataContract = _mapDataContract;
        minerContract = _minerContract;
        return true;
    }
    
}
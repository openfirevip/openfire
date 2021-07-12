pragma solidity ^0.8.0;

import "../common/DataOwnable.sol";
import "../hrc721/Earth.sol";
import "../hrc721/HrcData.sol";
import "../hrc721/HrcDataController.sol";
import "../mapdata/MapData.sol";
import "../mapdata/MapDataController.sol";
import "../hrc20/ofe.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../common/Pausable.sol";

abstract contract IMdexPair {
    function price(address token, uint256 baseDecimal) external virtual view returns (uint256);
}

contract RecoveryController is DataOwnable, Pausable, HrcData, MapData {
    
    using Counters for Counters.Counter;
    Counters.Counter private _recoveryIds;
    
	event _setContract(address hrcDataContract, address mapDataContract, address earthContract, address[] ofeContract);
	
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
        
    function getPrice(uint256 _pid) public view returns(uint256) {
        IMdexPair iMdexPair = IMdexPair(ccyInfo[_pid].lpAddress);
        return iMdexPair.price(ccyInfo[_pid].tokenAddress, ccyInfo[_pid].baseDecimal);
    }
    
    function recovery(uint256 _tokenId, uint256 _pid) public whenNotPaused returns(bool) {
        require(ccyInfo[_pid].lpAddress != address(0), "Recovery: ccyInfo isn't exists");
        // get base data
        HrcDataController hrcDataInstance = HrcDataController(hrcDataContract);
        BaseData memory baseData = hrcDataInstance.queryBaseData(_tokenId);
        require(baseData.toolsId != 0, "Recovery: token not exists");
        
        // get level
        MapDataController mapDataInstance = MapDataController(mapDataContract);
        LevelMoney memory levelMoney = mapDataInstance.getLevelByToolsId(baseData.toolsId);
        require(levelMoney.capitalAccount != address(0), "Recovery: capitalAccount not exists");
        
        // transfer token
        Earth earthInstance = Earth(earthContract);
        earthInstance.transferFrom(msg.sender, levelMoney.capitalAccount, _tokenId);
        
        // transfer money
        uint256 singlePrice = 1;//getPrice(_pid);
        uint256 ofeNum = levelMoney.recoveryMoney/singlePrice*ccyInfo[_pid].baseDecimal;
        ofe ofeInstance = ofe(ofeContract[_pid]);
        ofeInstance.transferFrom(levelMoney.capitalAccount, msg.sender, ofeNum);
        
        addRecords(msg.sender, _tokenId, levelMoney.recoveryMoney, singlePrice, ofeNum);
        
        return true;
    }
    
    // ======================================= data =======================================
    address public hrcDataContract;
    address public mapDataContract;
    address public earthContract;
    address[] public ofeContract;
    function setContract(address _hrcDataContract, address _mapDataContract, address _earthContract, address[] memory _ofeContract) public onlyOwner returns(bool) {
        hrcDataContract = _hrcDataContract;
        mapDataContract = _mapDataContract;
        earthContract = _earthContract;
        ofeContract = _ofeContract;
		
		emit _setContract(_hrcDataContract, _mapDataContract, _earthContract, _ofeContract);
        return true;
    }
    
    struct RecoveryCcyInfo {
        address lpAddress;
        address tokenAddress;
        uint256 baseDecimal;
    }
    mapping(uint256 => RecoveryCcyInfo) public ccyInfo;
    
    function addOrUpdCcyInfo(uint256 _pid, address _lpAddress, address _tokenAddress, uint256 _baseDecimal) public onlyDataOperater returns(bool) {
        ccyInfo[_pid].lpAddress = _lpAddress;
        ccyInfo[_pid].tokenAddress = _tokenAddress;
        ccyInfo[_pid].baseDecimal = _baseDecimal;
        return true;
    }
    
    struct RecoveryRecord {
        address account;
        uint256 tokenId;
        uint256 recoveryMoney;
        uint256 tokenPrice;
        uint256 tokenNum;
        uint256 recoveryTime;
    }
    mapping(uint256 => RecoveryRecord) public recoveryRecords;
    function addRecords(address _account, uint256 _tokenId, uint256 _recoveryMoney, uint256 _tokenPrice, uint256 _tokenNum) private {
        _recoveryIds.increment();
        uint256 newRecoveryIndex = _recoveryIds.current();
        
        recoveryRecords[newRecoveryIndex].account = _account;
        recoveryRecords[newRecoveryIndex].tokenId = _tokenId;
        recoveryRecords[newRecoveryIndex].recoveryMoney = _recoveryMoney;
        recoveryRecords[newRecoveryIndex].tokenPrice = _tokenPrice;
        recoveryRecords[newRecoveryIndex].tokenNum = _tokenNum;
        recoveryRecords[newRecoveryIndex].recoveryTime = block.timestamp;
    }
    
    function totalRecoveryRecord() public view returns(uint256 total) {
        total = _recoveryIds.current();
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
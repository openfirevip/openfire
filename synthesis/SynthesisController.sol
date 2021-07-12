pragma solidity ^0.8.0;

import "../common/DataOwnable.sol";
import "../hrc721/HrcData.sol";
import "../hrc721/HrcDataController.sol";
import "../hrc721/Earth.sol";
import "../mapdata/MapData.sol";
import "../mapdata/MapDataController.sol";
import "../hrc20/ofe.sol";
import "./SynthesisData.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../common/Pausable.sol";

contract SynthesisController is DataOwnable, Pausable, HrcData, MapData, SynthesisData {
    
    using Counters for Counters.Counter;
    Counters.Counter private _synthesisIndex;
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
        
    function checkSynthesis(uint256[] memory _tokenIds, uint256 _synthesisId) public view returns(bool) {
        // query synthesis map info
        MapDataController mapDataController = MapDataController(mapDataContract);
        MapBaseData memory mapBaseData = mapDataController.queryMapBaseData(_synthesisId);
        
        require(mapBaseData.flag, "Synthesis: synthesis map info isn't exists");
        require(mapBaseData.level != 1, "Synthesis: level is error");
        
        // check synthesis num
        bool flag = false;
        HrcDataController hrcDataController = HrcDataController(hrcDataContract);
        for(uint256 i = 0; i < mapBaseData.synthesisNeedToolsId.length; i++) {
            BaseData memory baseData = hrcDataController.queryBaseDataByTokenId(_tokenIds[i]);
            if(mapBaseData.synthesisNeedToolsId[i] != baseData.toolsId || !baseData.isDecorate) {
                flag = true;
                break;
            }
        }
        
        return !flag;
        
    }
    
    function synthesis(uint256[] memory _tokenIds, uint256 _synthesisToolsId) public whenNotPaused returns(bool) {
        
        require(checkSynthesis(_tokenIds, _synthesisToolsId), "Synthesis: Insufficient fragments");
        
        // transfer token 
        Earth earth = Earth(earthContract);
        for(uint256 i = 0; i < _tokenIds.length; i++) {
            earth.transferFrom(msg.sender, synthesisReceiveAddress, _tokenIds[i]);
        }
        
        // grant uper token
        // uint256 _synthesisTokenId = synthesisGrantMap(msg.sender, _synthesisToolsId);
        HrcDataController hrcData = HrcDataController(hrcDataContract);
        require(hrcData.addAllData(_synthesisToolsId, 0, 0, msg.sender), "add synthesis data fail");
        
        require(addSynthesisRecords(msg.sender, _synthesisToolsId, _tokenIds), "SynthesisData: synthesis add record fail");
        
        return true;
    }
    
    function addSynthesisRecords(address _synthesizer, uint256 _synthesisTokenId, uint256[] memory _tokenIds) private returns(bool) {
        synthesisRecords[_synthesisTokenId].synthesizer = _synthesizer;
        synthesisRecords[_synthesisTokenId].synthesisTokenId = _synthesisTokenId;
        synthesisRecords[_synthesisTokenId].tokenIds = _tokenIds;
        synthesisRecords[_synthesisTokenId].synthesisTime = block.timestamp;
        
        _synthesisIndex.increment();
        uint256 newSynthesisIndex = _synthesisIndex.current();
        synthesisTokenIds[newSynthesisIndex] = _synthesisTokenId;
        
        return true;
    }
    
    // ======================================= data =======================================
    address public hrcDataContract;
    address public earthContract;
    address public mapDataContract;
    function setContract(address _hrcDataContract, address _earthContract, 
                        address _mapDataContract) public onlyOwner returns(bool) {
		require(_hrcDataContract != address(0), "_hrcDataContract is a zero-address");
		require(_earthContract != address(0), "_earthContract is a zero-address");
		require(_mapDataContract != address(0), "_mapDataContract is a zero-address");
		
        hrcDataContract = _hrcDataContract;
        earthContract = _earthContract;
        mapDataContract = _mapDataContract;
        return true;
    }
    
    address public synthesisReceiveAddress;
    function setReceiveAddress(address _synthesisReceiveAddress) public onlyOwner returns(bool) {
		require(_synthesisReceiveAddress != address(0), "_synthesisReceiveAddress is a zero-address");
		
        synthesisReceiveAddress = _synthesisReceiveAddress;
        return true;
    } 
    
    // ===================================== interface ====================================
    function queryByIndex(uint256 _index) public view returns(SynthesisRecord memory synthesisRecord) {
        synthesisRecord = synthesisRecords[synthesisTokenIds[_index]];
    }
    
    function totalSynthesisRecord() public view returns(uint256 total) {
        total = _synthesisIndex.current();
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
pragma solidity ^0.8.0;

import "../common/DataOwnable.sol";
import "../hrc721/Earth.sol";
import "../hrc20/ofe.sol";
import "../common/Pausable.sol";
import "./TeamWorkDataController.sol";
import "./TeamWorkData.sol";
import "../mapdata/MapData.sol";
import "../mapdata/MapDataController.sol";
import "../hrc721/HrcData.sol";
import "../hrc721/HrcDataController.sol";

contract TeamWorkController is DataOwnable, Pausable, TeamWorkData, MapData, HrcData {
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
        
    function checkSendOrder(uint256 _hrcNo, uint64 _orderType, string memory _uploadName, uint64 _rewardCcy) public view returns(string memory) {
        // check token owner
        HrcDataController hrcDataInstance = HrcDataController(hrcDataContract);
        BaseData memory baseData = hrcDataInstance.queryBaseData(_hrcNo);
        
        address owner;
        if(!baseData.isDecorate || baseData.tokenId == 0) {
		    owner = hrcDataInstance.queryhrcNoAccountMapping(_hrcNo);
        } else {
            Earth earthInstance = Earth(earthContract);
            owner = earthInstance.ownerOf(baseData.tokenId);
        }
		if(msg.sender != owner) {
			return "1"; // token isn't owner
		}
		
		// check type
		if(_orderType != 0 && _orderType != 1) {
			return "2"; // order type error
		}
		
		// check upload name
		if(_orderType == 0 && keccak256(abi.encodePacked(_uploadName)) == keccak256(abi.encodePacked(""))) {
			return "3"; // upload name error
		}
		
// 		// check pay address
// 		if(_orderType == 0 && _rewardCcy != 0) {
// 			return "3"; // upload pay ccy error
// 		}
		
		TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
		address payAddress = teamWorkDataInstance.payCcyInfos(_rewardCcy);
		if(payAddress == address(0)) {
			return "5"; // pay address error
		}
		
		return "0";
    }
        
    function sendRenovateOrder(string memory _content, uint256 _hrcNo, uint256 _workingTime, 
								uint256 _reward, uint64 _rewardCcy) public whenNotPaused returns(bool) {
		string memory result = checkSendOrder(_hrcNo, 1, "", _rewardCcy);
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked("0")), result);
        
        // transfer collaborator fee
        TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
		address payAddress = teamWorkDataInstance.payCcyInfos(_rewardCcy);
        ofe ercInstance = ofe(payAddress);
        ercInstance.transferFrom(msg.sender, address(this), _reward);
		
		require(teamWorkDataInstance.accountSendRenovateOrder(msg.sender, 1, _content, _hrcNo, _workingTime, _reward, _rewardCcy), 
			"TeamWorkBaseControl: send renovate order fail!");
			
		return true;
    }
	
	function sendUploadOrder(uint256 _hrcNo, string memory _uploadName) public whenNotPaused returns(bool) {
		string memory result = checkSendOrder(_hrcNo, 0, _uploadName, 0);
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked("0")), result);
        
        // quantity upload fee
        HrcDataController hrcDataInstance = HrcDataController(hrcDataContract);
        uint256 toolsId = hrcDataInstance.queryToolsId(_hrcNo);
        
        MapDataController mapDataInstance = MapDataController(mapDataContract);
        MapBaseData memory mapBaseData = mapDataInstance.queryMapBaseData(toolsId);
		
        TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
        uint256 _reward = teamWorkDataInstance.uploadRate(mapBaseData.level);
        
        // transfer upload fee
		address payAddress = teamWorkDataInstance.payCcyInfos(0);
        ofe ercInstance = ofe(payAddress);
        ercInstance.transferFrom(msg.sender, receiveAddress, _reward);
        
		require(teamWorkDataInstance.accountSendUploadOrder(msg.sender, _hrcNo, _uploadName, _reward, 0), 
			"TeamWorkBaseControl: send upload order fail!");
			
		return true;
	}
	
	function checkOffShelf(uint256 _orderNo) public view returns(string memory) {
		TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
		OrderInfo memory order = teamWorkDataInstance.queryOrderInfo(_orderNo);
		
        // check order owner
        if(order.publisher != msg.sender) {
            return "1"; // order isn't owner
        }
        
        // check order state
        if(order.orderState != 0) {
            return "2"; // current order not allow operate
        }
        
		return "0";
    }
    
    function offShelf(uint256 _orderNo) public whenNotPaused returns(bool) {
        string memory result = checkOffShelf(_orderNo);
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked("0")), result);
        
        TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
        require(teamWorkDataInstance.accountChangeOrderState(_orderNo, 3), "TeamWork: off shelf fail");
        
        // transfer fee to collaborator
        OrderInfo memory order = teamWorkDataInstance.queryOrderInfo(_orderNo);
		address payAddress = teamWorkDataInstance.payCcyInfos(order.rewardCcy);
        ofe ercInstance = ofe(payAddress);
        ercInstance.transfer(order.publisher, order.reward);
		
        return true;
    }
	
	function checkReceivingOrder(uint256 _orderNo) public view returns(string memory) {
		TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
		OrderInfo memory order = teamWorkDataInstance.queryOrderInfo(_orderNo);
		
        // check order owner
        if(order.publisher == address(0)) {
            return "1"; // order isn't exists
        }
        
        // check order state
        if(order.orderState != 0) {
            return "2"; // current order not allow operate
        }
        
        // check is collaborator
        CollaboratorInfo memory collaboratorInfo = teamWorkDataInstance.queryCollaborator(msg.sender);
        if(collaboratorInfo.collaborator == address(0)) {
            return "3"; // collaborator isn't exists
        }
        if(collaboratorInfo.state != 0) {
            return "4"; // collaborator is disable
        }
        
		return "0";
    }
    
    function receivingOrder(uint256 _orderNo) public whenNotPaused returns(bool) {
        string memory result = checkReceivingOrder(_orderNo);
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked("0")), result);
        
        TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
        require(teamWorkDataInstance.receivingOrder(_orderNo, msg.sender), "TeamWork: receiving order fail");
        return true;
    }
	
	function checkReceivingCancel(uint256 _orderNo) public view returns(string memory) {
		TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
		OrderInfo memory order = teamWorkDataInstance.queryOrderInfo(_orderNo);
		
        // check order owner
        if(order.receiver != msg.sender) {
            return "1"; // current order not allow operate
        }
        
        // check order state
        if(order.orderState != 1) {
            return "2"; // current order not allow operate
        }
        
		return "0";
    }
    
    function receivingCancel(uint256 _orderNo) public whenNotPaused returns(bool) {
        string memory result = checkReceivingCancel(_orderNo);
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked("0")), result);
        
        TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
        require(teamWorkDataInstance.receivingCancel(_orderNo), "TeamWork: receiving order fail");
        return true;
    }
	
	function checkAccountConfirm(uint256 _orderNo) public view returns(string memory) {
		TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
		OrderInfo memory order = teamWorkDataInstance.queryOrderInfo(_orderNo);
		
        // check order owner
        if(msg.sender != order.publisher) {
            return "1"; // order isn't exists
        }
        
        // check order state
        if(order.orderState != 1) {
            return "2"; // current order not allow confirm
        }
        
        // check order order type
        if(order.orderType != 1) {
            return "3"; // current order type not allow confirm
        }
        
		return "0";
    }
    
    function accountConfirm(uint256 _orderNo) public whenNotPaused returns(bool) {
        string memory result = checkAccountConfirm(_orderNo);
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked("0")), result);
        
        TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
		OrderInfo memory order = teamWorkDataInstance.queryOrderInfo(_orderNo);
		
		// change order over
        require(teamWorkDataInstance.accountChangeOrderState(_orderNo, 2), "TeamWork: change order over fail");
		
		// transfer fee to collaborator
		address payAddress = teamWorkDataInstance.payCcyInfos(order.rewardCcy);
        ofe ercInstance = ofe(payAddress);
        ercInstance.transfer(order.receiver, order.reward);
        
        return true;
    }
    
    // ======================================= manage re fund =======================================
    function manageRefund(uint256 _orderNo) public onlyInterfaceOwner returns(bool) {
        TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
		OrderInfo memory order = teamWorkDataInstance.queryOrderInfo(_orderNo);
		
		// change order over
        require(teamWorkDataInstance.accountChangeOrderState(_orderNo, 4), "TeamWork: change order over fail");
		
		// transfer fee to collaborator
		address payAddress = teamWorkDataInstance.payCcyInfos(order.rewardCcy);
        ofe ercInstance = ofe(payAddress);
        ercInstance.transfer(order.publisher, order.reward);
        
        return true;
    }
    function manageConfirm(uint256 _orderNo) public onlyInterfaceOwner returns(bool) {
        TeamWorkDataController teamWorkDataInstance = TeamWorkDataController(teamWorkDataContract);
		OrderInfo memory order = teamWorkDataInstance.queryOrderInfo(_orderNo);
		
		// change order over
        require(teamWorkDataInstance.accountChangeOrderState(_orderNo, 2), "TeamWork: change order over fail");
		
		// transfer fee to collaborator
		address payAddress = teamWorkDataInstance.payCcyInfos(order.rewardCcy);
        ofe ercInstance = ofe(payAddress);
        ercInstance.transfer(order.receiver, order.reward);
        
        return true;
    }
    
    // ======================================= owner withdraw =======================================
    function manageWithdraw(address _token, address _to, uint256 _balance) public onlyOwner returns(bool) {
        ofe ercInstance = ofe(_token);
        ercInstance.transfer(_to, _balance);
        return true;
    }
    
    // ======================================= data =======================================
	event _setContract(address teamWorkDataContract, address hrcDataContract,
                        address mapDataContract, address earthContract);
	event _addOrUpdReceive(address receiveAddress);
						
    address public teamWorkDataContract;
    address public hrcDataContract;
    address public mapDataContract;
    address public earthContract;
    function setContract(address _teamWorkDataContract, address _hrcDataContract,
                        address _mapDataContract, address _earthContract) public onlyOwner returns(bool) {
        teamWorkDataContract = _teamWorkDataContract;
        hrcDataContract = _hrcDataContract;
        mapDataContract = _mapDataContract;
        earthContract = _earthContract;
		emit _setContract(_teamWorkDataContract, _hrcDataContract, _mapDataContract, _earthContract);
        return true;
    }
    
    address public receiveAddress;
    function addOrUpdReceive(address _receiveAddress) public onlyOwner returns(bool) {
		receiveAddress = _receiveAddress;	
		emit _addOrUpdReceive(_receiveAddress);
		return true;
	}
    // ===================================== interface ====================================
    
    
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
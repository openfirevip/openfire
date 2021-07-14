pragma solidity ^0.8.0;

import "../common/DataOwnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./TeamWorkData.sol";

contract TeamWorkDataController is DataOwnable, TeamWorkData {
    
    using SafeMath for uint256;
	
    using Counters for Counters.Counter;
    Counters.Counter private _orderNos;
	
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
    
	event _addOrUpdCcyInfo(uint64 index, address payAddress);
	event _updUploadRate(uint256 index, uint256 uploadRate);
	event _updUploadAddress(address uploadAddress);
    
    mapping(uint256 => OrderInfo) public orderInfos;
    mapping(address => CollaboratorInfo) public collaboratorInfos;
    
    mapping(uint64 => address) public payCcyInfos;
    mapping(uint256 => uint256) public uploadRate;
    address public uploadAddress;
    
    // ================================== orderInfo ================================== 
    function queryOrderInfo(uint256 _orderNo) public view returns(OrderInfo memory) {
        return orderInfos[_orderNo];
    }
    
    function totalOrderRecord() public view returns(uint256 total) {
        total = _orderNos.current();
    }
    
    function manageAddOrderInfos(address _publisher, uint64 _orderType, string memory _uploadName, 
								string memory _content, uint256 _hrcNo, uint256 _workingTime, 
								uint256 _reward, uint64 _rewardCcy) public onlyDataOperater returns(uint256) {
        return addOrderInfos(_publisher, _orderType, _uploadName, _content, _hrcNo, _workingTime, _reward, _rewardCcy);
    }
    
    function addOrderInfos(address _publisher, uint64 _orderType, string memory _uploadName, 
								string memory _content, uint256 _hrcNo, uint256 _workingTime, 
								uint256 _reward, uint64 _rewardCcy) private returns(uint256) {
        OrderInfo memory orderInfo = OrderInfo({
			publisher: _publisher,
			orderType: _orderType,
			uploadName: _uploadName,
			content: _content,
			hrcNo: _hrcNo,
			releaseTime: block.timestamp,
			workingTime: _workingTime,
			overTime: block.timestamp.add(_workingTime),
			reward: _reward,
			rewardCcy: _rewardCcy,
			orderState: 0,
			receiver: address(0)
		});
		
        _orderNos.increment();
        uint256 orderNo = _orderNos.current();
		
		orderInfos[orderNo] = orderInfo;
		return orderNo;
    }
    
    function manageUpdOrderInfos(uint256 _orderNo, address _publisher, uint64 _orderType, 
								string memory _content, uint256 _hrcNo, uint256 _workingTime, 
								uint256 _reward, uint64 _rewardCcy, 
								uint64 _orderState, address _receiver) public onlyDataOperater returns(bool) {
        return updOrderInfos(_orderNo, _publisher, _orderType, _content, _hrcNo, _workingTime, _reward, _rewardCcy, _orderState, _receiver);
    }
    
    function updOrderInfos(uint256 _orderNo, address _publisher, uint64 _orderType, 
								string memory _content, uint256 _hrcNo, uint256 _workingTime, 
								uint256 _reward, uint64 _rewardCcy, 
								uint64 _orderState, address _receiver) private returns(bool) {
        orderInfos[_orderNo].publisher = _publisher;
		orderInfos[_orderNo].orderType = _orderType;
		orderInfos[_orderNo].content = _content;
		orderInfos[_orderNo].hrcNo = _hrcNo;
		orderInfos[_orderNo].releaseTime = block.timestamp;
		orderInfos[_orderNo].workingTime = _workingTime;
		orderInfos[_orderNo].overTime = block.timestamp.add(_workingTime);
		orderInfos[_orderNo].reward = _reward;
		orderInfos[_orderNo].rewardCcy = _rewardCcy;
		orderInfos[_orderNo].orderState = _orderState;
		orderInfos[_orderNo].receiver = _receiver;
		return true;
    }
    
    // ================================== collaborator ================================== 
    function queryCollaborator(address _collaborator) public view returns(CollaboratorInfo memory) {
        return collaboratorInfos[_collaborator];
    }
    
    function addCollaborator(address _collaborator) public onlyDataOperater returns(bool) {
		require(_collaborator != address(0), "_collaborator is a zero-address");
		require(collaboratorInfos[_collaborator].collaborator == address(0), "_collaborator is exists");
		
        CollaboratorInfo memory collaboratorInfo = CollaboratorInfo({
            collaborator: _collaborator,
            state: 0,
            joinTime: block.timestamp
        });
        collaboratorInfos[_collaborator] = collaboratorInfo;
        return true;
    }
    
    function disableCollaborator(address _collaborator) public onlyDataOperater returns(bool) {
        collaboratorInfos[_collaborator].state = 1;
        return true;
    }
    
    function unDisableCollaborator(address _collaborator) public onlyDataOperater returns(bool) {
        collaboratorInfos[_collaborator].state = 0;
        return true;
    }
    
    // ================================== interface ================================== 
    function accountSendRenovateOrder(address _publisher, uint64 _orderType,
								string memory _content, uint256 _tokenId, uint256 _workingTime, 
								uint256 _reward, uint64 _rewardCcy) public onlyInterfaceOwner returns(bool) {
		addOrderInfos(_publisher, _orderType, "", _content, _tokenId, _workingTime, _reward, _rewardCcy);
		return true;
	}
	
	function accountSendUploadOrder(address _publisher, uint256 _tokenId, string memory _uploadName, uint256 _reward, uint64 _rewardCcy) public onlyInterfaceOwner returns(bool) {
		uint256 orderNo = addOrderInfos(_publisher, 0, _uploadName, "", _tokenId, 0, _reward, _rewardCcy);
		orderInfos[orderNo].orderState = 1;
		return true;
	}
	
	function accountUpdOrderInfos(uint256 _orderNo, uint64 _orderType, 
								string memory _content, uint256 _workingTime, 
								uint256 _reward, uint64 _rewardCcy) public onlyInterfaceOwner returns(bool) {
		orderInfos[_orderNo].orderType = _orderType;
		orderInfos[_orderNo].content = _content;
		orderInfos[_orderNo].releaseTime = block.timestamp;
		orderInfos[_orderNo].workingTime = _workingTime;
		orderInfos[_orderNo].overTime = block.timestamp.add(_workingTime);
		orderInfos[_orderNo].reward = _reward;
		orderInfos[_orderNo].rewardCcy = _rewardCcy;	
		return true;
	}
	
	function accountChangeOrderState(uint256 _orderNo, uint64 _orderState) public onlyInterfaceOwner returns(bool) {
		orderInfos[_orderNo].orderState = _orderState;	
		return true;
	}
	
	function receivingOrder(uint256 _orderNo, address _receiver) public onlyInterfaceOwner returns(bool) {
		orderInfos[_orderNo].orderState = 1;	
		orderInfos[_orderNo].receiver = _receiver;	
		orderInfos[_orderNo].overTime = block.timestamp+orderInfos[_orderNo].workingTime;	
		return true;
	}
	
	function receivingCancel(uint256 _orderNo) public onlyInterfaceOwner returns(bool) {
		orderInfos[_orderNo].orderState = 0;	
		orderInfos[_orderNo].receiver = address(0);	
		orderInfos[_orderNo].overTime = block.timestamp+orderInfos[_orderNo].workingTime;	
		return true;
	}
    
    // ================================== param ================================== 
    function addOrUpdCcyInfo(uint64 _index, address _payAddress) public onlyOwner returns(bool) {
		payCcyInfos[_index] = _payAddress;	
		emit _addOrUpdCcyInfo(_index, _payAddress);
		return true;
	}
	function updUploadRate(uint256 _index, uint256 _uploadRate) public onlyOwner returns(bool) {
	    uploadRate[_index] = _uploadRate;
		emit _updUploadRate(_index, _uploadRate);
	    return true;
	}
	function updUploadAddress(address _uploadAddress) public onlyOwner returns(bool) {
	    uploadAddress = _uploadAddress;
		emit _updUploadAddress(_uploadAddress);
	    return true;
	}
}


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

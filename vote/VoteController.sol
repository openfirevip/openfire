pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./Vote.sol";
import "./VoteOwnable.sol";

contract VoteController is Vote,VoteOwnable {

    using Counters for Counters.Counter;
    Counters.Counter _voteIds;
    
    constructor(address _snapshotOwner) {
        owner = msg.sender;
        snapshotOwner = _snapshotOwner;
    }
    
    function syncSnapshot(uint256 _voteNo, address _address, uint256 _num) public onlySnapshotOwner returns(bool) {
        if(snapshotMapping[_voteNo][_address] != 0) {
            totalMapping[_voteNo] = totalMapping[_voteNo]-snapshotMapping[_voteNo][_address] + _num;
        } else {
            totalMapping[_voteNo] += _num;
            snapshotAddressMapping[_voteNo].push(_address);
        }
        snapshotMapping[_voteNo][_address] = _num;
        return true;
    }
    
    function syncBatchSnapshot(uint256 _voteNo, address[] memory _address, uint256[] memory _num) public onlySnapshotOwner returns(bool) {
		if (_address.length != _num.length) {
			return false; 
		}

        for(uint256 i = 0; i < _address.length; i++) {
           if(snapshotMapping[_voteNo][_address[i]] != 0) {
                totalMapping[_voteNo] = totalMapping[_voteNo]-snapshotMapping[_voteNo][_address[i]] + _num[i];
            } else {
                totalMapping[_voteNo] += _num[i];
                snapshotAddressMapping[_voteNo].push(_address[i]);
            }
            snapshotMapping[_voteNo][_address[i]] = _num[i];
        }
        return true;
    }
    
    function querySnapshot(uint256 _voteNo, uint256 _index) public view returns(address, uint256, uint256) {
        return (snapshotAddressMapping[_voteNo][_index], 
                snapshotMapping[_voteNo][snapshotAddressMapping[_voteNo][_index]],
                snapshotAddressMapping[_voteNo].length);
    }
    
    function launchVote(string memory _content, uint256 _startTime, uint256 _expireTime) public onlyOwner returns(bool) {
        uint256 currentVoteId = _voteIds.current();
        _voteIds.increment();
        
        VoteEntity memory mTemp = VoteEntity({
            no: currentVoteId,
            content: _content,
            agreeNum: 0,
            agreeArr: new address[](0),
            refuseNum: 0,
            refuseArr: new address[](0),
            startTime: _startTime,
            expireTime: _expireTime
        });
        voteMapping[currentVoteId] = mTemp;
        
        return true;
    }
    
    function delVote(uint256 _voteNo) public onlyOwner returns(bool) {
        delete voteMapping[_voteNo];
        
        return true;
    }
    
    function updVote(uint256 _voteNo, string memory _content) public onlyOwner returns(bool) {
        VoteEntity storage temp = voteMapping[_voteNo];
        temp.content = _content;
        
        return true;                   
    }
    
    function updVoteTime(uint256 _voteNo, uint256 _startTime, uint256 _expireTime) public onlyOwner returns(bool) {
        VoteEntity storage temp = voteMapping[_voteNo];
        temp.startTime = _startTime;
        temp.expireTime = _expireTime;
        
        return true;                   
    }
    
    function changeState(uint256 _voteNo, uint256 _state) public onlyOwner returns(bool) {
        stateMapping[_voteNo] = _state;
        
        return true;
    }
    
    function queryVote(uint256 _voteNo) public view returns(uint256, string memory, uint256, uint256, uint256, uint256, uint256) {
        return (voteMapping[_voteNo].no, 
                voteMapping[_voteNo].content, 
                voteMapping[_voteNo].agreeNum, 
                voteMapping[_voteNo].refuseNum, 
                voteMapping[_voteNo].startTime, 
                voteMapping[_voteNo].expireTime,
                _voteIds.current());
    }
    
    function queryAgreeArr(uint256 _voteNo, uint256 _arrIndex) public view returns(address, uint256) {
        return (voteMapping[_voteNo].agreeArr[_arrIndex], voteMapping[_voteNo].agreeArr.length);
    }
    
    function queryRefuseArr(uint256 _voteNo, uint256 _arrIndex) public view returns(address, uint256) {
        return (voteMapping[_voteNo].refuseArr[_arrIndex], voteMapping[_voteNo].refuseArr.length);
    }
    
    function voteCheck(uint256 _voteNo) public view returns(uint256) {
        VoteEntity memory voteEntity = voteMapping[_voteNo];
        if(voteEntity.startTime == 0) {
            return 1;
        }
        if(stateMapping[_voteNo] != 1) {
            return 2;
        }
        uint256 isVote = accountVoteMapping[msg.sender][_voteNo];
        if(isVote != 0) {
            return 3;
        }
        
        if(block.timestamp < voteEntity.startTime) {
            return 4;
        }
        if(block.timestamp > voteEntity.expireTime) {
            return 5;
        }
        
        return 0;
    }
    
    function vote(uint256 _voteNo, bool _voteRes) public returns(bool) {
        VoteEntity storage voteEntity = voteMapping[_voteNo];
        require(voteEntity.startTime != 0, "vote no not exists");
        require(stateMapping[_voteNo] == 1, "vote sync snapshot is not read");
        uint256 isVote = accountVoteMapping[msg.sender][_voteNo];
        require(isVote == 0, "vote fail");
        
        require(block.timestamp >= voteEntity.startTime, "vote isn't start");
        require(block.timestamp <= voteEntity.expireTime, "vote is over");
        
        if(_voteRes) {
            voteEntity.agreeNum+=snapshotMapping[_voteNo][msg.sender];
            voteEntity.agreeArr.push(msg.sender);
            accountVoteMapping[msg.sender][_voteNo] = 1;
        } else {
            voteEntity.refuseNum+=snapshotMapping[_voteNo][msg.sender];
            voteEntity.refuseArr.push(msg.sender);
            accountVoteMapping[msg.sender][_voteNo] = 2;
        }
        
        return true;
    }
    
}
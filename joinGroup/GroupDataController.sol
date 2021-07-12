pragma solidity ^0.8.0;

import "./Group.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../common/DataOwnable.sol";

contract GroupDataController is Group, DataOwnable {
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
    
    using Counters for Counters.Counter;
    mapping(uint256 => Counters.Counter) _joinIds;
    
    // ================================================ data ================================================
    mapping(uint256 => mapping(uint256 => JoinGroup)) public groupMapping;        // systemType => group list
    mapping(address => mapping(uint256 => uint256[])) public userGroupMapping;    // account address => systemType => user join group array
    mapping(address => mapping(uint256 => Inviter)) inviterMapping;        // account address => systemType => user inviter group and join address
    mapping(address => mapping(uint256 => JoinTime)) public userJoinTimeMapping;  // account address => systemType => user join count records
    mapping(uint256 => uint256) public joinStartTime;
    mapping(uint256 => uint256) public joinSingleTime;
    
    mapping(address => mapping(uint256 => AccountIncome)) public accountIncomeMapping;  // account address => systemType => account income records
    
    mapping(uint256 => Param) public admissionFeeMapping;  // manage set group param
    bool public userDraw;      // is account draw rewards
    
    CarvesParam[] carvesParams; // carves param
    CarveTenParam[] carvesTenParams;
    uint256[] public tenuTotalValue;
    
    // ================================================ Interface query/operate data ================================================
    function newGroup(uint256 _systemNo, uint256 _currentGroupNo) public onlyInterfaceOwner returns(bool) {
        groupMapping[_systemNo][_currentGroupNo].joinNo = block.timestamp;
        groupMapping[_systemNo][_currentGroupNo].startTime = block.timestamp;
        return true;
    }
    function addGrouopJoinAndInviter(uint256 _systemNo, uint256 _currentGroupNo, 
                                        address _joinAddress, address inviterAddress) public onlyInterfaceOwner returns(bool) {
        groupMapping[_systemNo][_currentGroupNo].joinAddress.push(_joinAddress);
        groupMapping[_systemNo][_currentGroupNo].inviterAddress.push(inviterAddress);
        return true;
    }
    function addGrouopJoinAndInviterCard(uint256 _systemNo, uint256 _currentGroupNo, 
                                        uint256 _tokenId) public onlyInterfaceOwner returns(bool) {
        groupMapping[_systemNo][_currentGroupNo].tokenIds.push(_tokenId);
        return true;
    }
    function updGroupStartTime(uint256 _systemNo, uint256 _currentGroupNo) public onlyInterfaceOwner returns(bool) {
        groupMapping[_systemNo][_currentGroupNo].startTime = block.timestamp;
        return true;
    }
    function changeGroupFull(uint256 _systemNo, uint256 _currentGroupNo) public onlyInterfaceOwner returns(bool) {
        groupMapping[_systemNo][_currentGroupNo].isFull = true;
        return true;
    }
    function overGroup(uint256 _systemNo, uint256 _currentGroupNo, uint256 _winerIndex) public onlyInterfaceOwner returns(bool) {
        groupMapping[_systemNo][_currentGroupNo].winnerAddress = groupMapping[_systemNo][_currentGroupNo].joinAddress[_winerIndex];
        groupMapping[_systemNo][_currentGroupNo].isDraw = true;
        groupMapping[_systemNo][_currentGroupNo].endTime = block.timestamp;
        return true;
    }
    
    
    function addUserGroup(address _account, uint256 _systemNo, uint256 _currentGroupNo) public onlyInterfaceOwner returns(bool) {
        userGroupMapping[_account][_systemNo].push(_currentGroupNo);
        return true;
    }
        
    
    function queryInviter(address _account, uint256 _systemNo) public view returns(Inviter memory inviter) {
        inviter = inviterMapping[_account][_systemNo];
    }
    function addInviter(address _account, uint256 _systemNo, address _inviteAddress, uint256 _currentGroupNo) public onlyInterfaceOwner returns(bool) {
        inviterMapping[_account][_systemNo].inviterAddress.push(_inviteAddress);
        inviterMapping[_account][_systemNo].groupNo.push(_currentGroupNo);
        return true;
    }
    
    function increaseUserJoinTime(address _account, uint256 _systemNo) public onlyInterfaceOwner returns(bool) {
        userJoinTimeMapping[_account][_systemNo].inviteCount += 1;
        return true;
    }
    function reduceUserJoinCount(address _account, uint256 _systemNo) public onlyInterfaceOwner returns(bool) {
        userJoinTimeMapping[_account][_systemNo].joinCount -= 1;
        return true;
    }
    function reduceUserInviteCount(address _account, uint256 _systemNo) public onlyInterfaceOwner returns(bool) {
        userJoinTimeMapping[_account][_systemNo].inviteCount -= 1;
        return true;
    }
    function resetUserJoinCount(address _account, uint256 _systemNo, uint256 _joinDay, uint256 _joinCount) public onlyInterfaceOwner returns(bool) {
        userJoinTimeMapping[_account][_systemNo].joinDay = _joinDay;
        userJoinTimeMapping[_account][_systemNo].joinCount = _joinCount;
        userJoinTimeMapping[_account][_systemNo].inviteCount = 0;
        return true;
    }
    
    function dealInviteJoinTime(address _inviter, uint256 _systemNo) public onlyInterfaceOwner returns(bool) {
        // current run days
        uint256 currentRunDays = (block.timestamp-joinStartTime[_systemNo])/joinSingleTime[_systemNo];
        // account run days more current, update time/count
        if(currentRunDays > userJoinTimeMapping[_inviter][_systemNo].joinDay) {
            userJoinTimeMapping[_inviter][_systemNo].joinCount = admissionFeeMapping[_systemNo].joinCountLimit;
            userJoinTimeMapping[_inviter][_systemNo].inviteCount = 1;
        } else {
            userJoinTimeMapping[_inviter][_systemNo].inviteCount += 1;
        }
        userJoinTimeMapping[_inviter][_systemNo].joinDay = currentRunDays;
        
        return true;
    }
    
    
    function increaseAccountJoinIncome(address _account, uint256 _systemNo, uint256 _joinReward) public onlyInterfaceOwner returns(bool) {
        accountIncomeMapping[_account][_systemNo].joinReward += _joinReward;
        return true;
    }
    function increaseAccountInviteIncome(address _account, uint256 _systemNo, uint256 _inviteReward) public onlyInterfaceOwner returns(bool) {
        accountIncomeMapping[_account][_systemNo].inviterReward += _inviteReward;
        return true;
    }
    
    
    function queryCavesParam(uint256 _systemNo) public view returns(CarvesParam memory carvesTenParam) {
        carvesTenParam = carvesParams[_systemNo];
    }
    
    
    function increaseTenuTotalValue(uint256 _systemNo, uint256 _increaseValue) public onlyInterfaceOwner returns(bool) {
        tenuTotalValue[_systemNo] += _increaseValue;
        return true;
    }
    function setTenuTotalValue(uint256 _systemNo, uint256 _value) public onlyInterfaceOwner returns(bool) {
        tenuTotalValue[_systemNo] = _value;
        return true;
    }
    
    
    function getJoinIds(uint256 _systemNo) public onlyInterfaceOwner view returns(uint256) {
        return _joinIds[_systemNo].current();
    }
    function increaseJoinIds(uint256 _systemNo) public onlyInterfaceOwner returns(bool) {
        _joinIds[_systemNo].increment();
        return true;
    }
    
    // =================================================== get param ===================================================
    function getadmissionFee(uint256 _systemNo) public view returns(Param memory param) {
        param = admissionFeeMapping[_systemNo];
    }
    function getGroupMapping(uint256 _systemNo, uint256 _currentGroupNo) public view returns(JoinGroup memory currentGroup) {
        currentGroup = groupMapping[_systemNo][_currentGroupNo];
    }
    function getJoinTimeMapping(address _account, uint256 _systemNo) public view returns(JoinTime memory joinTime) {
        joinTime = userJoinTimeMapping[_account][_systemNo];
    }
    function getUserDraw() public view returns(bool) {
        return userDraw;
    }
    function getJoinStartTime(uint256 _systemNo) public view returns(uint256) {
        return joinStartTime[_systemNo];
    }
    function getJoinSingleTime(uint256 _systemNo) public view returns(uint256) {
        return joinSingleTime[_systemNo];
    }
    function getCarvesParams(uint256 _systemNo) public view returns(CarvesParam memory carvesParam) {
        carvesParam = carvesParams[_systemNo];
    }
    function getUserGroupMapping(address _account, uint256 _systemNo, uint256 _index) public view 
            returns(uint256 userGroupIds, uint256 total) {
        total = userGroupMapping[_account][_systemNo].length;
        userGroupIds = userGroupMapping[_account][_systemNo][_index];
    }
    function getUserInviteGroupList(address _account, uint256 _systemNo, uint256 _index) public view returns(address, uint256, uint256) {
        Inviter memory inviter = inviterMapping[_account][_systemNo];
        return (inviter.inviterAddress[_index], inviter.groupNo[_index], inviter.inviterAddress.length);
    }
    function getAccountIncomeMapping(address _account, uint256 _systemNo) public view returns(AccountIncome memory) {
        return accountIncomeMapping[_account][_systemNo];
    }
    function gettenuTotalValue(uint256 _systemNo) public view returns(uint256) {
        return tenuTotalValue[_systemNo];
    }
    function getCarvesTenParams(uint256 _systemNo) public view returns(CarveTenParam memory carveTenParam) {
        carveTenParam = carvesTenParams[_systemNo];
    }
    
    
    
    // ================================================ Manage set param ================================================
	event _setAdmissionFee(uint256 no, uint256 payType, address payTokenAddress, 
                        address carvesTokenAddress, uint256 deposit, uint256 admissionFee, 
                        uint256 groupCountLimit, uint256 joinCountLimit, uint256 timeLimit,
                        uint256 joinReward, uint256 inviterReward, address algorithmAddress);
						
	event _setCarvesAccountParam(uint256 systemNo, uint256[] carvesAccountRatio, 
						uint256[] carvesAccountBaseDecimal, address[] carvesAccountAddress);
						
	event _setCarveTenParam(uint256 systemNo, address[] tenuAddress, uint256[] tenuValues);
	
    function setJoinIds(uint256 _systemNo, uint256 _joinId) public onlyDataOperater {
        for(uint256 i = 0; i < _joinId; i++) {
            _joinIds[_systemNo].increment();
        }
    } 
    
    function addOrUpdJoinStartTime(uint256 _systemNo, uint256 _joinStartTime) public onlyDataOperater {
        joinStartTime[_systemNo] = _joinStartTime;
    }
    
    function addOrUpdJoinSingleTime(uint256 _systemNo, uint256 _joinSingleTime) public onlyDataOperater {
        joinSingleTime[_systemNo] = _joinSingleTime;
    }
    
    function setAdmissionFee(uint256 _no, uint256 _payType, address _payTokenAddress, 
                        address _carvesTokenAddress, uint256 _deposit, uint256 _admissionFee, 
                        uint256 _groupCountLimit, uint256 _joinCountLimit, uint256 _timeLimit,
                        uint256 _joinReward, uint256 _inviterReward, address _algorithmAddress) public onlyDataOperater {
        admissionFeeMapping[_no] = Param(_no, _payType, _payTokenAddress, _carvesTokenAddress, _deposit, _admissionFee, 
                                    _groupCountLimit, _joinCountLimit, _timeLimit,
                                    _joinReward, _inviterReward, _algorithmAddress, true);
									
		emit _setAdmissionFee(_no, _payType, _payTokenAddress, 
								_carvesTokenAddress, _deposit, _admissionFee, 
								_groupCountLimit, _joinCountLimit, _timeLimit, 
								_joinReward, _inviterReward, _algorithmAddress);
    }
    function systemIsOpenAndUserDraw(uint256 _systemNo, bool _isOpen, bool _userDraw) public onlyDataOperater {
        admissionFeeMapping[_systemNo].isOpen = _isOpen;
        userDraw = _userDraw;
    }
    
    function getCarvesParam(uint256 _systemNo) public view onlyDataOperater returns(CarvesParam memory) {
        return carvesParams[_systemNo];
    }
     function setCarvesAccountParam(
         uint256 _systemNo, uint256[] memory _carvesAccountRatio, uint256[] memory _carvesAccountBaseDecimal, address[] memory _carvesAccountAddress
    ) public onlyDataOperater returns(bool) {
        if(_systemNo == 999) {
            carvesParams.push(CarvesParam({
                carvesAccountRatio: _carvesAccountRatio, 
                carvesAccountAddress: _carvesAccountAddress, 
                carvesAccountBaseDecimal: _carvesAccountBaseDecimal
            }));
         } else {
            carvesParams[_systemNo].carvesAccountRatio = _carvesAccountRatio;
            carvesParams[_systemNo].carvesAccountAddress = _carvesAccountAddress;
            carvesParams[_systemNo].carvesAccountBaseDecimal = _carvesAccountBaseDecimal;
         }
		 
		emit _setCarvesAccountParam(_systemNo, _carvesAccountRatio, _carvesAccountBaseDecimal, _carvesAccountAddress);
        return true;
    }
    function delCarvesAccountParam(uint256 _systemNo) public onlyDataOperater returns(bool) {
        delete carvesParams[_systemNo];
        return true;
    }
    
    function getCarveTenParam(uint256 _systemNo) public view onlyDataOperater returns(
        address[] memory tenuAddress, 
        uint256[] memory tenuValues) {
            tenuAddress = carvesTenParams[_systemNo].tenuAddress;
            tenuValues = carvesTenParams[_systemNo].tenuValues;
    }
    
    function setCarveTenParam(uint256 _systemNo, address[] memory _tenuAddress, uint256[] memory _tenuValues) public onlyDataOperater returns (bool) {
        if(_systemNo == 999) {
            carvesTenParams.push(CarveTenParam({
                tenuAddress: _tenuAddress, 
                tenuValues: _tenuValues
            }));
            tenuTotalValue.push(0);
         } else {
            carvesTenParams[_systemNo].tenuAddress = _tenuAddress;
            carvesTenParams[_systemNo].tenuValues = _tenuValues;
         }
		 
		emit _setCarveTenParam(_systemNo, _tenuAddress, _tenuValues);
        return true;
    }
    
    function delCarveTenParam(uint256 _systemNo) public onlyDataOperater returns(bool) {
        delete carvesTenParams[_systemNo];
        return true;
    }
}
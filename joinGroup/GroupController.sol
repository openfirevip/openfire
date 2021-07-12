pragma solidity ^0.8.0;

import "./Group.sol";
import "./GroupOwnable.sol";
import "./GroupDataController.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "../account/AccountController.sol";
import "../miner/MinerController.sol";
import "./OpenAlgorithm.sol";

contract GroupController is Group, GroupOwnable {
    
    OpenAlgorithm openAlgorithm;
    AccountController accountController;
    MinerController minerController;
    GroupDataController groupDataController;
    
    constructor(address _withdrawManager, address _drawPrizeManager, address _paramManager) GroupOwnable(_withdrawManager, _drawPrizeManager, _paramManager) {}
    
    event JoinGroupEvent(uint256 systemType, address account, uint256 joinTime);
    event DrawPrizeEvent(uint256 systemType, address winner, uint256 prizeTime);
    
    /**
     * @dev User join group
     **/
    function join(uint256 _systemType) public returns(bool) {
        
        Param memory param = groupDataController.getadmissionFee(_systemType);
        require(param.payTokenAddress != address(0), "GroupController: join method _no not exists");
        require(param.payType == 0, "GroupCardController: pay type error");
        require(param.isOpen, "-1001");
        
        accountController = AccountController(accountContractAddress);
        (address accountAddress, address uperAddressArr, bool isTeamLeader, bool isOpen) = accountController.getAccountInfo(_systemType, msg.sender);
        require(param.isOpen && isOpen, "Group: current systemType is suspend");
        require(accountAddress != address(0), "GroupController: join method getAccountInfo fail, please register first");
        address invaiter = uperAddressArr;
        
        // Check current group is full
        uint256 currentGroupId = groupDataController.getJoinIds(_systemType);
        if(currentGroupId == 0) {
            groupDataController.newGroup(_systemType, currentGroupId);
        }
        JoinGroup memory currentGroup = groupDataController.getGroupMapping(_systemType, currentGroupId);
        
        // Isn't full, check address exists
        if(currentGroup.joinAddress.length < param.groupCountLimit) {
            bool flag = true;
            for(uint i = 0; i < currentGroup.joinAddress.length; i++) {
                if(currentGroup.joinAddress[i] == msg.sender) {
                    flag = false;
                    break;
                }
            }
            // Is exists
            require(flag, "GroupController: join method address is exists");
        }
        
        // Check is exists time
        JoinTime memory joinTime = groupDataController.getJoinTimeMapping(msg.sender, _systemType);
        dealJoinTime(_systemType, joinTime, param);
        joinTime = groupDataController.getJoinTimeMapping(msg.sender, _systemType);
        
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(param.payTokenAddress);
        bool success = token.transferFrom(msg.sender, address(this), param.deposit+param.admissionFee);
        require(success, "GroupController: join method join group fail");
        
        if(currentGroup.joinAddress.length == param.groupCountLimit) {
            // Is full
            groupDataController.changeGroupFull(_systemType, currentGroupId);
            if(groupDataController.getUserDraw()) {
                drawPrize(currentGroupId, _systemType);
            }
            
            groupDataController.increaseJoinIds(_systemType);
            currentGroupId = groupDataController.getJoinIds(_systemType);
            groupDataController.newGroup(_systemType, currentGroupId);
        }
        
        // GroupMapping join address record
        if(currentGroup.joinAddress.length == 0) {
            groupDataController.updGroupStartTime(_systemType, currentGroupId);
        }
        groupDataController.addGrouopJoinAndInviter(_systemType, currentGroupId, msg.sender, invaiter);
        
        // User join group id record
        groupDataController.addUserGroup(msg.sender, _systemType, currentGroupId);
        
        if(joinTime.inviteCount > 0) {
            groupDataController.reduceUserInviteCount(msg.sender, _systemType);
        } else {
            groupDataController.reduceUserJoinCount(msg.sender, _systemType);
        }
        
        // Share invaiter address and group id record
        if(invaiter != address(0)) {
            groupDataController.addInviter(invaiter, _systemType, msg.sender, currentGroupId);
            // invaiter join count increase
            groupDataController.dealInviteJoinTime(invaiter, _systemType);
        }
        
        
        currentGroup = groupDataController.getGroupMapping(_systemType, currentGroupId);
        if(currentGroup.joinAddress.length == param.groupCountLimit) {
            // Is full
            groupDataController.changeGroupFull(_systemType, currentGroupId);
            if(groupDataController.getUserDraw()) {
                drawPrize(currentGroupId, _systemType);
            }
            
            groupDataController.increaseJoinIds(_systemType);
            currentGroupId = groupDataController.getJoinIds(_systemType);
            groupDataController.newGroup(_systemType, currentGroupId);
        }
        
        emit JoinGroupEvent(_systemType, msg.sender, block.timestamp);
        return true;
    }
    function dealJoinTime(uint256 _systemType, JoinTime memory joinTime, Param memory param) private {
        // current run days
        uint256 currentRunDays = (block.timestamp-groupDataController.getJoinStartTime(_systemType))/groupDataController.getJoinSingleTime(_systemType);
        // account run days more current, update time/count
        if(currentRunDays > joinTime.joinDay) {
            groupDataController.resetUserJoinCount(msg.sender, _systemType, currentRunDays, param.joinCountLimit);
        }
        joinTime = groupDataController.getJoinTimeMapping(msg.sender, _systemType);
        require(joinTime.joinCount+joinTime.inviteCount > 0, "GroupController: join method time more than limit");
    }

    function drawPrizeManage(uint256 _joinId, uint256 _no) public onlyDrawPrizeOwner returns(bool) {
        return drawPrize(_joinId, _no);
    }
    
    function drawPrize(uint256 _joinId, uint256 _no) private returns(bool) {

        Param memory param = groupDataController.getadmissionFee(_no);
        JoinGroup memory currentGroup = groupDataController.getGroupMapping(_no, _joinId);
        if(currentGroup.joinAddress.length < param.groupCountLimit || currentGroup.isDraw) {
            return false;
        }
        
        // Set algorithm address
        openAlgorithm = OpenAlgorithm(param.algorithmAddress);
        
        uint256 winerIndex = openAlgorithm.rand(param.groupCountLimit);
        groupDataController.overGroup(_no, _joinId, winerIndex);
        
        //  Distribute reward
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(param.carvesTokenAddress);
        
        // Distribute join and inviter reward
        currentGroup = groupDataController.getGroupMapping(_no, _joinId);
        address[] memory groupAddress = currentGroup.joinAddress;
        for(uint256 i = 0; i < groupAddress.length; i++) {
            // join and didn't win reward
            if(groupAddress[i] != currentGroup.joinAddress[winerIndex]) {
                bool success1 = token.transfer(groupAddress[i], param.deposit+param.joinReward);
                require(success1, "GroupController: drawPrize method fail, distribute join reward fail");
                groupDataController.increaseAccountJoinIncome(groupAddress[i], _no, param.deposit+param.joinReward);
            }
            // inviter reward
            if(currentGroup.inviterAddress[i] != address(0)) {
                bool success2 = token.transfer(currentGroup.inviterAddress[i], param.inviterReward);
                require(success2, "GroupController: drawPrize method fail, distribute inviter reward");
                groupDataController.increaseAccountInviteIncome(currentGroup.inviterAddress[i], _no, param.inviterReward);
            }
        }
        
        // add miner
        minerController = MinerController(minerContractAddress);
        (bool success) = minerController.addMiner(_no, currentGroup.winnerAddress);
        require(success, "GroupController: drawPrize method addMiner fail");
        
        // carve
        token = ERC20PresetMinterPauser(param.carvesTokenAddress);
        
        CarvesParam memory carvesParam = groupDataController.getCarvesParams(_no);
        bool carveFeeSuccess = token.transfer(carvesParam.carvesAccountAddress[0], param.admissionFee*param.groupCountLimit);
                require(carveFeeSuccess, "GroupController: carve fee transfer fail");
        
         for(uint256 i = 2; i < carvesParam.carvesAccountAddress.length; i++) {
            bool carveMarketSuccess = token.transfer(carvesParam.carvesAccountAddress[i], 
                                            param.deposit
                                            *carvesParam.carvesAccountRatio[i]
                                            /carvesParam.carvesAccountBaseDecimal[i]);
            require(carveMarketSuccess, "GroupController: carve account transfer fail");
         }
        groupDataController.increaseTenuTotalValue(_no, param.deposit
                                *carvesParam.carvesAccountRatio[1]
                                /carvesParam.carvesAccountBaseDecimal[1]);                                
        
        emit DrawPrizeEvent(_no, currentGroup.joinAddress[winerIndex], block.timestamp);
        return true;
    }
    
    // ==================================== Get Group Param Data Start  ====================================
    
    // ==================================== Get Data Start  ====================================
   /**
    * @dev account 24h join group
    **/
    function accountTermJoinTime(uint256 _systemType) public view returns(uint256, uint256, uint256) {
        JoinTime memory joinTime = groupDataController.getJoinTimeMapping(msg.sender, _systemType);
        Param memory param = groupDataController.getadmissionFee(_systemType);
        
        // current run days
        uint256 joinDay;
        uint256 joinCount;
        uint256 currentRunDays = (block.timestamp-groupDataController.getJoinStartTime(_systemType))/groupDataController.getJoinSingleTime(_systemType);
        
        // account run days more current, update time/count
        if(currentRunDays > joinTime.joinDay) {
            joinDay = currentRunDays;
            joinCount = param.joinCountLimit;
        } else {
            joinDay = joinTime.joinDay;
            joinCount = joinTime.joinCount+joinTime.inviteCount;
        }
        return (joinDay, joinCount, param.joinCountLimit);
    }
    
    /**
     * @dev account is exists current group; true: not exists, false: exists
     **/
    function accountIsExistsCurrentGroup(uint256 _systemType) public view returns(bool) {
        uint256 currentGroupId = groupDataController.getJoinIds(_systemType);
        JoinGroup memory currentGroup = groupDataController.getGroupMapping(_systemType, currentGroupId);
        
        // check address exists
        bool flag = true;
        for(uint i = 0; i < currentGroup.joinAddress.length; i++) {
            if(currentGroup.joinAddress[i] == msg.sender) {
                flag = false;
                break;
            }
        }
        return flag;
    }
     
    /**
     * @dev User join group list
     **/
    function userGroupList(address _userAddress, uint256 _systemType, uint256 _index) public view 
            returns(uint256 userGroupIds, uint256 total) {
        return groupDataController.getUserGroupMapping(_userAddress, _systemType, _index);
    }
    
    /**
     * @dev Group list
     **/
     function groupList(uint256 _systemType, uint256 _joinId) public view returns(JoinGroup memory, bool) {
         JoinGroup memory joinGroup = groupDataController.getGroupMapping(_systemType, _joinId);
         bool flag = false;
         if(joinGroup.isDraw && joinGroup.winnerAddress==msg.sender) {
             flag = true;
         }
         return (joinGroup, flag);
     }
      
      /**
       * @dev User invite user and group list
       **/
       function userInviteGroupList(address _userAddress, uint256 _systemType, uint256 _index) public view returns(address, uint256, uint256) {
           return groupDataController.getUserInviteGroupList(_userAddress, _systemType, _index);
       }
       
       function accountIncome(uint256 _systemType) public view returns(AccountIncome memory) {
           return groupDataController.getAccountIncomeMapping(msg.sender, _systemType);
       }
       
       function getCurrentGroup(uint256 _systemType) public view returns(uint256) {
           return groupDataController.getJoinIds(_systemType);
       }
    // ==================================== Get Data End  ====================================
    
    // =============================== Manager Get Account Data ==============================
    function ManageGetTermJoinTime(uint256 _systemType, address _account) public view returns(uint256, uint256, uint256) {
        JoinTime memory joinTime = groupDataController.getJoinTimeMapping(_account, _systemType);
        Param memory param = groupDataController.getadmissionFee(_systemType);
        
        // current run days
        uint256 joinDay;
        uint256 joinCount;
        uint256 currentRunDays = (block.timestamp-groupDataController.getJoinStartTime(_systemType))/groupDataController.getJoinSingleTime(_systemType);
        
        // account run days more current, update time/count
        if(currentRunDays > joinTime.joinDay) {
            joinDay = currentRunDays;
            joinCount = param.joinCountLimit;
        } else {
            joinDay = joinTime.joinDay;
            joinCount = joinTime.joinCount+joinTime.inviteCount;
        }
        return (joinDay, joinCount, param.joinCountLimit);
    }

    /**
     * @dev account is exists current group; true: not exists, false: exists
     **/
    function ManageGetIsExistsCurrentGroup(uint256 _systemNo, address _account) public view returns(bool) {
        uint256 currentGroupId = groupDataController.getJoinIds(_systemNo);
        JoinGroup memory currentGroup = groupDataController.getGroupMapping(_systemNo, currentGroupId);
        
        // check address exists
        bool flag = true;
        for(uint i = 0; i < currentGroup.joinAddress.length; i++) {
            if(currentGroup.joinAddress[i] == _account) {
                flag = false;
                break;
            }
        }
        return flag;
    }
    
    function ManageGetAccountIncome(uint256 _systemNo, address _account) public view returns(AccountIncome memory) {
       return groupDataController.getAccountIncomeMapping(_account, _systemNo);
    }
    
    // ================================ Manager Operate Start ================================
    address public accountContractAddress;                 // account contract address
    address public minerContractAddress;                   // miner contract address
    address public groupDataContractAddress;                   // group data contract address
    function setContract(address _accountContractAddress, address _minerContractAddress, address _groupDataContractAddress) public onlyParamOwner returns(bool) {
        accountContractAddress = _accountContractAddress;
        minerContractAddress = _minerContractAddress;
        groupDataContractAddress = _groupDataContractAddress;
        
        groupDataController = GroupDataController(groupDataContractAddress);
        
        return true;
    }
     
    function ownerWithdraw(uint256 _no, uint256 _value) public onlyOwner returns(bool) {
        Param memory param = groupDataController.getadmissionFee(_no);
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(param.payTokenAddress);
        bool success = token.transfer(owner, _value);
        require(success, "GroupController: ownerWithdraw method transfer fail");
        return true;
    }
     
     
    function carvesTenFun(uint256 _no) public onlyParamOwner returns(bool) {
        Param memory param = groupDataController.getadmissionFee(_no);
        CarvesParam memory carvesParam = groupDataController.getCarvesParams(_no);
        CarveTenParam memory carvesTenParam = groupDataController.getCarvesTenParams(_no);
        
        uint256 count = param.deposit
                        *carvesParam.carvesAccountRatio[1]
                        /carvesParam.carvesAccountBaseDecimal[1];
        count = groupDataController.gettenuTotalValue(_no)/count;
        
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(param.carvesTokenAddress);
        for(uint256 i = 0; i < carvesTenParam.tenuAddress.length; i++) {
            address carvesAccount = carvesTenParam.tenuAddress[i];
            uint256 transferAccountVaue = carvesTenParam.tenuValues[i]*count;
            
            bool carveSuccess = token.transfer(carvesAccount, transferAccountVaue);
            require(carveSuccess, "MinerController: carve ten transfer fail");
        }
        groupDataController.setTenuTotalValue(_no, 0);
        return true;
    }
    // ================================= Manager Operate End =================================
    
}

pragma solidity ^0.8.0;

import "./AccountOwnable.sol";

contract AccountController is AccountOwnable {
    
    constructor(address _paramOwner) AccountOwnable(_paramOwner) {}
    
    struct Account {
        address accountAddress;
        address uperAddressArr;
        address[] inviteAddressArr;
        bool isTeamLeader;
    }
    
    mapping(address => mapping(uint256 => Account)) accountMapping;
    mapping(uint256 => address[]) systemAccountCountArr;
    mapping(uint256 => address[]) teamLeaderArr;
    
    event RegisterEvent(uint256 systemType, address account, address _uperAddress);
    event IsOpenEvent(uint256 systemType, bool isOpen);
    
    function register(uint256 _systemType, address _uperAddress) public returns(bool) {
        require(msg.sender != address(0), "Register: this msg.sender is not allow");
        
        LimitParam memory rules = registerRuleMapping[_systemType];
        require(rules.startTime != 0 && rules.isOpen, "Register: this systemType isn't exists");
        
        // check account is exists systemType
        require(accountMapping[msg.sender][_systemType].accountAddress == address(0), "Register: this account is in systemType");
        
        if(rules.isShareLimit) {
            require(accountMapping[_uperAddress][_systemType].accountAddress != address(0) || msg.sender == owner, "Register: this uperAddress isn't exists");
        } else {
            require(accountMapping[_uperAddress][_systemType].accountAddress != address(0) || _uperAddress == address(0), "Register: this uperAddress isn't exists");
        }
        if(rules.isCountLimit) {
            for(uint256 i = 0; i < rules.countLimitParam.length; i++) {
                // limit fixed value
                if(rules.countLimitParam[i].countLimitType == 0 
                    && block.timestamp >= rules.countLimitParam[i].startTime 
                    && block.timestamp <= rules.countLimitParam[i].endTime) {
                    require(systemAccountCountArr[_systemType].length < rules.countLimitParam[i].limitValue, "Register: current register count already expired - fixed limit");
                }
                
                // limit incremental value;
                if(rules.countLimitParam[i].countLimitType == 1 
                    && block.timestamp >= rules.countLimitParam[i].startTime 
                    && block.timestamp <= rules.countLimitParam[i].endTime) {
                    require(systemAccountCountArr[_systemType].length < rules.countLimitParam[i].startValue
                                    +rules.countLimitParam[i].startValue*(rules.countLimitParam[i].limitValue/100)
                                    *(((block.timestamp - rules.countLimitParam[i].startTime)/1 days)+1), "Register: current register count already expired - incremental limit");
                }
            }
        }
        
        systemAccountCountArr[_systemType].push(msg.sender);
        accountMapping[msg.sender][_systemType].accountAddress = msg.sender;
        accountMapping[msg.sender][_systemType].isTeamLeader = false;
        accountMapping[msg.sender][_systemType].uperAddressArr = _uperAddress;
        accountMapping[_uperAddress][_systemType].inviteAddressArr.push(msg.sender);
        
        emit RegisterEvent(_systemType, msg.sender, _uperAddress);
        return true;
        
    }
    
    // ============================= data show ===========================
    function getAccountInfo(uint256 _systemType, address _accountAddress) public view returns(address, address, bool, bool) {
        return (accountMapping[_accountAddress][_systemType].accountAddress, 
                accountMapping[_accountAddress][_systemType].uperAddressArr, 
                accountMapping[_accountAddress][_systemType].isTeamLeader,
                registerRuleMapping[_systemType].isOpen);
    }
    
    function getAccountInviteInfo(uint256 _systemType, address _accountAddress, uint256 _index) public view returns(address inviteAddress, uint256 total) {
        inviteAddress = accountMapping[_accountAddress][_systemType].inviteAddressArr[_index];
        total = accountMapping[_accountAddress][_systemType].inviteAddressArr.length;
    }
    
    function getSystemAddress(uint256 _systemType) public view returns(address[] memory) {
        return systemAccountCountArr[_systemType];
    }
    
    function getOneSystemAddress(uint256 _systemType, uint256 _index) public view returns(address account, uint256 total) {
        account = systemAccountCountArr[_systemType][_index];
        total = systemAccountCountArr[_systemType].length;
    }
    
    function isSatisfiedRegister(uint256 _systemType, address _uperAddress) public view returns(uint256) {
        LimitParam memory rules = registerRuleMapping[_systemType];
        
        if(!rules.isOpen) {
            return 0;
        }
        
        if(rules.isShareLimit) {
            if(accountMapping[_uperAddress][_systemType].accountAddress == address(0) && msg.sender != owner) {
                return 1;
            }
        } else {
            if(accountMapping[_uperAddress][_systemType].accountAddress == address(0) && _uperAddress != address(0)) {
                return 2;
            }
        }
        if(rules.isCountLimit) {
            for(uint256 i = 0; i < rules.countLimitParam.length; i++) {
                // limit fixed value
                if(rules.countLimitParam[i].countLimitType == 0 
                    && block.timestamp >= rules.countLimitParam[i].startTime 
                    && block.timestamp <= rules.countLimitParam[i].endTime) {
                    if(systemAccountCountArr[_systemType].length >= rules.countLimitParam[i].limitValue) {
                        return 3;
                    }
                }
                
                // limit incremental value;
                if(rules.countLimitParam[i].countLimitType == 1 
                    && block.timestamp >= rules.countLimitParam[i].startTime 
                    && block.timestamp <= rules.countLimitParam[i].endTime) {
                    if(systemAccountCountArr[_systemType].length >= rules.countLimitParam[i].startValue
                                    +rules.countLimitParam[i].startValue*(rules.countLimitParam[i].limitValue/100)
                                    *(((block.timestamp - rules.countLimitParam[i].startTime)/1 days)+1)) {
                                        return 4;
                                    }
                }
            }
        }
        return 5;
    }
    
    // ============================== param ==============================
    struct LimitParam {
        uint256 ruleNo;
        bool isCountLimit;
        CountLimitParam[] countLimitParam;
        
        bool isShareLimit;
        
        uint256 startTime;
        bool isOpen;
    }
    
    struct CountLimitParam {
        uint256 startTime; // s
        uint256 endTime; // s
        uint256 countLimitType;
        uint256 startValue;
        uint256 limitValue;
    }
    
    // systemType: 0: earth...
    mapping(uint256 => LimitParam) registerRuleMapping;
    
    /**
     * @dev open system and add register rules
     **/
    function registerSystemRulesCreate(
        uint256 _systemType,
        bool _isShareLimit,
        uint256[] memory _startTime, uint256[] memory _endTime, uint256[] memory _countLimitType, uint256[] memory _startValue, uint256[] memory _limitValue
    ) public onlyParamOwner returns(bool) {
        
        // open system register
        registerRuleMapping[_systemType].startTime = block.timestamp;
        registerRuleMapping[_systemType].isOpen = true;
        
        // set system share limit state (true: open; false: close;)
        shareLimitOpenOrClose(_systemType, _isShareLimit);
        
        // set system count limit (true: open; false: close;)
        if(_startTime.length > 0) {
            registerRuleMapping[_systemType].isCountLimit = true;
            for(uint256 i = 0; i < _startTime.length; i++) {
                countLimitAdd(_systemType, _startTime[i], _endTime[i], _countLimitType[i], _startValue[i], _limitValue[i]);
            }
        }
        
        return true;
    }
    
    /**
     * @dev close system
     **/
    function registerSystemCloseOrOpen(uint256 _systemType, bool _isOpen) public onlyParamOwner returns(bool) {
        registerRuleMapping[_systemType].isOpen = _isOpen;
        
        emit IsOpenEvent(_systemType, _isOpen);
        return true;
    }
    
    /**
     * @dev query register rules
     **/
    function registerSystemRulesGet(uint256 _systemType) public view onlyParamOwner returns(LimitParam memory) {
        return registerRuleMapping[_systemType];
    }
    
    /**
     * @dev open or close system register share limit
     **/
    function shareLimitOpenOrClose(uint256 _systemType, bool _isShareLimit) public onlyParamOwner returns(bool) {
        registerRuleMapping[_systemType].isShareLimit = _isShareLimit;
        return true;
    }
    
    /**
     * @dev add count limit
     **/
    function countLimitAdd(
        uint256 _systemType, uint256 _startTime, uint256 _endTime, uint256 _countLimitType, uint256 _startValue, uint256 _limitValue
    ) public onlyParamOwner returns(bool) {
        registerRuleMapping[_systemType].countLimitParam.push(CountLimitParam(_startTime, _endTime, _countLimitType, _startValue, _limitValue));
        return true;
    }
    
    
    /**
     * @dev update count limit
     **/
    function countLimitUpd(
        uint256 _systemType, uint256 _ruleNo, uint256 _startTime, uint256 _endTime, uint256 _countLimitType, uint256 _startValue, uint256 _limitValue
    ) public onlyParamOwner returns(bool) {
        registerRuleMapping[_systemType].countLimitParam[_ruleNo].startTime = _startTime;
        registerRuleMapping[_systemType].countLimitParam[_ruleNo].endTime = _endTime;
        registerRuleMapping[_systemType].countLimitParam[_ruleNo].countLimitType = _countLimitType;
        registerRuleMapping[_systemType].countLimitParam[_ruleNo].startValue = _startValue;
        registerRuleMapping[_systemType].countLimitParam[_ruleNo].limitValue = _limitValue;
        return true;
    }
    
    
    /**
     * @dev delete count limit
     **/
    function countLimitDel(uint256 _systemType, uint256 _ruleNo) public onlyParamOwner returns(bool) {
        delete registerRuleMapping[_systemType].countLimitParam[_ruleNo];
        return true;
    }
    
    /**
     * @dev open or close system register count limit
     **/
    function countLimitOpenOrClose(uint256 _systemType, bool _isCountLimit) public onlyParamOwner returns(bool) {
        registerRuleMapping[_systemType].isCountLimit = _isCountLimit;
        return true;
    }
    
    /**
     * @dev manage update account is team leader
     **/
     function teamLeaderUpdate(uint256 _systemType, address _accountAddress, bool _isTeamLeader) public onlyParamOwner returns(bool) {
         accountMapping[_accountAddress][_systemType].isTeamLeader = _isTeamLeader;
         if(_isTeamLeader) {
            teamLeaderArr[_systemType].push(_accountAddress);
         } else {
             for(uint256 i = 0; i < teamLeaderArr[_systemType].length; i++) {
                 if(teamLeaderArr[_systemType][i] == _accountAddress) {
                     delete teamLeaderArr[_systemType][i];
                     break;
                 }
             }
         }
         return true;
     }
    
    // ========================= manage account data show =========================
    
    function getAccountsBySystem(uint256 _systemType) public view returns(address[] memory) {
        return systemAccountCountArr[_systemType];
    }
    
    function getOneAccountsBySystem(uint256 _systemType, uint256 _index) public view returns(address account, uint256 total) {
        account = systemAccountCountArr[_systemType][_index];
        total = systemAccountCountArr[_systemType].length;
    }
    
    function getTeamLeader(uint256 _systemType) public view onlyInterfaceOwner returns(address[] memory) {
        return teamLeaderArr[_systemType];
    }
    
    function getOneTeamLeader(uint256 _systemType, uint256 _index) public view onlyInterfaceOwner returns(address account, uint256 total) {
        account = teamLeaderArr[_systemType][_index];
        total = teamLeaderArr[_systemType].length;
    }
    
}
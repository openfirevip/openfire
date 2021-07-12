pragma solidity ^0.8.0;

contract GroupOwnable {
    
    address public owner;
    address public paramManger;
    address public withdrawManager;
    address public drawPrizeManager;
    
    constructor(address _withdrawManager, address _drawPrizeManager, address _paramManger) {
        owner = msg.sender;
        withdrawManager = _withdrawManager;
        drawPrizeManager = _drawPrizeManager;
        paramManger = _paramManger;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier onlyWithdrawOwner() {
        require(msg.sender == withdrawManager || msg.sender == owner);
        _;
    }
    
    modifier onlyDrawPrizeOwner() {
        require(msg.sender == drawPrizeManager || msg.sender == owner);
        _;
    }
    
    modifier onlyParamOwner() {
        require(msg.sender == paramManger || msg.sender == owner);
        _;
    }
    
    function changeManager(address _cowner, address _cwithdrawManager, address _cdrawPrizeManager, address _cparamManger) 
        public onlyOwner returns(address, address, address, address) {
        if(_cowner != address(0)) {
            owner = _cowner;
        }
        if(_cwithdrawManager != address(0)) {
            withdrawManager = _cwithdrawManager;
        }
        if(_cdrawPrizeManager != address(0)) {
            drawPrizeManager = _cdrawPrizeManager;
        }
        if(_cparamManger != address(0)) {
            paramManger = _cparamManger;
        }
        
        return (owner,withdrawManager,drawPrizeManager, paramManger);
    }
    
}
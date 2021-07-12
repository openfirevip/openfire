pragma solidity ^0.8.0;

contract AccountOwnable {
    
    address public owner;
    address public paramOwner;
    address[] public interfaceOwner;
    
    constructor(address _paramOwner) {
        owner = msg.sender;
        paramOwner = _paramOwner;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "isn't owner");
        _;
    }
    
    modifier onlyParamOwner() {
        require(msg.sender == paramOwner || msg.sender == owner, "isn't param owner");
        _;
    }
    
    modifier onlyInterfaceOwner() {
        require(isInterfaceManager() || msg.sender == paramOwner || msg.sender == owner, "isn't show owner");
        _;
    }
    
    function isInterfaceManager() private view returns(bool flag) {
        flag = false;
        for(uint256 i = 0; i < interfaceOwner.length; i++) {
            if(msg.sender == interfaceOwner[i]) {
                flag = true;
                break;
            }
        }
    }
    
    function changeManager(address _cowner, address _cparamowner) 
        public onlyOwner returns(address, address) {
            
        if(_cowner != address(0)) {
            owner = _cowner;
        }
        
        if(_cparamowner != address(0)) {
            paramOwner = _cparamowner;
        }
        
        return (owner, paramOwner);
    }
    
    function changeInterfaceManager(address[] memory _interfaceOwner) public onlyParamOwner returns(bool) {
        interfaceOwner = _interfaceOwner;
        return true;
    }
    
}
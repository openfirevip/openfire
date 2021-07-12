pragma solidity ^0.8.0;

contract MinerOwnable {
    
    address public owner;
    address[] public minerOwner;
    address[] public minerStateOwner;
    address public cutDownOwner;
    address public paramOwner;
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier onlyMinerOwner() {
        bool flag = false;
        if (msg.sender == owner)
            flag = true;
        else {
            for(uint256 i = 0; i < minerOwner.length; i++) {
                if(msg.sender == minerOwner[i] ) {
                    flag = true;
                    break;
                }
            }
        }

        require(flag);
        _;
    }
    
    modifier onlyMinerStateOwner() {
        bool flag = false;
        if (msg.sender == owner)
            flag = true;
        else {
            for(uint256 i = 0; i < minerStateOwner.length; i++) {
                if(msg.sender == minerStateOwner[i] ) {
                    flag = true;
                    break;
                }
            }
        }

        require(flag);
        _;
    }
    
    modifier onlyCutDownOwner() {
        require(msg.sender == cutDownOwner || msg.sender == owner);
        _;
    }
    
    modifier onlyParamOwner() {
        require(msg.sender == paramOwner || msg.sender == owner);
        _;
    }
    
    function changeManager(address _cowner, address[] memory _cminerOwner, address[] memory _cminerStateOwner, address _ccutDownOwner, address _cparamOwner) 
        public onlyOwner returns(address, address[] memory, address[] memory, address) {
        
        if(_cowner != address(0)) {
            owner = _cowner;
        }
        
        if(_cminerOwner.length > 0) {
            minerOwner = _cminerOwner;
        }
        
        if(_cminerStateOwner.length > 0) {
            minerStateOwner = _cminerStateOwner;
        }
        
        if(_ccutDownOwner != address(0)) {
            cutDownOwner = _ccutDownOwner;
        }
        
        if(_cparamOwner != address(0)) {
            paramOwner = _cparamOwner;
        }

        return (owner, minerOwner, minerStateOwner, paramOwner);
    }
    
}
pragma solidity ^0.8.0;

/**
 * @title Ownable
 * @dev Contract authority control
 **/
contract DataOwnable {
    
    address public owner;
    address[] public dataOperater;
    address[] public interfaceOwner;
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) {
        owner = msg.sender;
        dataOperater = _dataOperater;
        interfaceOwner = _interfaceOwner;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier onlyDataOperater() {
        bool flag = false;
        if (msg.sender == owner)
            flag = true;
        else {
            for(uint256 i = 0; i < dataOperater.length; i++) {
                if(msg.sender == dataOperater[i] ) {
                    flag = true;
                    break;
                }
            }
        }

        require(flag);
        _;
    }
    
    modifier onlyInterfaceOwner() {
        bool flag = false;
        if (msg.sender == owner)
            flag = true;
        else {
            for(uint256 i = 0; i < interfaceOwner.length; i++) {
                if(msg.sender == interfaceOwner[i] ) {
                    flag = true;
                    break;
                }
            }
        }

        require(flag);
        _;
    }
    
    function changeManager(address _owner, address[] memory _dataOperater, address[] memory _interfaceOwner) 
        public onlyOwner returns(address) {
        if(_owner != address(0)) {
            owner = _owner;
        }
        
        if(_dataOperater.length > 0) {
            dataOperater = _dataOperater;
        }
        
        if(_interfaceOwner.length > 0) {
            interfaceOwner = _interfaceOwner;
        }
        
        return (owner);
    }
    
}
pragma solidity ^0.8.0;

contract VoteOwnable {
    
    address public owner;
    address public snapshotOwner;
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier onlySnapshotOwner() {
        require(msg.sender == snapshotOwner || msg.sender == owner);
        _;
    }
    
    function changeManager(address _cowner, address _csnapshotOwner) 
        public onlyOwner returns(address, address) {
        
        if(_cowner != address(0)) {
            owner = _cowner;
        }
        
        if(_csnapshotOwner != address(0)) {
            snapshotOwner = _csnapshotOwner;
        }

        return (owner, snapshotOwner);
    }
}
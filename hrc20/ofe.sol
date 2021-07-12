pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ofe is ERC20 {
    
    address public owner;
    
    constructor(string memory _name, string memory _symbol, uint256 _totalSupply) ERC20(_name, _symbol) {
        owner = msg.sender;
        _mint(msg.sender, _totalSupply*10**18);
    }
    
    function seo(uint256 _totalSupply) public onlyOwner returns(bool) {
        _mint(msg.sender, _totalSupply*10**18);
        return true;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    function changeManager(address _cowner) 
        public onlyOwner returns(address) {
        if(_cowner != address(0)) {
            owner = _cowner;
        }
        
        return (owner);
    }
}
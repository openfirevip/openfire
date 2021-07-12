pragma solidity ^0.8.0;

contract OpenAlgorithm {
    
    function rand(uint256 _length) public view returns(uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        return random%(_length-1);
    }
    
}
pragma solidity ^0.8.0;

contract Pausable {
    
    event Pause();
    event Unpause();

    bool public paused = false;


    
    /**
    * @dev modifier to allow actions only when the contract IS NOT paused
    */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }
	
    /**
    * @dev modifier to allow actions only when the contract IS paused
    */
    modifier whenPaused {
        require(paused);
        _;
    }
    
}
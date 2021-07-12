pragma solidity ^0.8.0;

contract TeamWorkData {
    
    struct OrderInfo {
        address publisher;
        uint64 orderType; // 0: upload; 1: draw;
        string uploadName;
        string content; // draw task requirement
        
		uint256 hrcNo;
        uint256 releaseTime;
        uint256 workingTime;
        uint256 overTime;
        
        uint256 reward;
        uint64 rewardCcy;
        
        uint64 orderState; // 0: wait; 1: received; 2: over; 3: off shelf; 4: manage refund;
        address receiver;
    }
    
    struct CollaboratorInfo {
        address collaborator;
        uint64 state; // 0: normal; 1: disable;
        uint256 joinTime;
    }
    
}
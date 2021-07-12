pragma solidity ^0.8.0;

contract Group {
    
    struct JoinGroup {
        uint256 joinNo;
        address[] joinAddress;
        address[] inviterAddress;
        uint256[] tokenIds;
        bool isFull;
        bool isDraw;
        address winnerAddress;
        uint256 startTime;
        uint256 endTime;
    }
    struct Inviter {
        address[] inviterAddress;
        uint256[] groupNo;
    }
    struct JoinTime {
        uint256 joinDay;
        uint256 joinCount;
        uint256 inviteCount;
    }
    
    
    // account income
    struct AccountIncome {
        address account;
        uint256 joinReward;
        uint256 inviterReward;
    }
    
    /**
     * @dev join group param
     **/
     struct Param {
         uint256 no;
         uint256 payType;
         address payTokenAddress;
         address carvesTokenAddress;
        //  uint256 decimal;
         uint256 deposit; // add decimal
         uint256 admissionFee; // add decimal
         
         uint256 groupCountLimit;
         uint256 joinCountLimit;
         uint256 timeLimit; // seconds
         
         uint256 joinReward;
         uint256 inviterReward;
         
         address algorithmAddress;
         
         bool isOpen;
     }
     
    // ============================ carves param ============================
    struct CarvesParam {
        uint256[] carvesAccountRatio;       // carves account and fee ratio
        uint256[] carvesAccountBaseDecimal; // carves account basedecimal
        address[] carvesAccountAddress;     // carves account recipt address
    }
    
    struct CarveTenParam {
        address[] tenuAddress;
        uint256[] tenuValues;
    }
    
}
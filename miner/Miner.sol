pragma solidity ^0.8.0;

contract Miner {
    
    // User miner records
    struct MinerRecords {
        address account;
        uint256 getTime;
        uint256 overTime;
        uint256 drawTime;
        uint256 runDays;
        uint256 drawReward;
        uint256 totalReward;
        uint256 num;
        bool isExpire;
        uint256 state; // 0: mining, 1: expire, 2:recovery
    }
    mapping(address => mapping(uint256 => MinerRecords[])) userMinerMapping;
    mapping(uint256 => uint256) minerCount;
    mapping(uint256 => MinerRecords[]) systemMinerMapping;
    
    // System param
    mapping(uint256 => uint256) termValid; // systemType => miner term (s) 
    mapping(uint256 => uint256) productTime; // systemType => miner product time (s,24h)
    struct MinerOutput {
        uint256 startTime;
        uint256 endTime;
        uint256 output;
    }
    mapping(uint256 => MinerOutput[]) minerOutputMapping; // systemType => miner output rules
    uint256[] minerOutputHalfNum;  // systemType => miner product num half
    uint256[] minerOutputHalfCycle; // systemType => half cycle
    
    mapping(uint256 => address) drawTokenAddressAndType; // systemType => withdrawTokenAddress
    struct BuyTokenParams {
        address tokenAddress;
        uint256 value;
    }
    mapping(uint256 => BuyTokenParams[]) buyMinerTokenParams; // systemType => buytokenAddress
    
    mapping(uint256 => uint256) public drawNum;
    mapping(uint256 => uint256) public actualProduct;
    
    // ============================ carves param ============================
    address accountContractAddress;         // account contract address
    address withdrawDirAddress;
    
    struct CarvesParam {
        uint256[] carvesAccountRatio;       // carves account and fee ratio
        uint256[] carvesAccountBaseDecimal; // carves account basedecimal
        address[] carvesAccountAddress;     // carves account recipt address
        uint256 inviterReward;              // invite buy miner reward
    }
    
    CarvesParam[] carvesParams; // carves param
    
    uint256[] tenuTotalValue;
    struct CarveTenParam {
        address[] tenuAddress;
        uint256[] tenuValues;
    }
    CarveTenParam[] carvesTenParams;
    
    
}
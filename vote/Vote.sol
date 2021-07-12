pragma solidity ^0.8.0;

contract Vote {
    
    struct VoteEntity {
        uint256 no;
        string content;
        uint256 agreeNum;
        address[] agreeArr;
        uint256 refuseNum;
        address[] refuseArr;
        uint256 startTime;
        uint256 expireTime;
    }
    mapping(uint256 => VoteEntity) public voteMapping;
    mapping(address => mapping(uint256 => uint256)) public accountVoteMapping;
    mapping(uint256 => address[]) public snapshotAddressMapping;
    mapping(uint256 => mapping(address => uint256)) public snapshotMapping;
    mapping(uint256 => uint256) public stateMapping;
    mapping(uint256 => uint256) public totalMapping;
    
}
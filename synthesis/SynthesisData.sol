pragma solidity ^0.8.0;

contract SynthesisData {
    
    struct SynthesisRecord {
        address synthesizer;
        uint256 synthesisTokenId;
        uint256[] tokenIds;
        uint256 synthesisTime;
    }
    mapping(uint256 => SynthesisRecord) public synthesisRecords; // tokenId => SynthesisRecord
    mapping(uint256 => uint256) public synthesisTokenIds; // index => tokenId
    
}
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../common/DataOwnable.sol";

contract FireWorksCard is ERC721, DataOwnable {
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenId;
    
    string public baseURI;  
    
    event grantCardEvent(address to, uint256 tokenId);
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner, string memory _name, string memory _symbol)
    ERC721(_name, _symbol) DataOwnable(_dataOperater, _interfaceOwner){}
    
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return bytes(baseURI).length > 0
            ? baseURI
            : string(abi.encodePacked(baseURI, tokenId));
    }
    
    function totalSupply() public view returns (uint256 total) {
        total = _tokenId.current();
    }
    
    function setURI(string memory _baseURIStr) public onlyDataOperater returns(bool) {
        baseURI = _baseURIStr;
        return true;
    }
    
    /**
     * @dev TeamManager grant map media reward
     **/
    function grantCard(address _to) public onlyInterfaceOwner returns(uint256 tokenId, bool flag) {
        require(_to != address(0), "Earth: grantCard to the zero address");
        
        _tokenId.increment();
        uint256 newTokenId = _tokenId.current();
        
        _mint(_to, newTokenId);
        tokenId = newTokenId;
        flag = true;
        
        emit grantCardEvent(_to, newTokenId);
    }
    
}
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../common/DataOwnable.sol";

contract Earth is ERC721, DataOwnable {
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenId;
    
    string public baseURI;  
    
    event grantMapMediaEvent(address to, uint256 tokenId);
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner, string memory _name, string memory _symbol)
    ERC721(_name, _symbol) DataOwnable(_dataOperater, _interfaceOwner){}
    
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
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
    function grantMapMedia(address _to) public onlyInterfaceOwner returns(uint256 tokenId, bool flag) {
        require(_to != address(0), "Earth: grantMapMedia to the zero address");
        
        _tokenId.increment();
        uint256 newTokenId = _tokenId.current();
        
        _mint(_to, newTokenId);
        tokenId = newTokenId;
        flag = true;
        
        emit grantMapMediaEvent(_to, newTokenId);
    }
    
}
pragma solidity ^0.8.0;

import "../common/Pausable.sol";
import "../common/DataOwnable.sol";
import "./FireWorksCard.sol";
import "../hrc20/ofe.sol";

contract BuyCard is Pausable, DataOwnable {
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
    
    event buyCardEvent(address to, uint256 tokenId);
    
    function buy(uint256 _systemNo) public returns(uint256) {
        PayInfo memory payInfo = payTokenAddress[_systemNo];
        require(payInfo.payTokenAddress != address(0), "BuyCard: _systemNo isn't exists");
        
        ofe ofeInstance = ofe(payInfo.payTokenAddress);
        ofeInstance.transferFrom(msg.sender, payInfo.receiveAddress, payInfo.payAmount);
        
        // grant card 
        FireWorksCard fireWorksCardInstance = FireWorksCard(fireWorksCardContract);
        (uint256 tokenId, bool flag) = fireWorksCardInstance.grantCard(msg.sender);
        require(flag, "BuyCard: grant card fail");
        
        emit buyCardEvent(msg.sender, tokenId);
        
        return tokenId;
    }
    
    // ======================================= data =======================================
    address public fireWorksCardContract;
    function setContract(address _fireWorksCardContract) public onlyOwner returns(bool) {
		require(_fireWorksCardContract != address(0), "_fireWorksCardContract is a zero-address");
        fireWorksCardContract = _fireWorksCardContract;
        return true;
    }
    
    struct PayInfo {
        address payTokenAddress;
        address receiveAddress;
        uint256 payAmount;
    }
    mapping(uint256 => PayInfo) payTokenAddress; // systemNo => payTokenAddress
    function setPayTokenAddress(uint256 _systemNo, address _payAddress, address _receiveAddress, uint256 _payAmount) public onlyOwner {
        payTokenAddress[_systemNo] = PayInfo(_payAddress, _receiveAddress, _payAmount);
    }
    
    /**
    * @dev called by the owner to pause, triggers stopped state
    */
    function pause() public onlyOwner whenNotPaused returns (bool) {
        paused = true;
        emit Pause();
        return true;
    }
    
    /**
    * @dev called by the owner to unpause, returns to normal state
    */
    function unpause() public onlyOwner whenPaused returns (bool) {
        paused = false;
        emit Unpause();
        return true;
    }
}
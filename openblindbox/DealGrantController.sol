pragma solidity ^0.8.0;

import "../common/DataOwnable.sol";
import "../hrc721/Earth.sol";
import "../hrc721/HrcData.sol";
import "../hrc721/HrcDataController.sol";
import "../teamwork/TeamWorkData.sol";
import "../hrc20/ofe.sol";

contract DealGrantController is DataOwnable, HrcData, TeamWorkData {
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
        
    // ======================================= grant map and decorate =======================================        
    function grantMapAndDecorate(uint256 _orderNo, string memory _url) public onlyInterfaceOwner returns(bool) {
        // order info
        ITeamWorkData teamWorkDataInstance = ITeamWorkData(teamWorkDataContract);
        OrderInfo memory orderInfo = teamWorkDataInstance.queryOrderInfo(_orderNo);
        
        // transfer upload reward
        require(manageGrantUploadReward(_orderNo), "DealGrant: grant upload reward fail");
        
        HrcDataController hrcDataInstance = HrcDataController(hrcDataContract);
        BaseData memory baseData = hrcDataInstance.queryBaseData(orderInfo.hrcNo);
        
        uint256 tokenId = baseData.tokenId;
        // grant map
        if(baseData.tokenId == 0) {
            tokenId = grantMap(orderInfo.publisher);
        }
        
        // upload url
        HrcDataController hrcData = HrcDataController(hrcDataContract);
        hrcData.uploadUrl(tokenId, _url, orderInfo.publisher, orderInfo.hrcNo);
        
        return true;
    }
    
    function grantMap(address _to) private onlyInterfaceOwner returns(uint256) {
         Earth earth = Earth(earthContract);
        (uint256 tokenId, bool flag) = earth.grantMapMedia(_to);
        require(flag, "DealGrant: grant map fail");
        
        return tokenId;
    }
    
    
    // ======================================= manage grant upload reward =======================================
    function checkGrantUploadReward(uint256 _orderNo) public view returns(string memory) {
        ITeamWorkData teamWorkDataInstance = ITeamWorkData(teamWorkDataContract);
		OrderInfo memory order = teamWorkDataInstance.queryOrderInfo(_orderNo);
		
        if(order.publisher == address(0)) {
            return "1"; // order isn't exists
        }
        // check order state
        if(order.orderState != 1) {
            return "2"; // current order not allow confirm
        }
        
        // check order order type
        if(order.orderType != 0) {
            return "3"; // current order type not allow confirm
        }
        
        return "0";
    }
    function manageGrantUploadReward(uint256 _orderNo) public onlyInterfaceOwner returns(bool) {
        string memory result = checkGrantUploadReward(_orderNo);
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked("0")), result);
        
        ITeamWorkData teamWorkDataInstance = ITeamWorkData(teamWorkDataContract);
		OrderInfo memory order = teamWorkDataInstance.queryOrderInfo(_orderNo);
		
		// change order over
        require(teamWorkDataInstance.accountChangeOrderState(_orderNo, 2), "TeamWork: change order over fail");
		
		// transfer fee to collaborator
		address payAddress = teamWorkDataInstance.payCcyInfos(order.rewardCcy);
        ofe ercInstance = ofe(payAddress);
        ercInstance.transfer(teamWorkDataInstance.uploadAddress(), order.reward);
        
        return true;
    }
    
    // ======================================= owner withdraw =======================================
    function manageWithdraw(address _token, address _to, uint256 _balance) public onlyOwner returns(bool) {
		require(_token != address(0), "_token is a zero-address");
		require(_to != address(0), "_to is a zero-address");

        ofe ercInstance = ofe(_token);
        ercInstance.transfer(_to, _balance);
        return true;
    }
    
    // ======================================= data =======================================
    address public hrcDataContract;
    address public earthContract;
    address public teamWorkDataContract;
    function setContract(address _hrcDataContract, address _earthContract, 
                        address _teamWorkDataContract) public onlyOwner returns(bool) {
		require(_hrcDataContract != address(0), "_hrcDataContract is a zero-address");
		require(_earthContract != address(0), "_earthContract is a zero-address");
		require(_teamWorkDataContract != address(0), "_teamWorkDataContract is a zero-address");
        hrcDataContract = _hrcDataContract;
        earthContract = _earthContract;
        teamWorkDataContract = _teamWorkDataContract;
        return true;
    }
    
}

abstract contract ITeamWorkData is TeamWorkData {
    function queryOrderInfo(uint256 _orderNo) public view virtual returns(OrderInfo memory);
    function accountChangeOrderState(uint256 _orderNo, uint64 _orderState) public virtual returns(bool);
    mapping(uint64 => address) public payCcyInfos;
    address public uploadAddress;
}
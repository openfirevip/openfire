pragma solidity ^0.8.0;

import "./Miner.sol";
import "./MinerOwnable.sol";
import "../account/AccountController.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";


library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {

        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

contract MinerController is MinerOwnable, Miner {
    
    using SafeMath for uint256;
    
    AccountController accountController;
    
    constructor(address _accountContractAddress, address _withdrawDirAddress) MinerOwnable() {
        accountContractAddress = _accountContractAddress;
        withdrawDirAddress = _withdrawDirAddress;
    }
    
    event BuyMinerEvent(uint256 systemType, address account, uint256 buyType, uint256 num, uint256 buyTime);
    event DrawRewardEvent(uint256 systemType, address account, uint256 reward, uint256 drawTime);
    
    // ============================= account operate =============================
    function getMinerRecords(uint256 _systemType, uint256 _index) public view 
            returns(MinerRecords memory minerRecoeds, uint256 total) {
        total = userMinerMapping[msg.sender][_systemType].length;
        minerRecoeds = userMinerMapping[msg.sender][_systemType][_index];
    }
    function getMinerRecord(uint256 _systemType, uint256 _index) public view returns(MinerRecords memory) {
        return userMinerMapping[msg.sender][_systemType][_index];
    }
    
    function getOneMinerAndWaitDrawReward(uint256 _systemType, uint256 _index) public view returns(
        MinerRecords memory minerRecords, 
        uint256 waitDrawReward, uint256 runDays,
        uint256 total
    ) {
        minerRecords = userMinerMapping[msg.sender][_systemType][_index];
        (waitDrawReward, runDays) = queryOneMinerIncome(_systemType, msg.sender, _index);
        total = userMinerMapping[msg.sender][_systemType].length;
    }
    
    function accountDrawReward(uint256 _systemType) public returns(bool) {
        // Query account miner
        require(userMinerMapping[msg.sender][_systemType].length != 0, "MinerController: accountDrawReward method fail, account not exists miner");
        
        uint256 reward = 0;
        for(uint256 i = 0; i < userMinerMapping[msg.sender][_systemType].length; i++) {
            reward += quantityAccountDrawRewawrd(_systemType, i);
        }
        // require(reward != 0, "MinerController: accountDrawReward method reward is zero");
        if(reward == 0) {
            return false;
        }
        
        // Transfer token
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(drawTokenAddressAndType[_systemType]);
        bool success = token.transferFrom(withdrawDirAddress, msg.sender, reward);
        require(success, "MinerController: accountDrawReward method transfer token fail");
        drawNum[_systemType] += reward;
        
        emit DrawRewardEvent(_systemType, msg.sender, reward, block.timestamp);
        return true;
    }
    
    function queryOneMinerTotalIncome(uint256 _systemType, address _accountAddress, uint256 _index) public view returns(uint256, uint256) {
        uint256 totalReward = 0;
        uint256 totalRunDay = 0;
        MinerRecords storage minerRecords = userMinerMapping[_accountAddress][_systemType][_index];
        (totalReward, totalRunDay) = quantityCurRewardAndRunDayOne(_systemType, minerRecords.getTime, minerRecords.overTime, minerRecords);
        return (totalReward, totalRunDay);
    }
    
    function accountDrawOneReward(uint256 _systemType, uint256 _index) public returns(bool) {
        // Query account miner
        require(userMinerMapping[msg.sender][_systemType][_index].getTime != 0, "MinerController: accountDrawOneReward method fail, the miner not exists");
        
        uint256 reward = 0;
        // MinerRecords storage minerRecords = userMinerMapping[msg.sender][_systemType][_index];
        // if(!minerRecords.isExpire && minerRecords.state == 0) {
            
            reward = quantityAccountDrawRewawrd(_systemType, _index);
            
        // }
            
        // require(reward != 0, "MinerController: accountDrawReward method reward is zero");
        if(reward == 0) {
            return false;
        }
        
        // Transfer token
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(drawTokenAddressAndType[_systemType]);
        bool success = token.transferFrom(withdrawDirAddress, msg.sender, reward);
        require(success, "MinerController: accountDrawReward method transfer token fail");
        drawNum[_systemType] += reward;
        
        emit DrawRewardEvent(_systemType, msg.sender, reward, block.timestamp);
        return true;
    }
    
    function quantityAccountDrawRewawrd(uint256 _systemType, uint256 _index) private returns(uint256) {
        uint256 reward = 0;
        MinerRecords storage minerRecords = userMinerMapping[msg.sender][_systemType][_index];
        if(!minerRecords.isExpire) {
            // Quantity reward
            uint256 curReward = 0;
            uint256 curRunDay = 0;
            
            // Expire
            uint256 tempCurDrawTime = block.timestamp;
            if(block.timestamp >= minerRecords.overTime) {
               minerRecords.isExpire = true;
               minerRecords.state = 1;
               tempCurDrawTime = minerRecords.overTime;
            }
            
            // current draw num trigger half num
            // if(drawNum[_systemType] >= minerOutputHalfNum) {
            //     // update output rules
            //     for(uint j = 0; j < minerOutputMapping[_systemType].length; j++) {
            //         MinerOutput storage minerOutput = minerOutputMapping[_systemType][j];
            //         if(block.timestamp >= minerOutput.startTime && block.timestamp < minerOutput.endTime) {
            //             if(j+1 < minerOutputMapping[_systemType].length) {
            //                 minerOutputMapping[_systemType][j].endTime = block.timestamp;
            //                 minerOutputMapping[_systemType][j+1].startTime = block.timestamp;
            //             }
            //             break;
            //         }
            //     }
            // }
            
            uint256 curStartTime = minerRecords.drawTime;
            for(uint j = 0; j < minerOutputMapping[_systemType].length; j++) {
                
                MinerOutput storage minerOutput = minerOutputMapping[_systemType][j];
                
                if(curStartTime >= minerOutput.startTime && curStartTime < minerOutput.endTime) {
                    // Check tempCurDrawTime more than minerOutput endTime
                    if(tempCurDrawTime >= minerOutput.endTime) {
                        curReward += ((minerOutput.endTime - curStartTime)*100000) / productTime[_systemType] * minerOutput.output * minerRecords.num;
                        curRunDay += ((minerOutput.endTime - curStartTime)*100000) / productTime[_systemType];
                    
                        curStartTime = minerOutput.endTime;
                    } else {
                        curReward += ((tempCurDrawTime - curStartTime)*100000) / productTime[_systemType] * minerOutput.output * minerRecords.num;
                        curRunDay += ((tempCurDrawTime - curStartTime)*100000) / productTime[_systemType];
                    }
                }
                
            }
            
            if(curReward > 0) {
                uint256 tempDrawTime = block.timestamp;
                uint256 outputEndTime = minerOutputMapping[_systemType][minerOutputMapping[_systemType].length-1].endTime;
                if(tempDrawTime > outputEndTime) {
                    tempDrawTime = outputEndTime;
                }
                minerRecords.drawTime = tempDrawTime; // minerRecords.drawTime + (curRunDay*productTime[_systemType]);// block.timestamp;
                minerRecords.runDays += curRunDay;
                minerRecords.drawReward += curReward/100000;
                minerRecords.totalReward += curReward/100000;
                reward = curReward/100000;
            }
        }
        
        return reward;
    }
    
    function queryAllMinerIncome(uint256 _systemType) public view returns(uint256) {
        uint256 reward = 0;
        
        for(uint256 i = 0; i < userMinerMapping[msg.sender][_systemType].length; i++) {
            (uint256 curReward, uint256 curRunDay) = quantityCurRewardAndRunDay(_systemType, msg.sender, i);
            if(curReward > 0) {
                reward += curReward;
            }
        }
        return reward;
    }
    
    function queryOneMinerIncome(uint256 _systemType, address _accountAddress, uint256 _index) public view returns(uint256, uint256) {

        (uint256 curReward, uint256 curRunDay) = quantityCurRewardAndRunDay(_systemType, _accountAddress, _index);
        
        return (curReward, curRunDay);
    }
    
    function quantityCurRewardAndRunDay(uint256 _systemType, address _accountAddress, uint256 _index) private view returns(uint256, uint256) {
        MinerRecords storage minerRecords = userMinerMapping[_accountAddress][_systemType][_index];
        // Quantity reward
        uint256 curReward = 0;
        uint256 curRunDay = 0;
        
        if(!minerRecords.isExpire) {
            
            // Expire
            uint256 tempCurDrawTime = block.timestamp;
            if(block.timestamp >= minerRecords.overTime) {
               tempCurDrawTime = minerRecords.overTime;
            }
                
            // current draw num trigger half num
            // uint256 tempPrice = 0;
            // if(drawNum[_systemType] >= minerOutputHalfNum) {
            //     // update output rules
            //     for(uint j = 0; j < minerOutputMapping[_systemType].length; j++) {
            //         MinerOutput storage minerOutput = minerOutputMapping[_systemType][j];
            //         if(block.timestamp >= minerOutput.startTime && block.timestamp < minerOutput.endTime) {
            //             if(j+1 < minerOutputMapping[_systemType].length) {
            //                 tempPrice = minerOutputMapping[_systemType][j+1].output;
            //             }
            //             break;
            //         }
            //     }
            // }
            
            uint256 curStartTime = minerRecords.drawTime;
            (curReward, curRunDay) = quantityCurRewardAndRunDayOne(_systemType, curStartTime, tempCurDrawTime, minerRecords);
            
        } else {
            curRunDay = minerRecords.runDays;
        }
        return (curReward, curRunDay);
    }
    
    // function a(uint256 start,uint256 end) public view returns(uint256 abc, uint256 bbb) {
    //     abc = ((start-end)*100000)/86400*1000000000000000000;
    //     bbb = abc / 100000;
    // }
    
    function quantityCurRewardAndRunDayOne(uint256 _systemType, uint256 curStartTime, uint256 tempCurDrawTime, MinerRecords memory minerRecords) private view returns(uint256, uint256) {
        uint256 curReward = 0;
        uint256 curRunDay = 0;                                    
        for(uint j = 0; j < minerOutputMapping[_systemType].length; j++) {
            
            MinerOutput storage minerOutput = minerOutputMapping[_systemType][j];
            
            if(curStartTime >= minerOutput.startTime && curStartTime < minerOutput.endTime) {
                // uint256 nowPrice = minerOutput.output;
                // if(tempPrice != 0 && tempPrice <= minerOutput.output && curStartTime >= block.timestamp) {
                //     nowPrice = tempPrice;
                // }
                
                // Check tempCurDrawTime more than minerOutput endTime
                if(tempCurDrawTime >= minerOutput.endTime) {
                    curReward += ((minerOutput.endTime - curStartTime)*100000) / productTime[_systemType] * minerOutput.output * minerRecords.num;
                    curRunDay += ((minerOutput.endTime - curStartTime)*100000) / productTime[_systemType];
                    
                    curStartTime = minerOutput.endTime;
                } else {
                    curReward += ((tempCurDrawTime - curStartTime)*100000) / productTime[_systemType] * minerOutput.output * minerRecords.num;
                    curRunDay += ((tempCurDrawTime - curStartTime)*100000) / productTime[_systemType];
                }
                
            }
            
        }
        return (curReward/100000, curRunDay);
    }
    
    function buyMiner(uint256 _systemType, uint256 _buyType, uint256 _num) public returns(bool) {
        BuyTokenParams memory param = buyMinerTokenParams[_systemType][_buyType];
        require(param.tokenAddress != address(0), "this _buyTokenAddress not exists");
        
        accountController = AccountController(accountContractAddress);
        (address accountAddress, address uperAddressArr, bool isTeamLeader, bool isOpen) = accountController.getAccountInfo(_systemType, msg.sender);
        // require(accountAddress != address(0), "GroupController: join method getAccountInfo fail, please register first");
        require(isOpen, "Miner: current systemType is suspend");
        
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(param.tokenAddress);
        bool buyFeeSuccess = token.transferFrom(msg.sender, address(this), param.value.mul(_num));
        require(buyFeeSuccess, "MinerController: buyMiner method transfer token fail");
        
        MinerRecords[] storage temp = userMinerMapping[msg.sender][_systemType];
        uint256 term = block.timestamp+termValid[_systemType];
        MinerRecords memory mTemp = MinerRecords({
            account: msg.sender,
            getTime: block.timestamp,
            overTime: term,
            drawTime: block.timestamp,
            runDays: 0,
            drawReward: 0,
            totalReward: 0,
            num: _num,
            isExpire: false,
            state: 0
        });
        temp.push(mTemp);
        systemMinerMapping[_systemType].push(mTemp);
        
        require(carvesFun(_num, _systemType, uperAddressArr, param), "buyMiner: carve fail!");
         
        emit BuyMinerEvent(_systemType, msg.sender, _buyType, _num, block.timestamp);
        
        return true;
    }
    
    function carvesFun(uint256 _num, uint256 _systemType, address uperAddressArr, BuyTokenParams memory param) private returns(bool) {
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(param.tokenAddress);
        uint256 inviteNum = carvesParams[_systemType].inviterReward.mul(_num);
        if(uperAddressArr != address(0)) {
            bool inviteSuccess = token.transfer(uperAddressArr, inviteNum);
            require(inviteSuccess, "MinerController: buyMiner method fail, distribute invite reward fail");
        } else {
            address inviteAddress = carvesParams[_systemType].carvesAccountAddress[0];
            bool inviteSuccess = token.transfer(inviteAddress, inviteNum);
            require(inviteSuccess, "MinerController: buyMiner method fail, distribute not invite reward fail");
        }
        
        // carve
        CarvesParam memory carvesParam = carvesParams[_systemType];
        for(uint256 i = 2; i < carvesParam.carvesAccountAddress.length; i++) {
            address carvesAccount = carvesParam.carvesAccountAddress[i];
            uint256 transferAccountVaue = param.value.mul(carvesParam.carvesAccountRatio[i]);
            transferAccountVaue = transferAccountVaue.mul(_num).div(carvesParam.carvesAccountBaseDecimal[i]);
            
            bool carveSuccess = token.transfer(carvesAccount, transferAccountVaue);
            require(carveSuccess, "MinerController: carve account transfer fail");
        }
        
        uint256 minerCountTemp = minerCount[_systemType].add(_num);
        minerCount[_systemType] = minerCountTemp;
        tenuTotalValue[_systemType] += param.value.mul(carvesParam.carvesAccountRatio[1]).mul(_num).div(carvesParam.carvesAccountBaseDecimal[1]);
        
        return true;
    }
    
    function halfTime(uint256 _systemType, uint256 _now) public view returns(uint256 overTime) {
        for(uint j = 0; j < minerOutputMapping[_systemType].length; j++) {
            MinerOutput storage minerOutput = minerOutputMapping[_systemType][j];
            if(_now >= minerOutput.startTime && _now <= minerOutput.endTime) {
                overTime = minerOutput.endTime;
                break;
            }
        }
    }
    
    // ============================= manager operate =============================
    function addMiner(uint256 _systemType, address _accountAddress) public onlyMinerOwner returns(bool) {
        MinerRecords[] storage temp = userMinerMapping[_accountAddress][_systemType];
        MinerRecords memory mTemp = MinerRecords({
            account: _accountAddress,
            getTime: block.timestamp,
            overTime: block.timestamp+termValid[_systemType],
            drawTime: block.timestamp,
            runDays: 0,
            drawReward: 0,
            totalReward: 0,
            num: 1,
            isExpire: false,
            state: 0
        });
        temp.push(mTemp);
        systemMinerMapping[_systemType].push(mTemp);
        minerCount[_systemType]+=1;
        return true;
    }
    
    function minerManagerUpdMinerState(uint256 _systemType, address _accountAddress, uint256 _index, uint256 _state) public onlyMinerStateOwner returns(bool) {
        userMinerMapping[_accountAddress][_systemType][_index].state = _state;
        return true;
    }
    function minerManagerGetMinerRecord(uint256 _systemType, address _accountAddress, uint256 _index) public view 
            returns(MinerRecords memory minerRecoeds, uint256 total) {
        total = userMinerMapping[_accountAddress][_systemType].length;
        minerRecoeds = userMinerMapping[_accountAddress][_systemType][_index];
    }
    function minerManagerGetMinerRecords(uint256 _systemType, address _accountAddress) public view returns(MinerRecords[] memory) {
        return userMinerMapping[_accountAddress][_systemType];
    }
    function getSystemMinerRecord(uint256 _systemType, uint256 _index) public view 
            returns(MinerRecords memory minerRecoeds, uint256 total) {
        total = systemMinerMapping[_systemType].length;
        minerRecoeds = systemMinerMapping[_systemType][_index];
    }
    
    function manageRechargeToken(uint256 _systemType, uint256 _rechargeValue) public onlyOwner returns(bool) {
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(drawTokenAddressAndType[_systemType]);
        bool success = token.transferFrom(msg.sender, address(this), _rechargeValue);
        require(success, "MinerController: manageRechargeToken method recharge token fail");
        return true;
    }
    
    function manageWithdrawToken(uint256 _systemType, uint256 _withdrawValue, address _withdrawAddress) public onlyOwner returns(bool) {
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(drawTokenAddressAndType[_systemType]);
        bool success = token.transferFrom(withdrawDirAddress, _withdrawAddress, _withdrawValue);
        require(success, "MinerController: manageWithdrawToken method recharge token fail");
        return true;
    }
    
    function setContract(address _accountContractAddress, address _withdrawDirAddress) public onlyParamOwner returns(bool) {
        accountContractAddress = _accountContractAddress;
        withdrawDirAddress = _withdrawDirAddress;
        return true;
    }
    
    function setMinerTermAndProductTime(uint256 _systemType, uint256 _termValid, uint256 _productTime) public onlyParamOwner returns(bool) {
        termValid[_systemType] = _termValid;
        productTime[_systemType] = _productTime;
        return true;
    }
    
    function addMinerOutput(uint256 _systemType, uint256[] memory _startTime, 
                        uint256[] memory _endTime, uint256[] memory _output) public onlyParamOwner returns(bool) {
        MinerOutput[] storage minerOutput = minerOutputMapping[_systemType];
        for(uint256 i = 0; i < _startTime.length; i++) {
            minerOutput.push(MinerOutput({startTime: _startTime[i], endTime: _endTime[i], output: _output[i]}));
        }
        return true;
    }
    
    function updMinerOutput(uint256 _systemType, uint256 _index, uint256 _startTime, uint256 _endTime, uint256 _output) public onlyParamOwner returns(bool) {
        minerOutputMapping[_systemType][_index].startTime = _startTime;
        minerOutputMapping[_systemType][_index].endTime = _endTime;
        minerOutputMapping[_systemType][_index].output = _output;
        return true;
    }
    
    function delMinerOutput(uint256 _systemType, uint256 _index) public onlyParamOwner returns(bool) {
        delete minerOutputMapping[_systemType][_index];
        return true;
    }
    
    function setHalfNum(uint256 _index, uint256 _halfNum, uint256 _halfCycle) public onlyParamOwner returns(bool) {
        if(_index == 999) {
            minerOutputHalfNum.push(_halfNum);
            minerOutputHalfCycle.push(_halfCycle);
        } else {
            minerOutputHalfNum[_index] = _halfNum;
            minerOutputHalfCycle[_index] = _halfCycle;
        }
        return true;
    }
    
    function addOrUpdSystemTokenAddress(uint256 _systemType, address _tokenAddress) public onlyParamOwner returns(bool) {
        drawTokenAddressAndType[_systemType] = _tokenAddress;
        return true;
    }
    
    function delSystemTokenAddress(uint256 _systemType) public onlyParamOwner returns(bool) {
        delete drawTokenAddressAndType[_systemType];
        return true;
    }
    
    function getBuyMinerTokenParam(uint256 _systemType) public view onlyParamOwner returns(BuyTokenParams[] memory) {
        return buyMinerTokenParams[_systemType];
    }
    
    function addBuyMinerTokenParam(uint256 _systemType, address _buyTokenAddress, uint256 _deposit) public onlyParamOwner returns(bool) {
        buyMinerTokenParams[_systemType].push(BuyTokenParams({tokenAddress: _buyTokenAddress, value: _deposit}));
        return true;
    }
    
    function updBuyMinerTokenParam(uint256 _systemType, uint256 _index, address _buyTokenAddress, uint256 _deposit) public onlyParamOwner returns(bool) {
        buyMinerTokenParams[_systemType][_index].tokenAddress = _buyTokenAddress;
        buyMinerTokenParams[_systemType][_index].value = _deposit;
        return true;
    }
    
    function delBuyMinerParams(uint256 _systemType) public onlyParamOwner returns(bool) {
        delete buyMinerTokenParams[_systemType];
        return true;
    }
    
    // ========================= manage param show =========================
    function paramShowBySystemType(uint256 _systemType) public view onlyParamOwner returns(uint256, uint256, MinerOutput[] memory, address) {
        return (termValid[_systemType], productTime[_systemType], minerOutputMapping[_systemType], drawTokenAddressAndType[_systemType]);
    }
    
    function gettermValid(uint256 _systemType) public view onlyParamOwner returns(uint256) {
        return termValid[_systemType];
    }
    
    function getproductTime(uint256 _systemType) public view onlyParamOwner returns(uint256) {
        return productTime[_systemType];
    }
    
    function getminerOutputMapping(uint256 _systemType) public view onlyParamOwner returns(MinerOutput[] memory) {
        return minerOutputMapping[_systemType];
    }
    
    function getdrawTokenAddressAndType(uint256 _systemType) public view onlyParamOwner returns(address) {
        return drawTokenAddressAndType[_systemType];
    }
    
    function getDrawNum(uint256 _systemType) public view onlyParamOwner returns(uint256) {
        return drawNum[_systemType];
    }
    
    function getminerOutputHalfNum(uint256 _systemType) public view onlyParamOwner returns(uint256) {
        return minerOutputHalfNum[_systemType];
    }
    
    function getbuyMinerTokenParams(uint256 _systemType) public view onlyParamOwner returns(BuyTokenParams[] memory) {
        return buyMinerTokenParams[_systemType];
    }
    
    function getminerCount(uint256 _systemType) public view onlyParamOwner returns(uint256) {
        return minerCount[_systemType];
    }
    
    // ======================== cut down ======================
    function setActualProductParam(uint256 _systemType, uint256 _actualProduct) public onlyParamOwner returns(bool) {
        actualProduct[_systemType] = _actualProduct;
        return true;
    }
    
    function setActualProduct(uint256 _systemType) public onlyCutDownOwner returns(bool) {
        if(minerOutputMapping[_systemType][minerOutputMapping[_systemType].length-1].endTime < block.timestamp+1 days
            && minerOutputMapping[_systemType][minerOutputMapping[_systemType].length-1].output/2 != 0) {
            minerOutputMapping[_systemType].push(MinerOutput({
                            startTime: minerOutputMapping[_systemType][minerOutputMapping[_systemType].length-1].endTime, 
                            endTime: minerOutputMapping[_systemType][minerOutputMapping[_systemType].length-1].endTime+minerOutputHalfCycle[_systemType], 
                            output: minerOutputMapping[_systemType][minerOutputMapping[_systemType].length-1].output/2
                        }));
        }
        
        uint256 nowProductSingle = 0;
        for(uint j = 0; j < minerOutputMapping[_systemType].length; j++) {
            MinerOutput storage minerOutput = minerOutputMapping[_systemType][j];
            if(block.timestamp >= minerOutput.startTime && block.timestamp < minerOutput.endTime) {
                nowProductSingle = minerOutput.output;
                break;
            }
        }
        isTriggerCutDown(_systemType);
        actualProduct[_systemType] += (minerCount[_systemType]*nowProductSingle);
        return true;
    }
    function isTriggerCutDown(uint256 _systemType) private onlyCutDownOwner returns(bool) {
        // current draw num trigger half num
        if(actualProduct[_systemType] >= minerOutputHalfNum[_systemType]) {
            // update output rules
            for(uint j = 0; j < minerOutputMapping[_systemType].length; j++) {
                MinerOutput storage minerOutput = minerOutputMapping[_systemType][j];
                if(block.timestamp >= minerOutput.startTime && block.timestamp < minerOutput.endTime) {
                    minerOutputMapping[_systemType][j].endTime = block.timestamp;
                    if(j+1 < minerOutputMapping[_systemType].length) {
                        minerOutputMapping[_systemType][j+1].startTime = block.timestamp;
                    } else {
                        if(minerOutputMapping[_systemType][j].output/2 != 0) {
                            minerOutputMapping[_systemType].push(MinerOutput({
                                startTime: block.timestamp, 
                                endTime: block.timestamp+minerOutputHalfCycle[_systemType], 
                                output: minerOutputMapping[_systemType][j].output/2
                            }));
                        }
                    }
                    minerOutputHalfNum[_systemType] = minerOutputHalfNum[_systemType]*2;
                    break;
                }
            }
        }
        return true;
    }
    
    // ============================= carves account =========================
    
     function getCarvesParam(uint256 _no) public view onlyParamOwner returns(
        uint256[] memory carvesAccountRatio, 
        uint256[] memory carvesAccountBaseDecimal,
        address[] memory carvesAccountAddress,
        uint256 inviterReward) {
            carvesAccountRatio = carvesParams[_no].carvesAccountRatio;
            carvesAccountBaseDecimal = carvesParams[_no].carvesAccountBaseDecimal;
            carvesAccountAddress = carvesParams[_no].carvesAccountAddress;
            inviterReward = carvesParams[_no].inviterReward;
     }
     
     function setCarvesAccountParam(
         uint256 _no, uint256[] memory _carvesAccountRatio, 
         uint256[] memory _carvesAccountBaseDecimal, 
         address[] memory _carvesAccountAddress,
         uint256 _inviterReward
     ) public onlyParamOwner returns(bool) {
         if(_no == 999) {
            carvesParams.push(CarvesParam({
                carvesAccountRatio: _carvesAccountRatio, 
                carvesAccountAddress: _carvesAccountAddress, 
                carvesAccountBaseDecimal: _carvesAccountBaseDecimal,
                inviterReward: _inviterReward
            }));
         } else {
            carvesParams[_no].carvesAccountRatio = _carvesAccountRatio;
            carvesParams[_no].carvesAccountAddress = _carvesAccountAddress;
            carvesParams[_no].carvesAccountBaseDecimal = _carvesAccountBaseDecimal;
            carvesParams[_no].inviterReward = _inviterReward;
         }
        return true;
     }
    
    function delCarvesAccountParam(uint256 _systemType) public onlyParamOwner returns(bool) {
        delete carvesParams[_systemType];
        return true;
    }
     
     function ownerWithdraw(uint256 _no, uint256 _tokenType, uint256 _value) public onlyOwner returns(bool) {
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(buyMinerTokenParams[_no][_tokenType].tokenAddress);
        bool success = token.transfer(owner, _value);
        require(success, "MinerController: ownerWithdraw method transfer fail");
        return true;
     }
     
     function getCarveTenParam(uint256 _no) public view onlyParamOwner returns(
        address[] memory tenuAddress, 
        uint256[] memory tenuValues) {
            tenuAddress = carvesTenParams[_no].tenuAddress;
            tenuValues = carvesTenParams[_no].tenuValues;
     }
     
     function setCarveTenParam(uint256 _no, address[] memory _tenuAddress, uint256[] memory _tenuValues) public onlyParamOwner returns (bool) {
        if(_no == 999) {
            carvesTenParams.push(CarveTenParam({
                tenuAddress: _tenuAddress, 
                tenuValues: _tenuValues
            }));
            tenuTotalValue.push(0);
         } else {
            carvesTenParams[_no].tenuAddress = _tenuAddress;
            carvesTenParams[_no].tenuValues = _tenuValues;
         }
        return true;
     }
    
    function delCarveTenParam(uint256 _systemType) public onlyParamOwner returns(bool) {
        delete carvesTenParams[_systemType];
        return true;
    }
     
    function getTenuTotal(uint256 _no) public view onlyParamOwner returns(uint256) {
        return tenuTotalValue[_no];
    }
     
    function setTenuTotal(uint256 _no, uint256 _tenuTotalValue) public onlyParamOwner returns(bool) {
        tenuTotalValue[_no] = _tenuTotalValue;
        return true;
    }
    
    function carvesTenFun(uint256 _no, uint256 _buyType) public onlyParamOwner returns(bool) {
        BuyTokenParams memory param = buyMinerTokenParams[_no][_buyType];
        uint256 count = tenuTotalValue[_no].div(param.value.mul(carvesParams[_no].carvesAccountRatio[1]).div(carvesParams[_no].carvesAccountBaseDecimal[1]));
        
        ERC20PresetMinterPauser token = ERC20PresetMinterPauser(param.tokenAddress);
        for(uint256 i = 0; i < carvesTenParams[_no].tenuAddress.length; i++) {
            address carvesAccount = carvesTenParams[_no].tenuAddress[i];
            uint256 transferAccountVaue = carvesTenParams[_no].tenuValues[i]*count;
            
            bool carveSuccess = token.transfer(carvesAccount, transferAccountVaue);
            require(carveSuccess, "MinerController: carve ten transfer fail");
        }
        tenuTotalValue[_no] = 0;
        return true;
    }

}
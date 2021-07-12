pragma solidity ^0.8.0;

import "../common/Pausable.sol";
import "../common/DataOwnable.sol";

contract OfePool is Pausable, DataOwnable {
    
    using SafeMath for uint256;
    
    constructor(address[] memory _dataOperater, address[] memory _interfaceOwner) 
        DataOwnable(_dataOperater, _interfaceOwner){}
        
    event Deposit(uint256 indexed pid, address indexed account, uint256 indexed amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    
    struct PoolInfo {
        IERC20 lpToken;
        IERC20 rewardToken;
        address rewardAddress;
        uint256 lastRewardBlock;
        uint256 accMdxPerShare;
        uint256 totalAmount;
        bool isAllowance;
    }
    
    PoolInfo[] public poolInfo; // pid => poolInfo
	mapping(address => bool) isExists;
    
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // pid => address => accountInfo
    
    struct SingleRewardInfo {
        uint256 startTime;
        uint256 endTime;
        uint256 singleReward;
    }
    mapping(uint256 => SingleRewardInfo[]) public singleRewardInfos; // pid => singleReward
    
    function deposit(uint256 _pid, uint256 _amount) public whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pendingAmount = user.amount.mul(pool.accMdxPerShare).div(1e12).sub(user.rewardDebt);
            if (pendingAmount > 0) {
                safeRewardTransfer(_pid, msg.sender, pendingAmount);
            }
        }
        if (_amount > 0) {
            pool.lpToken.transferFrom(msg.sender, address(this), _amount);
            user.amount = user.amount.add(_amount);
            pool.totalAmount = pool.totalAmount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMdxPerShare).div(1e12);
        
        emit Deposit(_pid, msg.sender, _amount);
    }
    
    function withdraw(uint256 _pid, uint256 _amount) public whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdrawMdx: not good");
        updatePool(_pid);
        uint256 pendingAmount = user.amount.mul(pool.accMdxPerShare).div(1e12).sub(user.rewardDebt);
        if (pendingAmount > 0) {
            safeRewardTransfer(_pid, msg.sender, pendingAmount);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.totalAmount = pool.totalAmount.sub(_amount);
            pool.lpToken.transfer(msg.sender, _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMdxPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }
    
    function show(uint256 _pid) public view returns(uint256 reward) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][msg.sender];
        if (block.timestamp <= pool.lastRewardBlock) {
            return 0;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        uint256 accMdxPerShare = pool.accMdxPerShare;
        uint256 blockReward = 0;// (block.timestamp - pool.lastRewardBlock) * singleRewardInfo[_pid];
        if (lpSupply != 0) {
            uint256 tempCurDrawTime = block.timestamp;
            if(block.timestamp >= singleRewardInfos[_pid][singleRewardInfos[_pid].length-1].endTime) {
               tempCurDrawTime = singleRewardInfos[_pid][singleRewardInfos[_pid].length-1].endTime;
            }
            uint256 curStartTime = pool.lastRewardBlock;
            for(uint j = 0; j < singleRewardInfos[_pid].length; j++) {
                
                SingleRewardInfo memory singleRewardInfo = singleRewardInfos[_pid][j];
                
                if(curStartTime >= singleRewardInfo.startTime && curStartTime < singleRewardInfo.endTime) {
                    // Check tempCurDrawTime more than minerOutput endTime
                    if(tempCurDrawTime >= singleRewardInfo.endTime) {
                        blockReward += (singleRewardInfo.endTime - curStartTime)*singleRewardInfo.singleReward;
                    
                        curStartTime = singleRewardInfo.endTime;
                    } else {
                        blockReward += (tempCurDrawTime - curStartTime)*singleRewardInfo.singleReward;
                    }
                }
                
            }
            
            accMdxPerShare = accMdxPerShare.add(blockReward.mul(1e12).div(lpSupply));
        }
        
        return user.amount.mul(accMdxPerShare).div(1e12).sub(user.rewardDebt);
    }
    
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardBlock) {
            return;
        }
        
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.timestamp;
            return;
        }
            
        uint256 blockReward = 0;// (block.timestamp - pool.lastRewardBlock) * singleRewardInfo[_pid];
        uint256 tempCurDrawTime = block.timestamp;
        if(block.timestamp >= singleRewardInfos[_pid][singleRewardInfos[_pid].length-1].endTime) {
           tempCurDrawTime = singleRewardInfos[_pid][singleRewardInfos[_pid].length-1].endTime;
        }
        uint256 curStartTime = pool.lastRewardBlock;
        for(uint j = 0; j < singleRewardInfos[_pid].length; j++) {
            
            SingleRewardInfo storage singleRewardInfo = singleRewardInfos[_pid][j];
            
            if(curStartTime >= singleRewardInfo.startTime && curStartTime < singleRewardInfo.endTime) {
                // Check tempCurDrawTime more than singleRewardInfo endTime
                if(tempCurDrawTime >= singleRewardInfo.endTime) {
                    blockReward += (singleRewardInfo.endTime - curStartTime)*singleRewardInfo.singleReward;
                
                    curStartTime = singleRewardInfo.endTime;
                } else {
                    blockReward += (tempCurDrawTime - curStartTime)*singleRewardInfo.singleReward;
                }
            }
            
        }
        if (blockReward <= 0) {
            pool.lastRewardBlock = block.timestamp;
            return;
        }
        pool.accMdxPerShare = pool.accMdxPerShare.add(blockReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.timestamp;
    }
    
    function safeRewardTransfer(uint256 _pid, address _to, uint256 _amount) internal {
        PoolInfo memory pool = poolInfo[_pid];
        if(pool.isAllowance) {
            uint256 allowMoney = pool.rewardToken.allowance(pool.rewardAddress, address(this));
            if (_amount > allowMoney) {
                pool.rewardToken.transferFrom(pool.rewardAddress, _to, allowMoney);
            } else {
                pool.rewardToken.transferFrom(pool.rewardAddress, _to, _amount);
            }
        } else {
            pool.rewardToken.transferFrom(pool.rewardAddress, _to, _amount);
        }
    }
    
    // ======================================= manager =======================================
    function addPool(IERC20 _lpToken, IERC20 _rewardToken, address _rewardAddress, bool _isAllowance) public onlyOwner {
        require(address(_lpToken) != address(0), "OfePool: _lpToken is the zero address");
        require(address(_rewardToken) != address(0), "OfePool: _lpToken is the zero address");
		require(!isExists[address(_lpToken)], "OfePool: _lpToken is exists");
        
        poolInfo.push(PoolInfo({
            lpToken : _lpToken,
            rewardToken : _rewardToken,
            rewardAddress : _rewardAddress,
            lastRewardBlock : block.timestamp,
            accMdxPerShare : 0,
            totalAmount : 0,
            isAllowance: _isAllowance
        }));
		
		isExists[address(_lpToken)] = true;
    }
    function updPoolInfo(uint256 _pid, IERC20 _lpToken, IERC20 _rewardToken, address _rewardAddress, bool _isAllowance) public onlyOwner {
        if(address(_lpToken) != address(0)) {
            poolInfo[_pid].lpToken = _lpToken;
        }
        if(address(_rewardToken) != address(0)) {
            poolInfo[_pid].rewardToken = _rewardToken;
        }
        if(_rewardAddress != address(0)) {
            poolInfo[_pid].rewardAddress = _rewardAddress;
        }
        poolInfo[_pid].isAllowance = _isAllowance;
    }
    function updPoolLastBlock(uint256 _pid, uint256 _lastRewardBlock) public onlyOwner {
        poolInfo[_pid].lastRewardBlock = _lastRewardBlock;
    }
    function addRewardInfo(uint256 _pid, uint256 _startTime, uint256 _endTime, uint256 _singleReward) public onlyOwner {
        singleRewardInfos[_pid].push(SingleRewardInfo({
            startTime: _startTime,
            endTime: _endTime,
            singleReward: _singleReward
        }));
    }
    function addRewardInfoAndUpdatePool(uint256 _pid, uint256 _endTime, uint256 _singleReward) public onlyOwner {
        PoolInfo memory pool = poolInfo[_pid];
        updatePool(_pid);
        singleRewardInfos[_pid].push(SingleRewardInfo({
            startTime: pool.lastRewardBlock,
            endTime: _endTime,
            singleReward: _singleReward
        }));
    }
    function updRewardInfo(uint256 _pid, uint256 _index, uint256 _startTime, uint256 _endTime, uint256 _singleReward) public onlyOwner {
        singleRewardInfos[_pid][_index].startTime = _startTime;
        singleRewardInfos[_pid][_index].endTime = _endTime;
        singleRewardInfos[_pid][_index].singleReward = _singleReward;
    }
    function updRewardInfoAndUpdatePool(uint256 _pid, uint256 _index, uint256 _startTime, uint256 _endTime, uint256 _singleReward) public onlyOwner {
        updatePool(_pid);
        singleRewardInfos[_pid][_index].startTime = _startTime;
        singleRewardInfos[_pid][_index].endTime = _endTime;
        singleRewardInfos[_pid][_index].singleReward = _singleReward;
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

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

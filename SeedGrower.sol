

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;



interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

contract Staking {
    mapping(address => uint256) public lastClaimTime;
    mapping(address => uint256) public stakedTokens; // User's staked tokens
    mapping(address => uint256) public accumulatedRewards; // Unclaimed rewards
    mapping(address => uint256) public stakingStartTime; // Timestamp of each user's stake
    mapping(address => bool) public alreadyVoted;

    // uint256 public constant MINIMUM_CLAIM_INTERVAL = 7 days; // 7 days in seconds
    uint256 public constant MINIMUM_CLAIM_INTERVAL = 7 seconds; // 7 days in seconds
    // uint256 public constant NINETY_DAYS = 90 days; // 90 days in seconds
    uint256 public constant NINETY_DAYS = 90 seconds; // 90 days in seconds

    address public lpTokenAddress;
    IERC20 public rewardToken; // Address of the reward token

    address owner = msg.sender;
    address public marketingWallet = owner;

    uint256 totalStakedTokens;
    uint256 public applicants;
    uint256 fee;

    // Rewards distribution parameters
    uint256 public totalDistributedRewards;
    uint256 public currentMonth;
    uint256 public currentDay;
    uint256 public monthlyRewardLimit;
    uint256 public dailyLimit;
    uint256 public rewardsDistributedToday;

    struct LockInfo {
        uint256 amount;
        uint256 lockTime;
    }
    // Annual total rewards for each year
    mapping(uint256 => uint256) public annualRewards;

    event LockedLP(address indexed user, uint256 amount);
    event RewardHarvested(address indexed user, uint256 amount);
    event UnlockedLP(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    // Mapping to track staking information for each user
    mapping(address => LockInfo) public lockInfo;

    constructor(address _uniswapPool, address _rewardToken) {
        lpTokenAddress = _uniswapPool;
        rewardToken = IERC20(_rewardToken);
        annualRewards[54] = 1000000 * 10**18; //2024 epoch year
        annualRewards[55] = 850000 * 10**18; //2025
        annualRewards[56] = 475000 * 10**18; //2026
        annualRewards[57] = 275500 * 10**18; //2027
        annualRewards[58] = 225000 * 10**18; //2028
        annualRewards[59] = 75625 * 10**18; //2029
        annualRewards[60] = 50000 * 10**18; //2030
        annualRewards[61] = 45000 * 10**18; //2031
        annualRewards[62] = 45000 * 10**18; //2032
        annualRewards[63] = 45000 * 10**18; //2033
        annualRewards[64] = 45000 * 10**18; //2034
        annualRewards[65] = 45000 * 10**18; //2035
        annualRewards[66] = 44600 * 10**18; //2036
    }

    function lockLP(uint256 amount) public {
        uint256 usdtAmount = getUSDValueOfLPTokens(msg.sender);
        //require(usdtAmount >= 100 * 10**6, "insuffient pooled Amount");
        require(usdtAmount >= 1 * 10**6, "insuffient pooled Amount");

        require(
            IERC20(lpTokenAddress).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            "LP token transfer failed"
        );
        uint256 lockTime = block.timestamp + NINETY_DAYS;
        stakingStartTime[msg.sender] = block.timestamp;
        lockInfo[msg.sender] = LockInfo(amount, lockTime); // update last claimed timestamp
        totalStakedTokens += amount;
        stakedTokens[msg.sender] += amount;
        emit LockedLP(msg.sender, amount);
    }

    function unlockLP() public {
    require(block.timestamp >= stakingStartTime[msg.sender] + NINETY_DAYS, "Cannot unlock before 90 days");

    uint256 lockedAmount = lockInfo[msg.sender].amount;
    
    require(lockedAmount > 0, "No locked tokens");

    // Transfer LP tokens back to the user
    require(
        IERC20(lpTokenAddress).transfer(
            msg.sender,
            lockedAmount
        ),
        "LP token transfer failed"
    );

    // Update staking information
    totalStakedTokens -= lockedAmount;
    stakedTokens[msg.sender] -= lockedAmount;
    delete lockInfo[msg.sender];

    emit UnlockedLP(msg.sender, lockedAmount);
}


    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function yearNow() internal view returns (uint256) {
        return block.timestamp / 365 days; // Approximate year based on timestamp
    }

    function marketingFee() internal returns (uint256) {
        if (applicants >= 1000000) {
            fee = 50;
        } else if (applicants >= 10000000) {
            fee = 25;
        } else if (applicants >= 100000000) {
            fee = 12;
        } else {
            fee = 100;
        }

        return fee;
    }

    // Function to get the current month
    function getCurrentMonth() public view returns (uint256) {
        return block.timestamp / 30 days;
    }

    // Function to harvest rewards
    function harvestRewards() public {
        uint256 timeSinceLastClaim = block.timestamp -
            lastClaimTime[msg.sender];
        uint256 timeSinceStaking = block.timestamp -
            stakingStartTime[msg.sender];

        require(
            timeSinceLastClaim >= MINIMUM_CLAIM_INTERVAL,
            "Must wait at least 7 days between claims"
        );
        require(
            timeSinceStaking >= NINETY_DAYS,
            "Cannot claim before 90 days of staking"
        );

        require(stakedTokens[msg.sender] > 0, "No staked tokens");

        // Check if the current month has changed
        if (currentMonth != getCurrentMonth()) {
            currentMonth = getCurrentMonth();
            monthlyRewardLimit = (annualRewards[yearNow()] / 12); // Daily limit
        }
        if (block.timestamp / 1 days != currentDay) {
            currentDay = block.timestamp / 1 days;
            dailyLimit = annualRewards[yearNow()] / 12 / 30; // Daily limit
            rewardsDistributedToday = 0; // Reset the daily counter
        }

        if (yearNow() > 66) {
            annualRewards[yearNow()] = 44600 * 10**18;
        }
        uint256 dailyReward = (annualRewards[yearNow()] * stakedTokens[msg.sender]) 
                                / totalStakedTokens / 365;
        uint256 unclaimedDays = min(
            timeSinceLastClaim / MINIMUM_CLAIM_INTERVAL,
            timeSinceStaking / NINETY_DAYS
        );
        uint256 accumulatedReward = dailyReward * unclaimedDays;
        accumulatedRewards[msg.sender] = accumulatedReward;
        uint256 remainingDailyLimit = dailyLimit - rewardsDistributedToday;
        uint256 claimableAmount = min(accumulatedReward, remainingDailyLimit);
        claimableAmount =
            (claimableAmount * stakedTokens[msg.sender]) /
            totalStakedTokens;

        accumulatedRewards[msg.sender] -= claimableAmount;
        totalDistributedRewards += claimableAmount;
        rewardsDistributedToday += claimableAmount;

        require(claimableAmount > 0, "No claimable rewards");
        uint256 marketingShare = (claimableAmount * marketingFee()) / 10000;
        claimableAmount -= marketingShare;
        if (claimableAmount > 0) {
            rewardToken.transfer(msg.sender, claimableAmount);
            rewardToken.transfer(marketingWallet, marketingShare);
        }
        lastClaimTime[msg.sender] = block.timestamp;
        emit RewardHarvested(msg.sender, claimableAmount);
    }

    function getUnclaimedRewards(address user) external view returns (uint256) {
        uint256 timeSinceLastClaim = block.timestamp -
            lastClaimTime[msg.sender];
        uint256 timeSinceStaking = block.timestamp -
            stakingStartTime[msg.sender];

        if (
            timeSinceLastClaim < MINIMUM_CLAIM_INTERVAL ||
            timeSinceStaking < NINETY_DAYS
        ) {
            // No rewards if claiming too soon or staking for less than 90 days
            return 0;
        }

        uint256 unclaimedDays = min(
            timeSinceLastClaim / MINIMUM_CLAIM_INTERVAL,
            timeSinceStaking / NINETY_DAYS
        );

        uint256 dailyReward = (annualRewards[yearNow()] * stakedTokens[user]) 
                                / totalStakedTokens / 365;
        uint256 accumulatedReward = dailyReward * unclaimedDays;

        return accumulatedReward;
    }

    // Owner function to withdraw any accidentally sent tokens to the staking contract
    function withdrawExcess(address token, uint256 amount) external {
        require(msg.sender == owner, "not Allowed");
        IERC20(token).transfer(owner, amount);
    }

    // Set the address of the Uniswap pool
    function setUniswapPool(address _uniswapPool) external {
        require(msg.sender == owner, "not Allowed");
        lpTokenAddress = _uniswapPool;
    }

    // Get the approximate USD value of user's LP tokens
    function getUSDValueOfLPTokens(address user)
        internal
        view
        returns (uint256)
    {
        require(lpTokenAddress != address(0), "Uniswap pool address not set");

        // Retrieve the user's LP token balance
        uint256 lpTokenBalance = IERC20(lpTokenAddress).balanceOf(user);

        // Retrieve the total supply of LP tokens in the Uniswap pool
        uint256 totalLPTokens = IERC20(lpTokenAddress).totalSupply();

        // Get the reserves of the underlying tokens in the Uniswap pool
        (uint256 reserveUSDT, , ) = IUniswapV2Pair(lpTokenAddress)
            .getReserves();

        // Assuming the pool consists of two tokens (BUSD and BUDS)
        // Calculate the share of the total pool that the user's LP tokens represent
        uint256 userShare = (lpTokenBalance * (1e18)) / (totalLPTokens);

        // Estimate the USD value of the user's share based on the reserves
        uint256 usdValue = (userShare * reserveUSDT) / (1e18);

        return usdValue;
    }
  
    function reduceCommission() external {
        require(rewardToken.balanceOf(msg.sender) > 0, "Zero Holdings");
        require(
            !alreadyVoted[msg.sender],
            "You have already applied for reduction"
        );
        applicants++;
        alreadyVoted[msg.sender] = true;
    }
}

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}


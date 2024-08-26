// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/automation/KeeperCompatible.sol";

contract StakingRewards is
    Pausable,
    Ownable,
    ReentrancyGuard,
    KeeperCompatible
{
    using EnumerableSet for EnumerableSet.AddressSet;

// created a struct to handle individual rewards
    struct ReferralReward {
        uint256 totalAmount;
        uint256 startTime;
        uint256 claimedAmount;
        uint256 lastClaimTime;
    }

// vesting period for referrals
    uint256 public constant REFERRAL_VESTING_PERIOD = 30 days;

    uint256 public constant PERCENTAGE_DENOMINATOR = 10000;

    IERC20Metadata public token;
    uint256 public stakingAppStartedAt;

    EnumerableSet.AddressSet allStakers;

    address public treasuryWallet;

    // Duration of rewards to be paid out (in seconds)
    uint256 public duration;

    uint256 public treasuryRateForRewards;

    mapping(address => uint256) public stakingRewardsToRelease;
    uint internal lastProcessedIndex;
    uint internal batchSize;

    uint256 public totalStakingRewardsToRelease;


    // created new mapping from address to address to struct
    mapping(address => mapping(address => ReferralReward)) public firstReferralRewards;
    mapping(address => mapping(address => ReferralReward)) public secondReferralRewards;


    // User address => rewards to be claimed
    mapping(address => uint256) public totalRewardClaimed;
    mapping(address => uint256) public releasedRewardUpdatedAt;

    mapping(address => uint256) public remainingStakingRewards;
    mapping(address => uint256) public remainingReferralRewards;

    // Total staked
    uint256 public totalStaked;
    uint256 public treasuryBalancePrev;
    uint256 public totalStakedPrev;

    mapping(address => uint256) public tokensStaked;
    mapping(address => uint256) public lastUnstakedAt;

    uint256 public unstakeFee;
    uint256 public discountUnstakeFee;

    uint256 public firstRefRewardsRate;
    uint256 public secondRefRewardsRate;
    uint256 public releaseRefRewardDuration;
    uint256 public releaseRefRewardEpoch;

    uint256 public longtermStakingRewardsRate;

    uint256 public multiplierEpoch;
    uint256 public multiplierRatePerEpoch;

    mapping(address => uint256) public lastStakedTime;
    mapping(address => uint256) public lastStakedAmount;

    // Ref variables
    mapping(address => address) public referrers; // (Referee => Referrer)

    mapping(address => EnumerableSet.AddressSet) firstReferees; // (Referrer => first Referees)
    mapping(address => EnumerableSet.AddressSet) secondReferees; // (Referrer => second Referees)

    mapping(address => mapping(address => uint256)) public stakedWithRef;

    mapping(address => mapping(address => uint256)) public firstRefRewards;
    mapping(address => mapping(address => uint256)) public secondRefRewards;

    mapping(address => uint256) public totalRefRewardClaimed;

    mapping(address => uint256) public lastFirstRefRewardPerSec; // referee => reward per sec
    mapping(address => uint256) public lastSecondRefRewardPerSec; // referee => reward per sec

    mapping(address => uint256) public refRewardStartedAt; // referee => startedAt

    uint256 public totalRefRewardsVested;

    ///events
    event StakeToken(address indexed user, uint256 amount, uint256 time);
    event UnstakeToken(address indexed user, uint256 amount, uint256 time);
    event ClaimReward(address indexed user, uint256 amount, uint256 time);
    event DurationChanged(uint256 duration, uint256 time);

    //new event added
    event ReferralRewardClaimed(address indexed referrer, address indexed referee, uint256 amount, uint256 time);

    mapping(string => address) public referrersWithRefCodes; // referrer => refCode;
    mapping(address => bool) public isReferrer; // referrer => bool;

    mapping(address => bool) public isUsedRefCode; // referee => bool;

    uint256 public lastTimeStampForChainlink;
    uint256 public releaseRewardDuration;
    uint256 internal batchProcessTime;

    // test
    uint256 public callingCount;

    mapping(address => uint256) public refereeCount; // referrer => referee count

    /// @notice constructor to initialize the staking contract
    constructor(
        address _ownerAddress,
        address _token,
        address _treasuryWallet,
        uint256 _duration
    ) Ownable(msg.sender) {
        token = IERC20Metadata(_token);
        duration = _duration;
        unstakeFee = 900; // 9% as default
        discountUnstakeFee = 5000; // discount fee for unstaking with ref code : 50% as default
        firstRefRewardsRate = 3000; // first Referral fee : 30%  as default
        secondRefRewardsRate = 1500; // 15% as default
        releaseRefRewardDuration = 86400 * 30; // 1 month as default
        releaseRefRewardEpoch = 86400; // 1 day as default
        longtermStakingRewardsRate = 2400; // 24% as default
        multiplierEpoch = 86400 * 7; // 1 week as default
        multiplierRatePerEpoch = 100; // 1% as default
        treasuryWallet = _treasuryWallet;
        treasuryBalancePrev = token.balanceOf(treasuryWallet);
        totalStakedPrev = 0;
        treasuryRateForRewards = 10000; // 100% as default;
        stakingAppStartedAt = block.timestamp;
        lastTimeStampForChainlink = block.timestamp;
        releaseRewardDuration = 28800; // chainlink automation is updated every 8 hours.
        batchSize = 500;
        lastProcessedIndex = 0;
        batchProcessTime = 0;
        transferOwnership(_ownerAddress);
        pause();
    }

    receive() external payable {}

    fallback() external {}

    function withdrawETH(address _to) external onlyOwner {
        require(_to != address(0), "Invalid address: zero address");
        (bool success, ) = payable(_to).call{value: address(this).balance}("");
        if (!success) {
            revert("Transfer Failed");
        }
    }

    function _isValidReferralCode(
        string memory _refCode
    ) internal view returns (bool) {
        if (bytes(_refCode).length < 5) return false;
        if (referrersWithRefCodes[_refCode] == address(0)) return false;
        return true;
    }

    // Calculates Reward Per token and second
    function _rewardsPerTokenAndSec(
        uint256 _duration
    ) internal view returns (uint256) {
        if (totalStaked == 0 || _duration == 0) return 0;

        uint256 currentStakingAppMultiplier = _calculateStakingAppMuliplier();
        uint256 deltaStaked = totalStaked > totalStakedPrev
            ? totalStaked - totalStakedPrev
            : 0;
        uint256 deltaReferralRewards = (deltaStaked *
            (firstRefRewardsRate + secondRefRewardsRate)) /
            PERCENTAGE_DENOMINATOR; // [(S(n)-S(n-1)) * R(r)]
        uint256 longtermStakingRewards = (totalStakingRewardsToRelease *
            currentStakingAppMultiplier) / PERCENTAGE_DENOMINATOR; // [S(n) * R(ls,n)* APY(n-1)]

        if (
            deltaReferralRewards +
                longtermStakingRewards +
                totalStakingRewardsToRelease >
            treasuryBalancePrev
        ) return 0;

        uint256 tn = ((treasuryBalancePrev -
            longtermStakingRewards -
            deltaReferralRewards -
            totalStakingRewardsToRelease) * treasuryRateForRewards) /
            PERCENTAGE_DENOMINATOR;

        uint256 rewardPerTokenAndSec = (tn * 1e18) / totalStaked / _duration;

        return rewardPerTokenAndSec;
    }

    function _calculateStakingAppMuliplier() internal view returns (uint256) {
        uint256 delta = ((block.timestamp / multiplierEpoch) *
            multiplierEpoch) -
            ((stakingAppStartedAt / multiplierEpoch) * multiplierEpoch);
        uint256 multiplier = (multiplierRatePerEpoch * delta) / multiplierEpoch;
        return _min(multiplier, longtermStakingRewardsRate);
    }

    function _calculateMuliplier(
        address _account
    ) internal view returns (uint256) {
        if (tokensStaked[_account] > 0) {
            uint256 delta = ((block.timestamp / multiplierEpoch) *
                multiplierEpoch) -
                ((lastUnstakedAt[_account] / multiplierEpoch) *
                    multiplierEpoch);
            uint256 multiplier = (multiplierRatePerEpoch * delta) /
                multiplierEpoch;

            return _min(multiplier, longtermStakingRewardsRate);
        }
        return 0;
    }

    // Calculates and returns the earned rewards for a user
    function _earnedStakingReward(
        address _account
    ) internal view returns (uint256) {
        require(
            block.timestamp >= releasedRewardUpdatedAt[_account],
            "Claim update!"
        );
        if (tokensStaked[_account] == 0) {
            return 0;
        }

        uint256 delta = block.timestamp - releasedRewardUpdatedAt[_account];

        uint256 effectiveStakedAmount = tokensStaked[_account];
        if (block.timestamp - lastStakedTime[_account] < 1 days) {
            effectiveStakedAmount -= lastStakedAmount[_account];
        }

        uint256 stakingReward = (_rewardsPerTokenAndSec(duration) *
            effectiveStakedAmount *
            (PERCENTAGE_DENOMINATOR + _calculateMuliplier(_account)) *
            delta) /
            PERCENTAGE_DENOMINATOR /
            1e18;
        return stakingReward;
    }

    function _updateStakingReleasedRewards(
        uint _batchStartIndex,
        uint _batchSize
    ) internal {
        address[] memory stakers = allStakers.values();
        uint256 endIndex = _batchStartIndex + _batchSize;
        if (endIndex > stakers.length) {
            endIndex = stakers.length;
        }

        uint256 newStakingReleaseRewards = 0;
        uint256 newTotalStakingReleaseRewards = 0;

        for (uint256 i = _batchStartIndex; i < endIndex; ++i) {
            newStakingReleaseRewards = _earnedStakingReward(stakers[i]);

            releasedRewardUpdatedAt[stakers[i]] = block.timestamp;

            stakingRewardsToRelease[stakers[i]] += newStakingReleaseRewards;
            newTotalStakingReleaseRewards += newStakingReleaseRewards;
        }

        totalStakingRewardsToRelease += newTotalStakingReleaseRewards;
        treasuryBalancePrev = token.balanceOf(treasuryWallet);

        lastProcessedIndex = endIndex;
    }

    function _processNextBatchToReleaseStakingRewards() internal {
        if (lastProcessedIndex >= allStakers.values().length) {
            lastProcessedIndex = 0;
        }

        _updateStakingReleasedRewards(lastProcessedIndex, batchSize);

        //testing
        callingCount++;
    }

    function _handleBatchProcessForAutomation() internal {
        uint256 stakerLength = allStakers.values().length;
        uint256 batchProcessCount = stakerLength / batchSize;
        if (batchSize * batchProcessCount < stakerLength) {
            batchProcessCount += 1;
        }

        if (batchProcessTime >= batchProcessCount) {
            batchProcessTime = 0;
            lastTimeStampForChainlink = block.timestamp;
            return;
        }

        batchProcessTime++;
    }

    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp - lastTimeStampForChainlink) > releaseRewardDuration;
        performData = checkData;

        return (upkeepNeeded, performData);
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        require((block.timestamp - lastTimeStampForChainlink) > releaseRewardDuration, "KeepUp requirement is not met!");
        _processNextBatchToReleaseStakingRewards();
        _handleBatchProcessForAutomation();
    }

    function _updateRefRewardPerSec(
        address _referee,
        uint256 _unstaked
    ) internal returns (uint256, uint256) {
        uint256 deltaFirstRewardPerSec = 0;
        uint256 deltaSecondRewardPerSec = 0;

        if (lastFirstRefRewardPerSec[_referee] > 0) {
            deltaFirstRewardPerSec =
                (lastFirstRefRewardPerSec[_referee] *
                    _unstaked *
                    PERCENTAGE_DENOMINATOR) /
                tokensStaked[_referee] /
                PERCENTAGE_DENOMINATOR;

            lastFirstRefRewardPerSec[_referee] -= deltaFirstRewardPerSec;
        }

        if (lastSecondRefRewardPerSec[_referee] > 0) {
            deltaSecondRewardPerSec =
                (lastSecondRefRewardPerSec[_referee] *
                    _unstaked *
                    PERCENTAGE_DENOMINATOR) /
                tokensStaked[_referee] /
                PERCENTAGE_DENOMINATOR;
            lastSecondRefRewardPerSec[_referee] -= deltaSecondRewardPerSec;
        }

        return (deltaFirstRewardPerSec, deltaSecondRewardPerSec);
    }

    function _updateExpectedRefRewards(
        address _referee,
        uint256 _unstaked
    ) internal returns (bool) {
        address firstReferrer = referrers[_referee];
        uint256 releaseExpireAt = refRewardStartedAt[_referee] + releaseRefRewardDuration;

        if (block.timestamp < releaseExpireAt) {
            address secondReferrer = referrers[firstReferrer];
            uint256 deltaFirstRefRewardPerSec = 0;
            uint256 deltaSecondRefRewardPerSec = 0;

            (deltaFirstRefRewardPerSec, deltaSecondRefRewardPerSec) = _updateRefRewardPerSec(_referee, _unstaked);

            uint256 remainedTime = (releaseExpireAt / releaseRefRewardEpoch) * releaseRefRewardEpoch -
                (block.timestamp / releaseRefRewardEpoch) * releaseRefRewardEpoch;

            ReferralReward storage firstReward = firstReferralRewards[firstReferrer][_referee];
            uint256 firstDeltaAmount = deltaFirstRefRewardPerSec * remainedTime;
            if (firstReward.totalAmount >= firstDeltaAmount) {
                firstReward.totalAmount -= firstDeltaAmount;
            } else {
                firstDeltaAmount = firstReward.totalAmount;
                firstReward.totalAmount = 0;
            }

            uint256 secondDeltaAmount = 0;
            if (secondReferrer != address(0)) {
                ReferralReward storage secondReward = secondReferralRewards[secondReferrer][_referee];
                secondDeltaAmount = deltaSecondRefRewardPerSec * remainedTime;
                if (secondReward.totalAmount >= secondDeltaAmount) {
                    secondReward.totalAmount -= secondDeltaAmount;
                } else {
                    secondDeltaAmount = secondReward.totalAmount;
                    secondReward.totalAmount = 0;
                }
            }

            totalRefRewardsVested -= (firstDeltaAmount + secondDeltaAmount);
            return true;
        }

        return false;
    }

    //new function to determine claimable amount
    function _calculateClaimableReferralReward(
        ReferralReward storage reward
    ) internal view returns (uint256) {
        if (block.timestamp >= reward.startTime + REFERRAL_VESTING_PERIOD) {
            return reward.totalAmount - reward.claimedAmount;
        }

        uint256 elapsedTime = block.timestamp - reward.lastClaimTime;
        uint256 totalVestingTime = REFERRAL_VESTING_PERIOD;
        uint256 claimableAmount = (reward.totalAmount * elapsedTime) / totalVestingTime;

        return claimableAmount > (reward.totalAmount - reward.claimedAmount)
            ? (reward.totalAmount - reward.claimedAmount)
            : claimableAmount;
    }

    // level 1: first referrer, level 2: second referrer
    //modified it to use the new struct
 function _calculateRefRewards(
    address _referrer,
    address _referee,
    uint256 _level
) internal view returns (uint256) {
    ReferralReward storage reward = _level == 1
        ? firstReferralRewards[_referrer][_referee]
        : secondReferralRewards[_referrer][_referee];

    if (block.timestamp >= reward.startTime + REFERRAL_VESTING_PERIOD) {
        return reward.totalAmount - reward.claimedAmount;
    }

    uint256 elapsedTime = block.timestamp - reward.lastClaimTime;
    uint256 claimableAmount = (reward.totalAmount * elapsedTime) / REFERRAL_VESTING_PERIOD;

    return claimableAmount > (reward.totalAmount - reward.claimedAmount)
        ? (reward.totalAmount - reward.claimedAmount)
        : claimableAmount;
}

//modified it to use the new struct
    function _calculateTotalRefRewardToClaim(
        address _referrer
    ) internal view returns (uint256) {
        address[] memory firstRefereeList = firstReferees[_referrer].values();
        address[] memory secondRefereeList = secondReferees[_referrer].values();

        uint256 firstRefereeCnt = firstRefereeList.length;
        uint256 secondRefereeCnt = secondRefereeList.length;

        uint256 totalReward = 0;

        for (uint256 i = 0; i < firstRefereeCnt; ++i) {
            ReferralReward storage reward = firstReferralRewards[_referrer][firstRefereeList[i]];
            totalReward += _calculateClaimableReferralReward(reward);
        }
    
        for (uint256 i = 0; i < secondRefereeCnt; ++i) {
            ReferralReward storage reward = secondReferralRewards[_referrer][secondRefereeList[i]];
            totalReward += _calculateClaimableReferralReward(reward);
        }

        return totalReward;
    }
    //modified it to use the struct
    function _addStakeReferrer(
        address _referee,
        address _firstReferrer,
        uint256 _amount
    ) internal returns (bool) {
        referrers[_referee] = _firstReferrer;

        firstReferees[_firstReferrer].add(_referee);

        refRewardStartedAt[_referee] = block.timestamp;

        stakedWithRef[_firstReferrer][_referee] = _amount;

        uint256 firstRefReward = (_amount * firstRefRewardsRate) / PERCENTAGE_DENOMINATOR;
        firstReferralRewards[_firstReferrer][_referee] = ReferralReward({
            totalAmount: firstRefReward,
            startTime: block.timestamp,
            claimedAmount: 0,
            lastClaimTime: block.timestamp
        });
        lastFirstRefRewardPerSec[_referee] = firstRefReward / releaseRefRewardDuration;

        uint256 secondRefReward = 0;
        if (referrers[_firstReferrer] != address(0)) {
            address secondReferrer = referrers[_firstReferrer];
            secondReferees[secondReferrer].add(_referee);

            secondRefReward = (_amount * secondRefRewardsRate) / PERCENTAGE_DENOMINATOR;
            secondReferralRewards[secondReferrer][_referee] = ReferralReward({
                totalAmount: secondRefReward,
                startTime: block.timestamp,
                claimedAmount: 0,
                lastClaimTime: block.timestamp
            });
            lastSecondRefRewardPerSec[_referee] = secondRefReward / releaseRefRewardDuration;
        }

        totalRefRewardsVested += (firstRefReward + secondRefReward);

        return true;
    }

    function _createRefCode(
        address _referrer,
        string memory _refCode
    ) internal returns (bool) {
        require(bytes(_refCode).length >= 5, "Invalid Referral Code");
        require(
            !isReferrer[_referrer] &&
                referrersWithRefCodes[_refCode] == address(0),
            "You created referral code already"
        );
        referrersWithRefCodes[_refCode] = _referrer;
        isReferrer[_referrer] = true;
        return true;
    }

    // Allows users to stake a specified amount of tokens
    function stake(
        uint256 _amount,
        address _referrer,
        string memory _refCode
    ) external whenNotPaused {
        require(_amount != 0, "amount = 0");

        if (_referrer != address(0) && _isValidReferralCode(_refCode)) {
            require(
                !isUsedRefCode[msg.sender],
                "You used referral code already!"
            );
        }
        if (_referrer != address(0) && !isReferrer[_referrer]) {
            _createRefCode(_referrer, _refCode);
        }

        require(
            referrersWithRefCodes[_refCode] != msg.sender,
            "You are using your own referral code!"
        );

        token.transferFrom(msg.sender, address(this), _amount);

        if (!allStakers.contains(msg.sender) && _amount > 0) {
            allStakers.add(msg.sender);
        }

        if (tokensStaked[msg.sender] == 0) {
            // initialize the timestamps when a user stakes at first.
            // stakedStartTime[msg.sender] = block.timestamp;
            releasedRewardUpdatedAt[msg.sender] = block.timestamp;
            lastUnstakedAt[msg.sender] = block.timestamp;
        }

        if (_isValidReferralCode(_refCode)) {
            address referrer = referrersWithRefCodes[_refCode];
            if (referrer != address(0) && !isUsedRefCode[msg.sender]) {
                _addStakeReferrer(msg.sender, referrer, _amount);
                isUsedRefCode[msg.sender] = true;
                refereeCount[referrer] += 1;
            }
        }

        tokensStaked[msg.sender] += _amount;

        totalStakedPrev = totalStaked;
        totalStaked += _amount;
        lastStakedTime[msg.sender] = block.timestamp;
        lastStakedAmount[msg.sender] = _amount;

        emit StakeToken(msg.sender, _amount, block.timestamp);
    }

    // Allows users to unstake a specified amount of staked tokens
    function unstake(uint256 _amount) external whenNotPaused {
        require(_amount != 0, "amount = 0");
        require(
            tokensStaked[msg.sender] >= _amount,
            "You didn't stake enough tokens to unstake!"
        );

        uint256 unstakeFeeAmount = (_amount * unstakeFee) /
            PERCENTAGE_DENOMINATOR;

        if (referrers[msg.sender] != address(0)) {
            unstakeFeeAmount =
                (unstakeFeeAmount * discountUnstakeFee) /
                PERCENTAGE_DENOMINATOR;
            _updateExpectedRefRewards(msg.sender, _amount);
        }

        tokensStaked[msg.sender] -= _amount;
        totalStaked -= _amount;

        if (tokensStaked[msg.sender] == 0) {
            allStakers.remove(msg.sender);
        }

        token.transfer(msg.sender, _amount - unstakeFeeAmount);
        token.transfer(treasuryWallet, unstakeFeeAmount);

        lastUnstakedAt[msg.sender] = block.timestamp;

        emit UnstakeToken(msg.sender, _amount, block.timestamp);
    }

    function claimStakingReward() external whenNotPaused returns (bool) {
        uint256 reward = stakingRewardsToRelease[msg.sender] +
            remainingStakingRewards[msg.sender];
        uint256 remaining = _claimReward(reward);

        remainingStakingRewards[msg.sender] = remaining;

        uint256 claimedReward = reward - remaining;

        if (claimedReward >= stakingRewardsToRelease[msg.sender]) {
            totalStakingRewardsToRelease -= stakingRewardsToRelease[msg.sender];
            stakingRewardsToRelease[msg.sender] = 0;
        } else {
            totalStakingRewardsToRelease -= claimedReward;
            stakingRewardsToRelease[msg.sender] -= claimedReward;
        }

        totalRewardClaimed[msg.sender] += claimedReward;

        return true;
    }

//using time based claiming now
    function claimReferralReward() external whenNotPaused nonReentrant returns (bool) {
        uint256 totalClaimableReward = 0;

        // Process first level referrals
        address[] memory firstRefereeList = firstReferees[msg.sender].values();
        for (uint256 i = 0; i < firstRefereeList.length; i++) {
            address referee = firstRefereeList[i];
            ReferralReward storage reward = firstReferralRewards[msg.sender][referee];
            uint256 claimableReward = _calculateClaimableReferralReward(reward);
            
            if (claimableReward > 0) {
                reward.claimedAmount += claimableReward;
                reward.lastClaimTime = block.timestamp;
                totalClaimableReward += claimableReward;
                
                emit ReferralRewardClaimed(msg.sender, referee, claimableReward, block.timestamp);
            }
        }

        // Process second level referrals
        address[] memory secondRefereeList = secondReferees[msg.sender].values();
        for (uint256 i = 0; i < secondRefereeList.length; i++) {
            address referee = secondRefereeList[i];
            ReferralReward storage reward = secondReferralRewards[msg.sender][referee];
            uint256 claimableReward = _calculateClaimableReferralReward(reward);
            
            if (claimableReward > 0) {
                reward.claimedAmount += claimableReward;
                reward.lastClaimTime = block.timestamp;
                totalClaimableReward += claimableReward;
                
                emit ReferralRewardClaimed(msg.sender, referee, claimableReward, block.timestamp);
            }
        }

        require(totalClaimableReward > 0, "No referral rewards to claim");

        uint256 remaining = _claimReward(totalClaimableReward);
        uint256 claimedReward = totalClaimableReward - remaining;

        totalRefRewardClaimed[msg.sender] += claimedReward;
        remainingReferralRewards[msg.sender] = remaining;

        return true;
    }

    // Allows users to claim their rewards
    function _claimReward(uint256 _amount) internal returns (uint256) {
        uint256 reward = _amount;

        if (reward > 0) {
            uint256 treasuryBalance = token.balanceOf(treasuryWallet);
            require(treasuryBalance > reward);
            token.transferFrom(treasuryWallet, msg.sender, reward);
        }

        return 0;
    }


    function _updateReferralRewards(address _referrer, uint256 _claimedReward) internal {
        address[] memory firstRefereeList = firstReferees[_referrer].values();
        address[] memory secondRefereeList = secondReferees[_referrer].values();
    
        uint256 firstRefereeCnt = firstRefereeList.length;
        uint256 secondRefereeCnt = secondRefereeList.length;
    
        uint256 remainingReward = _claimedReward;
    
        for (uint256 i = 0; i < firstRefereeCnt; ++i) {
            uint256 refReward = firstRefRewards[_referrer][firstRefereeList[i]];
            if (remainingReward > 0 && refReward > 0) {
                uint256 rewardToDeduct = _min(remainingReward, refReward);
                firstRefRewards[_referrer][firstRefereeList[i]] -= rewardToDeduct;
                remainingReward -= rewardToDeduct;
            }
        }
    
        for (uint256 i = 0; i < secondRefereeCnt; ++i) {
            uint256 refReward = secondRefRewards[_referrer][secondRefereeList[i]];
            if (remainingReward > 0 && refReward > 0) {
                uint256 rewardToDeduct = _min(remainingReward, refReward);
                secondRefRewards[_referrer][secondRefereeList[i]] -= rewardToDeduct;
                remainingReward -= rewardToDeduct;
            }
        }

        if (remainingReward > 0) {
            remainingReferralRewards[_referrer] += remainingReward;
        }

    }

    function earnedReferralReward(
        address _referrer
    ) public view returns (uint256) {
        uint256 refReward = _calculateTotalRefRewardToClaim(_referrer);
        return refReward;
    }

    function referralRewardToClaim(
        address _referrer
    ) public view returns (uint256) {
        uint256 refReward = _calculateTotalRefRewardToClaim(_referrer);
        return refReward - totalRefRewardClaimed[_referrer];
    }

    /*
     * Owner Control
     */

    /// @notice withdraw tokens stored in the contract
    function emergencyWithdrawTokens(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        IERC20Metadata(_token).transfer(_to, _amount);
    }

    function updateToken(address _token) external onlyOwner {
        require(_token != address(0), "Token shouldn't be zero");
        token = IERC20Metadata(_token);
    }

    function updateReleaseStakingRewardDuration(uint256 _duration) external onlyOwner {
        releaseRewardDuration = _duration;
    }

    function updateRewardDuration(uint256 _duration) external onlyOwner {
        duration = _duration;
        emit DurationChanged(_duration, block.timestamp);
    }

    function updateReleaseRefRewardDuration(
        uint256 _releaseRefRewardDuration
    ) external onlyOwner {
        releaseRefRewardDuration = _releaseRefRewardDuration;
    }

    function updateRefRewardRates(
        uint256 _firstRefRewardRate,
        uint256 _secondRefRewardRate
    ) external onlyOwner {
        require(
            _firstRefRewardRate > 0 && _firstRefRewardRate < 1000,
            "Invalid Referral Rewards Rate"
        );
        require(
            _secondRefRewardRate > 0 && _secondRefRewardRate < 1000,
            "Invalid Referral Rewards Rate"
        );

        firstRefRewardsRate = _firstRefRewardRate;
        secondRefRewardsRate = _secondRefRewardRate;
    }

    function updateReleaseRefRewardInfo(
        uint256 _duration,
        uint256 _epoch
    ) external onlyOwner {
        releaseRefRewardDuration = _duration;
        releaseRefRewardEpoch = _epoch;
    }

    function updateMultiplier(
        uint256 _multiplierRatePerEpoch,
        uint256 _multiplierEpoch
    ) external onlyOwner {
        require(
            _multiplierRatePerEpoch > 100 &&
                _multiplierRatePerEpoch < longtermStakingRewardsRate,
            "multiplierRatePerEpoch should be less than longterm staking rewards rate"
        );
        multiplierRatePerEpoch = _multiplierRatePerEpoch;
        multiplierEpoch = _multiplierEpoch;
    }

    function updateStakingAppStartedAt() external onlyOwner {
        stakingAppStartedAt = block.timestamp;
    }

    function updateLongtermStakingRewardsRate(
        uint256 _longtermStakingRewardsRate
    ) external onlyOwner {
        require(
            _longtermStakingRewardsRate > 100 &&
                _longtermStakingRewardsRate < PERCENTAGE_DENOMINATOR,
            "longterm staking rewards rate should be less than 100%"
        );

        require(
            _longtermStakingRewardsRate > multiplierRatePerEpoch,
            "Longterm staking rewards rate must be greater than multiplier rate per epoch"
        );

        longtermStakingRewardsRate = _longtermStakingRewardsRate;
    }

    function updateStakingToken(address _token) external onlyOwner {
        require(_token != address(0), "Token shouldn't be zero");
        token = IERC20Metadata(_token);
    }

    function updateUnstakeFee(uint256 _unstakeFee) external onlyOwner {
        require(
            _unstakeFee > 100 && _unstakeFee < 50000,
            "Unstake Fee should be less than denominator"
        );
        unstakeFee = _unstakeFee;
    }

    function updateDiscountUnstakeFee(
        uint256 _discountUnstakeFee
    ) external onlyOwner {
        require(
            _discountUnstakeFee > 100 &&
                _discountUnstakeFee < PERCENTAGE_DENOMINATOR,
            "Unstake Fee should be less than denominator"
        );
        discountUnstakeFee = _discountUnstakeFee;
    }

    function updateTreasuryRateForRewards(
        uint256 _treasuryRateForRewards
    ) external onlyOwner {
        require(
            _treasuryRateForRewards > 100 &&
                _treasuryRateForRewards < PERCENTAGE_DENOMINATOR,
            "Treasury Rate for rewards should be less than denominator"
        );
        treasuryRateForRewards = _treasuryRateForRewards;
    }

    /*
     * View functions
     */
    function getAllStakers() external view returns (address[] memory) {
        return allStakers.values();
    }

    function getStakersLength() external view returns (uint256) {
        return allStakers.values().length;
    }

    function getStakingRewardsToRelease(
        address _account
    ) external view returns (uint256) {
        return
            stakingRewardsToRelease[_account];
    }

    function getFirstReferees(
        address _referrer
    ) external view returns (address[] memory) {
        return firstReferees[_referrer].values();
    }

    function getSecondReferees(
        address _referrer
    ) external view returns (address[] memory) {
        return secondReferees[_referrer].values();
    }

    function getFirstRefReward(
        address _referrer,
        address _referee
    ) external view returns (uint256) {
        return _calculateRefRewards(_referrer, _referee, 1);
    }

    function getSecondRefReward(
        address _referrer,
        address _referee
    ) external view returns (uint256) {
        return _calculateRefRewards(_referrer, _referee, 2);
    }

    function getTokenStaked(address _account) external view returns (uint256) {
        return tokensStaked[_account];
    }

    function getTotalRewardClaimed(
        address _account
    ) external view returns (uint256) {
        return totalRewardClaimed[_account];
    }

    function getRefRewardClaimed(
        address _account
    ) external view returns (uint256) {
        return totalRefRewardClaimed[_account];
    }

    function getCalculateMultiplier(
        address _account
    ) external view returns (uint256) {
        uint256 muiltiplier = _calculateMuliplier(_account);
        return muiltiplier;
    }

    function getAPY() external view returns (uint256) {
        return _rewardsPerTokenAndSec(duration) * 86400 * 365;
    }

    function getAPYSimulation(
        uint256 _duration
    ) external view returns (uint256) {
        return _rewardsPerTokenAndSec(_duration) * 86400 * 365;
    }

    function getRefereeCount(
        address _referrer
    ) external view returns (uint256) {
        return refereeCount[_referrer];
    }

    /// @notice pause the staking
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice unpause the staking
    function unpause() public onlyOwner {
        _unpause();
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }
}
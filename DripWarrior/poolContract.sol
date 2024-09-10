// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

// 0xcCc22A7fc54d184138dfD87B7aD24552cD4E0915
interface IBEP20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}

contract PoolContrcat is Initializable, OwnableUpgradeable, UUPSUpgradeable, AutomationCompatibleInterface {

    IBEP20 public usdcToken;
    
    uint256 public treasuryPoolAmount;
    uint256 public ownerShipPoolAmount;
    uint256 public totalStakedAmount;

    uint256 public tdividentPayoutPercentage;
    uint256 public odividentPayoutPercentage;
    uint256 public flowToTreasuryPercentage;
    uint256 public maintainceFeePercentage;

    uint256 public noOfUsers;
    address public multisigAddress;

    bool public checkOnce;
    uint256 public interval; // interval specifies the time between upkeeps
    uint256 public startingTime; 
    uint256 public lastTimeStamp; // lastTimeStamp tracks the last upkeep performed
    address public s_forwarderAddress;

    struct UserRegistered{

        bool blocked;
        uint256 receivedAmount;
        uint256 withdrawAmount;
        uint256 receiveFromTreasury;
        uint256 receiveFromOwneerShip;
        uint256 totalStakedAmount;
    }

    uint256 public totalProjects;
    mapping(address => bool) public alreadyAdded;
    mapping(uint256 => address) public totalUsers;
    mapping(uint256 => uint256) public tPPercentages;
    mapping(address => UserRegistered) public userRegistered;

    event AddTreasuery(uint256 _treasuryPoolAmount);
    event AddOwnership(uint256 _ownerShipPoolAmount);
    event AddFunds(uint256 _amount, uint256 _projectNo);
    event offInterval(address _owner, uint256 _interval);
    event Withdraw (address recipient, uint256 usdcAmount);
    event PercentageChanged(address _owner, uint256 _newPercentage);
    event SetForwarderAddress(address _owner, address _s_forwarderAddress);
    event UserBlocked(address owner,address blockUserAddress, bool blocked);
    event StakeTokens (address sender, address recepient,uint256 usdcAmount);
    event SetInterval(address _owner, uint256 _interval, uint256 _lastTimeStamp);
    event AddProject(uint256 projectId, uint256 OpPercentage,uint256 tpPercentage);
    event WeeklyTransfered(address caller,uint256  ownerShipPoolAmount, uint256  treasuryPoolAmount);

    error wrongValue(bool value);
    error wrongTime(uint256 time);
    error userBlocked(bool blocked);
    error wrongOwner(address owner);
    error wrongAmount(uint256 amount);
    error transferFailed(bool transfered);
    error wrongProjectNo(uint256 projectNO);
    error wrongAddress(address wrongAddress);
    error wrongPercentage(uint256 percentage);
    error wrongInterval(uint256 updateInterval);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner,address _usdcAddress,
        address _multisigAddress) initializer public {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        usdcToken = IBEP20(_usdcAddress);

            tPPercentages[0] = 5100; // 51 %
            tPPercentages[1] = 7500; // 75 % 
            tPPercentages[2] = 3500; // 35 %
            tPPercentages[3] = 7700; // 77 %
            tdividentPayoutPercentage = 5000; // 50 %
            odividentPayoutPercentage = 7500; // 75 %
            
            flowToTreasuryPercentage = 1500; // l5%
            maintainceFeePercentage = 1000; // 10 % 

            totalProjects = 4;
            multisigAddress = _multisigAddress;
    }

    

     function addProjects(uint256 _tPPercentage) external onlyOwner(){
        
        if(_tPPercentage <= 0){
            revert wrongPercentage(_tPPercentage);
        }

        tPPercentages[totalProjects] = _tPPercentage;
        totalProjects++;

        emit AddProject((totalProjects--), (10000 - _tPPercentage), _tPPercentage);
    }

    function addOwnership(uint256 _amount) external onlyOwner(){
        
        if(_amount <= 0){
            revert wrongAmount(_amount);
        }

        ownerShipPoolAmount += _amount;

        bool success = usdcToken.transferFrom(msg.sender,address(this),_amount );
        if(!success){
            revert transferFailed(success);
        }

        emit AddOwnership(ownerShipPoolAmount);
    }
    
    function addTreasuery(uint256 _amount) external onlyOwner(){
        
        if(_amount <= 0){
            revert wrongAmount(_amount);
        }


        treasuryPoolAmount += _amount;

        bool success = usdcToken.transferFrom(msg.sender,address(this),_amount );
        if(!success){
            revert transferFailed(success);
        }

        emit AddTreasuery(treasuryPoolAmount);
    }

    function stakeTokens(uint256 _amount) external  {
        
        if(_amount <= 0){
            revert wrongAmount(_amount);
        }
        
        if(userRegistered[msg.sender].blocked){
            revert userBlocked(userRegistered[msg.sender].blocked);
        }

        userRegistered[msg.sender].totalStakedAmount += _amount;
       
        if(!alreadyAdded[msg.sender]){
            
            totalUsers[noOfUsers] = msg.sender;
            alreadyAdded[msg.sender] = true;
            noOfUsers++;
        }

        totalStakedAmount += _amount;

        bool success =usdcToken.transferFrom(msg.sender,multisigAddress,_amount);
        
        if(!success){
            revert transferFailed(success);
        }

        emit StakeTokens(msg.sender,multisigAddress, _amount);

    }

    function reStakeTokens(uint256 _amount) external  {
        
        if(_amount <= 0){
            revert wrongAmount(_amount);
        }
       
        if(userRegistered[msg.sender].blocked){
            revert userBlocked(userRegistered[msg.sender].blocked);
        }

        require(_amount <= userRegistered[msg.sender].receivedAmount,"invalid _amount!");

        userRegistered[msg.sender].receivedAmount -= _amount;
        userRegistered[msg.sender].totalStakedAmount += _amount;
        
        ownerShipPoolAmount += _amount;
        totalStakedAmount += _amount;

        emit StakeTokens(msg.sender,address(this), _amount);

    }

   
    function addFunds(uint256 _amount, uint256 _projectNo)   external {

        if(_amount <= 0){
            revert wrongAmount(_amount);
        }

        if(_projectNo > totalProjects){
            revert wrongProjectNo(_projectNo);
        }
            
        calculateFees(_amount, tPPercentages[_projectNo]);
        
        bool success = usdcToken.transferFrom(msg.sender,address(this),_amount );
        if(!success){
            revert transferFailed(success);
        }

        emit AddFunds(_amount,_projectNo);
        
    }


    function calculateFees(uint256 _amount, uint256 _tPPercentage) private {
       
        uint256 oPPercentage = 10000 - _tPPercentage;
        uint256 ownerShipFee = calculatePercentage(_amount, oPPercentage);
        uint256 treasuryFee = calculatePercentage(_amount, _tPPercentage);

        ownerShipPoolAmount += ownerShipFee;
        treasuryPoolAmount += treasuryFee;
    }



    function weeklyTransfer() public bothOwner {
        
        ( uint256 remainFiftyOPool,uint256 dividentPayoutOPoolAmount, uint256 perPersonFromTPool)  = perPoolCalculation();
        
        require(ownerShipPoolAmount > 0 && treasuryPoolAmount > 0, "not enough amount");
        uint256 maxlimit;

        for(uint256 i = 0; i < noOfUsers; i++){

            if(!userRegistered[totalUsers[i]].blocked){

                uint256 eachSharePercentage = (userRegistered[totalUsers[i]].totalStakedAmount * (10000)) / (totalStakedAmount);
                
                uint256 eachSendAmount = calculatePercentage(dividentPayoutOPoolAmount, eachSharePercentage);
                ownerShipPoolAmount -= eachSendAmount;
                        
                maxlimit += eachSendAmount;
                treasuryPoolAmount -= perPersonFromTPool;

                userRegistered[totalUsers[i]].receiveFromTreasury = perPersonFromTPool;
                userRegistered[totalUsers[i]].receiveFromOwneerShip = eachSendAmount;
                
                uint256 totalSendAmount = eachSendAmount + perPersonFromTPool;
                userRegistered[totalUsers[i]].receivedAmount += totalSendAmount;

                require(maxlimit <= remainFiftyOPool, "Amount is greater then 50%");
            }
            
        }

        emit WeeklyTransfered(msg.sender, ownerShipPoolAmount, treasuryPoolAmount);

    }

    

    function perPoolCalculation() private returns(uint256, uint256,uint256){
        

        uint256 remainFiftyOPool = calculatePercentage(ownerShipPoolAmount, 5000);

        uint256 dividentPayoutOPoolAmount = calculatePercentage(remainFiftyOPool, odividentPayoutPercentage);
        uint256 fifteenPercenntToTPoolAmount = calculatePercentage(remainFiftyOPool, flowToTreasuryPercentage);
        uint256 tenPercenntToMaintenceAmount = calculatePercentage(remainFiftyOPool, maintainceFeePercentage);
        uint256 remainFiftyTPoolAmount = calculatePercentage(treasuryPoolAmount, tdividentPayoutPercentage);

        require(noOfUsers > 0, "no users!");
        
        uint256 perPersonFromTPool = remainFiftyTPoolAmount/noOfUsers;
        
        ownerShipPoolAmount -= (fifteenPercenntToTPoolAmount + tenPercenntToMaintenceAmount);
        treasuryPoolAmount += fifteenPercenntToTPoolAmount;

        bool success = usdcToken.transfer(multisigAddress, tenPercenntToMaintenceAmount);
        if(!success){
            revert transferFailed(success);
        }

        return (remainFiftyOPool,dividentPayoutOPoolAmount,perPersonFromTPool);
    }

    function checkUpkeep(bytes calldata /*checkData*/) external override view  returns (bool, bytes memory) {
      
        if(!checkOnce){

            if(block.timestamp != startingTime){
                revert wrongTime(startingTime);
            }
        }
        
        bool needsUpkeep = (block.timestamp - lastTimeStamp) > interval;

        return (needsUpkeep, bytes(""));
    }

    function performUpkeep(bytes calldata /*performData*/) external  {
        
        require(
            msg.sender == s_forwarderAddress,
            "This address does not have permission to call performUpkeep"
        );
        
        if(interval == 0){
            revert wrongInterval(interval);
        }
        
        lastTimeStamp = block.timestamp;
        checkOnce = true;
        weeklyTransfer();
        
    }


    
    function setInterval (uint256 _startingTime, uint256 updateInterval) external  onlyOwner{
         
        if(updateInterval <= 0){
            revert wrongInterval(updateInterval);
        }
        
        if(_startingTime > block.timestamp){
            revert wrongTime(_startingTime);
        }

        interval = updateInterval;
        startingTime = _startingTime;
        lastTimeStamp = block.timestamp;

        emit SetInterval(msg.sender, interval, lastTimeStamp);

    }

    function off () external  onlyOwner{
       
        interval = 0;
        checkOnce = false;
        
        emit offInterval(msg.sender, interval);
    }


    function setForwarderAddress(address forwarderAddress) external onlyOwner {
        
        if(forwarderAddress == address(0)){
            revert wrongAddress(forwarderAddress);
        }
        
        s_forwarderAddress = forwarderAddress;

        emit SetForwarderAddress(msg.sender, s_forwarderAddress);
    }

    function calculatePercentage(uint256 _totalStakeAmount,uint256 percentageNumber) private pure returns(uint256) {
        
        require(_totalStakeAmount !=0 , "_totalStakeAmount can not be zero");
        require(percentageNumber !=0 , "_totalStakeAmount can not be zero");
        uint256 serviceFee = _totalStakeAmount * (percentageNumber) / (10000);
        
        return serviceFee;
    }
    
    
    function userWithdrawAmoount(uint256 _amount) external {
        
        if(_amount <= 0){
            revert wrongAmount(_amount);
        }
        require(_amount <= userRegistered[msg.sender].receivedAmount, "invalid _amount!");

        userRegistered[msg.sender].receivedAmount -= _amount;
        userRegistered[msg.sender].withdrawAmount += _amount;
       
        bool success = usdcToken.transfer(msg.sender,_amount);
       
        if(!success){
            revert transferFailed(success);
        }

        emit Withdraw(msg.sender, _amount);
    }

    function blockUser(address _userAddress, bool value) external onlyOwner {
        
        if(_userAddress == address(0)){
            revert wrongAddress(_userAddress);
        }

        if(value != true && value != false){
            revert wrongValue(value);
        }

        if(value == true){

            userRegistered[_userAddress].blocked = true;
        }else{
       
            userRegistered[_userAddress].blocked = false;
        }
        
        emit UserBlocked(msg.sender,_userAddress, userRegistered[_userAddress].blocked);
    }


    
    function setTeasueryPercentages(uint256 _projectId,uint256 _newPerccentage) external onlyOwner {
        
        if(_newPerccentage <= 0){
            revert wrongPercentage(_newPerccentage);
        }
        
        tPPercentages[_projectId] = _newPerccentage;

        emit PercentageChanged(msg.sender, tPPercentages[_projectId]);
    }

    function settdividentPayoutPercentage(uint256 _newPerccentage) external onlyOwner {
        
        if(_newPerccentage <= 0){
            revert wrongPercentage(_newPerccentage);
        }
        
        tdividentPayoutPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, tdividentPayoutPercentage);

    }
    
    function setodividentPayoutPercentage(uint256 _newPerccentage) external onlyOwner {
        
        if(_newPerccentage <= 0){
            revert wrongPercentage(_newPerccentage);
        }
        
        odividentPayoutPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, odividentPayoutPercentage);
    }
    

    function setflowToTreasuryPercentage(uint256 _newPerccentage) external onlyOwner {
       
        if(_newPerccentage <= 0){
            revert wrongPercentage(_newPerccentage);
        }
        
        flowToTreasuryPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, flowToTreasuryPercentage);
    }

    function setmaintainceFeePercentage(uint256 _newPerccentage) external onlyOwner {
        
        if(_newPerccentage <= 0){
            revert wrongPercentage(_newPerccentage);
        }
        
        maintainceFeePercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, maintainceFeePercentage);
    }

    modifier bothOwner(){
        if(msg.sender != owner() && msg.sender != s_forwarderAddress){
            revert wrongOwner(msg.sender);
        }
        _;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}

// 0xcCc22A7fc54d184138dfD87B7aD24552cD4E0915

// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


interface IBEP20 {        
    
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}

contract PoolContrcat is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    IBEP20 public usdcToken;
    
    uint256 public treasuryPoolAmount;
    uint256 public ownerShipPoolAmount;
    uint256 public totalStakedAmount;

    uint256 public tdividentPayoutPercentage;
    uint256 public odividentPayoutPercentage;
    uint256 public flowToTreasuryPercentage;
    uint256 public maintainceFeePercentage;
    uint256 public ownerRemainingPercentage;

    uint256 public noOfUsers;
    address public multisigAddress;

    bool private locked;
    bool public permission;
    address public rewardSender;
    address public secondryOwner;


    struct UserRegistered{

        bool blocked;
        uint256 receivedAmount;
        uint256 withdrawAmount;
        uint256 receiveFromTreasury;
        uint256 receiveFromOwneerShip;
        uint256 totalStakedAmount;
    }

    uint256 public totalProjects;
    mapping(address => bool) public whiteListed;
    mapping(address => bool) public alreadyAdded;
    mapping(uint256 => address) public totalUsers;
    mapping(uint256 => uint256) public tPPercentages;
    mapping(address => UserRegistered) public userRegistered;

    event SetToken(address usdcToken);
    event AddTreasuery(uint256 _treasuryPoolAmount);
    event OwnershipAdded(uint256 _ownerShipPoolAmount);
    event AddFunds(uint256 _amount, uint256 _projectNo);
    event Withdraw (address recipient, uint256 usdcAmount);
    event SetPermission(bool _permission, bool permission);
    event OwnerChanged (address previousOwner, address newOwneer);
    event PercentageChanged(address _owner, uint256 _newPercentage);
    event multipleUserWhiteListed(address owner, uint256 usersLength);
    event SetForwarderAddress(address _owner, address _s_rewardSender);
    event UserBlocked(address owner,address blockUserAddress, bool blocked);
    event StakeTokens (address sender, address recepient,uint256 usdcAmount);
    event AddProject(uint256 projectId, uint256 OpPercentage,uint256 tpPercentage);
    event multipleUserAddeed(address owner,uint256 _amountLength, uint256 usersLength);
    event WeeklyTransfered(address caller,uint256  ownerShipPoolAmount, uint256  treasuryPoolAmount, uint256 noOfUsers,
    uint256 previousOwnershipAmount,uint256 previousTreasuryPoolAmount);

    error ArrayLengthMismatch();
    error wrongValue(bool value);
    error userBlocked(bool blocked);
    error wrongOwner(address owner);
    error wrongAmount(uint256 amount);
    error notAllowed(bool permission);
    error zeroUsers(uint256 noOfUsers);
    error NotWhitelisted(address user);
    error transferFailed(bool transfered);
    error notEnoughBalance(uint256 amount);
    error emptyAmount(uint256 amountLength);
    error wrongProjectNo(uint256 projectNO);
    error wrongAddress(address wrongAddress);
    error wrongPercentage(uint256 percentage);
    error emptyAddresses(uint256 addressLength);
    error notEnoughAmount(uint256 balanceAmount);
    error zeroPercentage(uint256 _eachSharePercentage, address _totalUsers);
    error emptyPools(uint256 ownerShipPoolAmount, uint256 treasuryPoolAmount);
    error wrongPercentages(uint256 _maintainceFeePercentage,uint256 _flowToTreasuryPercentage,
    uint256 _odividentPayoutPercentage);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address _usdcAddress,
        address _rewardSender,
        address _ownerTwo,
        address _multisigAddress)
        initializer public
    {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        usdcToken = IBEP20(_usdcAddress);

            tdividentPayoutPercentage = 5000; // 50 %
            ownerRemainingPercentage = 5000; // 50 %
            odividentPayoutPercentage = 7500; // 75 %
            
            flowToTreasuryPercentage = 1500; // l5%
            maintainceFeePercentage = 1000; // 10 % 

            multisigAddress = _multisigAddress;
            secondryOwner = _ownerTwo;
            rewardSender = _rewardSender;
            permission = true;
            whiteListed[owner()] = true;
            whiteListed[secondryOwner] = true;
    }

    

     function addProjects(uint256 _tPPercentage) external bothOwner(){
        
        if(_tPPercentage <= 0 || _tPPercentage > 10000 ){
            revert wrongPercentage(_tPPercentage);
        }

        tPPercentages[totalProjects] = _tPPercentage;
        totalProjects++;


        emit AddProject((totalProjects), (10000 - _tPPercentage), _tPPercentage);
    }

    function addOwnershipPool(uint256 _amount) external bothOwner(){
        
        if(_amount <= 0){
            revert wrongAmount(_amount);
        }

        ownerShipPoolAmount += _amount;

        bool success = usdcToken.transferFrom(msg.sender,address(this),_amount );
        if(!success){
            revert transferFailed(success);
        }

        emit OwnershipAdded(ownerShipPoolAmount);
    }
    
    function addTreasueryPool(uint256 _amount) external bothOwner(){
        
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

        if (!whiteListed[msg.sender]) {
            revert NotWhitelisted(msg.sender);
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

        bool success = usdcToken.transferFrom(msg.sender,multisigAddress,_amount);
        
        if(!success){
            revert transferFailed(success);
        }

        emit StakeTokens(msg.sender,multisigAddress, _amount);

    }

   
    function stakeTokensByOwner(uint256[] memory _amount, address[] memory users) external bothOwner() {
        
         if(_amount.length <= 0){

            revert emptyAmount(_amount.length);
        }
        if(users.length <= 0){

            revert emptyAddresses(users.length);
        }

        if (users.length != _amount.length) {
            revert ArrayLengthMismatch();
        }

        for(uint i=0 ;i < _amount.length; i++){

            if(users[i] == address(0)){
                revert wrongAddress(users[i]);
            }

            if (!alreadyAdded[users[i]]) {
              
                totalUsers[noOfUsers] = users[i]; 
                whiteListed[users[i]] = true;
                alreadyAdded[users[i]] = true; 
                noOfUsers++;
            }

            userRegistered[users[i]].totalStakedAmount += _amount[i] ;
            totalStakedAmount += _amount[i];
        }

        emit multipleUserAddeed(msg.sender,_amount.length,users.length);
    }


    function reStakeTokens(uint256 _amount) external  {
        
        if(_amount <= 0){
            revert wrongAmount(_amount);
        }
       
        if(userRegistered[msg.sender].blocked){
            revert userBlocked(userRegistered[msg.sender].blocked);
        }

        if(userRegistered[msg.sender].receivedAmount < _amount){
            revert notEnoughBalance(_amount);
        }

        userRegistered[msg.sender].receivedAmount -= _amount;
        userRegistered[msg.sender].totalStakedAmount += _amount;
        
        ownerShipPoolAmount += _amount;
        totalStakedAmount += _amount;

        emit StakeTokens(msg.sender,address(this), _amount);

    }

   
    function addFunds(uint256 _amount, uint256 _projectNo) external bothOwner() {

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


    function weeklyTransfer() public PermissionGranted() bothOwner() {

        if(msg.sender != rewardSender && msg.sender != owner() && msg.sender != secondryOwner){
            revert wrongOwner(msg.sender);
        }

        if(ownerShipPoolAmount <= 0 && treasuryPoolAmount <= 0){
            revert emptyPools(ownerShipPoolAmount,treasuryPoolAmount);
        }

        uint256 previousOwnershipAmount = ownerShipPoolAmount;
        uint256 previousTreasuryPoolAmount = treasuryPoolAmount;
        
        ( uint256 remainFiftyOPool,uint256 dividentPayoutOPoolAmount, uint256 perPersonFromTPool)  = perPoolCalculation();
        
       
        uint256 maxlimit;

        for(uint256 i = 0; i < noOfUsers; i++){

            if(!userRegistered[totalUsers[i]].blocked){

                uint256 eachSharePercentage = (userRegistered[totalUsers[i]].totalStakedAmount * (10000)) / (totalStakedAmount);
                
                uint256 eachSendAmount;
                
                if(eachSharePercentage > 0){
                    
                    eachSendAmount = calculatePercentage(dividentPayoutOPoolAmount, eachSharePercentage);
                    
                    ownerShipPoolAmount -= eachSendAmount;        
                    maxlimit += eachSendAmount;
                    
                    userRegistered[totalUsers[i]].receiveFromOwneerShip += eachSendAmount;
                    
                    require(maxlimit <= remainFiftyOPool, "Amount is greater then 50%");
                }

                treasuryPoolAmount -= perPersonFromTPool;
                userRegistered[totalUsers[i]].receiveFromTreasury += perPersonFromTPool;

                uint256 totalSendAmount = eachSendAmount + perPersonFromTPool;
                userRegistered[totalUsers[i]].receivedAmount += totalSendAmount;
            }
        }

        emit WeeklyTransfered(
            msg.sender,
            ownerShipPoolAmount, 
            treasuryPoolAmount, 
            noOfUsers, 
            previousOwnershipAmount,
            previousTreasuryPoolAmount);
    }

    

    function perPoolCalculation() private returns(uint256, uint256,uint256){
        

        uint256 remainFiftyOPool = calculatePercentage(ownerShipPoolAmount, ownerRemainingPercentage);

        uint256 dividentPayoutOPoolAmount = calculatePercentage(remainFiftyOPool, odividentPayoutPercentage);
        uint256 fifteenPercenntToTPoolAmount = calculatePercentage(remainFiftyOPool, flowToTreasuryPercentage);
        uint256 tenPercenntToMaintenceAmount = calculatePercentage(remainFiftyOPool, maintainceFeePercentage);
        uint256 remainFiftyTPoolAmount = calculatePercentage(treasuryPoolAmount, tdividentPayoutPercentage);
       
        if(noOfUsers <= 0){
            revert zeroUsers(noOfUsers);
        }
        
        uint256 perPersonFromTPool = remainFiftyTPoolAmount/noOfUsers;
        
        ownerShipPoolAmount -= (fifteenPercenntToTPoolAmount + tenPercenntToMaintenceAmount);
        treasuryPoolAmount += fifteenPercenntToTPoolAmount;

        bool success = usdcToken.transfer(multisigAddress, tenPercenntToMaintenceAmount);
        if(!success){
            revert transferFailed(success);
        }

        return (remainFiftyOPool,dividentPayoutOPoolAmount,perPersonFromTPool);
    }


    function setRewardSender(address _rewardSender) external bothOwner() {
        
        if(_rewardSender == address(0)){
            revert wrongAddress(_rewardSender);
        }
        
        rewardSender = _rewardSender;

        emit SetForwarderAddress(msg.sender, rewardSender);
    }

    function calculatePercentage(uint256 _totalStakeAmount,uint256 percentageNumber) private pure returns(uint256) {
        
        if(_totalStakeAmount <= 0){
            revert wrongAmount(_totalStakeAmount);
        }
        if(percentageNumber <= 0){
            revert wrongPercentage(percentageNumber);
        }
       
        uint256 serviceFee = _totalStakeAmount * (percentageNumber) / (10000);
        
        return serviceFee;
    }
    

    function userWithdrawAmoount(uint256 _amount) external nonReentrant() {
        
        if(_amount == 0){
            revert wrongAmount(_amount);
        }

        if(_amount > userRegistered[msg.sender].receivedAmount){
            revert notEnoughAmount(userRegistered[msg.sender].receivedAmount);
        }

        userRegistered[msg.sender].receivedAmount -= _amount;
        userRegistered[msg.sender].withdrawAmount += _amount;
       
        bool success = usdcToken.transfer(msg.sender,_amount);
       
        if(!success){
            revert transferFailed(success);
        }

        emit Withdraw(msg.sender, _amount);
    }


    function ownerWithdrawAmoount(uint256 _amount) external nonReentrant() bothOwner() {
        
        if(_amount == 0){
            revert wrongAmount(_amount);
        }

        if(_amount > usdcToken.balanceOf(address(this))){
            revert notEnoughAmount(usdcToken.balanceOf(address(this)));
        }
       
        bool success = usdcToken.transfer(msg.sender,_amount);
       
        if(!success){
            revert transferFailed(success);
        }

        emit Withdraw(msg.sender, _amount);
    }

    function blockUser(address _userAddress, bool value) external bothOwner(){
        
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

    function setTeasueryPercentages(uint256 _projectId,uint256 _newPerccentage) external bothOwner() {
        
        if(_newPerccentage <= 0){
            revert wrongPercentage(_newPerccentage);
        }
        
        tPPercentages[_projectId] = _newPerccentage;

        emit PercentageChanged(msg.sender, tPPercentages[_projectId]);
    }


    function settdividentPayoutPercentage(uint256 _newPerccentage) external bothOwner() {
        
        if(_newPerccentage <= 0){
            revert wrongPercentage(_newPerccentage);
        }
        
        tdividentPayoutPercentage = _newPerccentage;

        emit PercentageChanged(msg.sender, tdividentPayoutPercentage);

    }
    

    function OPpercentageDistribution(
        
        uint256 _maintainceFeePercentage,
        uint256 _flowToTreasuryPercentage,
        uint256 _odividentPayoutPercentage) external bothOwner() {
        
        if(_maintainceFeePercentage <= 0 || _flowToTreasuryPercentage <= 0 || _odividentPayoutPercentage <= 0){
            revert wrongPercentages(_maintainceFeePercentage, _flowToTreasuryPercentage, _odividentPayoutPercentage);
        }

        if(_maintainceFeePercentage + _flowToTreasuryPercentage + _odividentPayoutPercentage > 10000){
            revert wrongPercentage(_maintainceFeePercentage + _flowToTreasuryPercentage + _odividentPayoutPercentage);
        }
        
        maintainceFeePercentage = _maintainceFeePercentage;
        flowToTreasuryPercentage = _flowToTreasuryPercentage;
        odividentPayoutPercentage = _odividentPayoutPercentage;

        emit PercentageChanged(msg.sender, maintainceFeePercentage);
    }

    function changeOwnerShipTwo(address ownerAddressTwo) external bothOwner(){
        
        if(ownerAddressTwo == address(0)){
            revert wrongAddress(ownerAddressTwo);
        }
        
        address previousOwner = secondryOwner;
        secondryOwner = ownerAddressTwo;
       
        emit OwnerChanged(previousOwner, ownerAddressTwo);
    }

    function setPermission(bool _permission) external bothOwner() {
        
        if(_permission != true && _permission != false){
            revert wrongValue(_permission);
        }
        
        permission = _permission;
        
        emit SetPermission(_permission, permission);
    }

    function setToken(address  _tokenAddress) external bothOwner() {
        
        if(_tokenAddress == address(0)){
            revert wrongAddress(_tokenAddress);
        }
        
        usdcToken = IBEP20(_tokenAddress);
        
        emit SetToken(address(usdcToken));
    }

    modifier bothOwner(){
        if(msg.sender != owner() && msg.sender != secondryOwner){
            revert wrongOwner(msg.sender);
        }
        _;
    }

    modifier PermissionGranted() {
        if(!permission){
            revert notAllowed(permission);
        }
        _;
    }

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}

// 0xcCc22A7fc54d184138dfD87B7aD24552cD4E0915// SPDX-License-Identifier: MIT

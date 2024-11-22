// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "hardhat/console.sol";

contract MyContract is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    ERC20Upgradeable public usdcToken;

    struct MarketInfo {

        bool resolved;
        uint256 endTime;
        uint256 totalNoBets;
        uint256 totalYesBets;
        uint256 totalYesShares;
        uint256 totalNoShares;
        uint256[2] initialPrice;
        uint256 totalBetAmountOnYes;
        uint256 totalBetAmountOnNo;
    }

    struct UserInfo{

        uint256 listNo;
        uint256 noBetAmount;
        uint256 rewardAmount;
        uint256 yesBetAmount;
        uint256 noShareAmount;
        uint256 yesShareAmount;
        uint256 finalShareAmount;
        mapping(uint256 => bool) betOn;
    }

    struct SellInfo{
        bool list;
        bool sold;
        address owner;
        uint256 price;
        uint256 noShare;
        uint256 yesShare;
        uint256 amount;
        uint256 listOn;
    }

    uint256 public totalUsers;
    uint256 public profitPercentage;

    mapping(uint256 => address) public eachUser;
    mapping(address => UserInfo) public userInfo;
    mapping(address => bool) public alreadyAdded;
    mapping(address => MarketInfo) public marketInfo;
    mapping(address => mapping(uint256 => SellInfo)) public sellInfo;
    

    event Bet(address indexed user,uint256 indexed _amount,uint256 _betOn);
    event SellShare(address indexed user, uint256 listNo,  uint256 onPrice);
    event BuyShares(address buyer, address seller, uint256 _amountBBuyed, uint256 onPrice);
    event ResolveMarket(address ownerAddress, uint256 ownerAmount, uint256 totalwinShares, uint256 totalAmoount);

    error marketResolved();
    error notBet(bool beted);
    error alreadySold(bool sold);
    error wrongPrice(uint256 price);
    error notListed(uint256 listNo);
    error wrongOwner(address owner);
    error wrongAmount(uint256 amount);
    error transferFaild(bool transferd);
    error transferFailed(bool transfered);
    error wrongBetIndex(uint256 betIndex);
    error wrongNoOfShares(uint256 _noOfShares);
    error zeroPercentageAmount(uint256 _amount);
    error notEnoughAmount(uint256 _useerAmount);
    error notResolvedBeforeTime(uint256 endTime);
    error contractLowbalance(uint256 contractBalance);
    error zeropercentageNumber(uint256 percentageNumber);
    error contractLowbalanceForOwner(uint256 contractBalance);


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner,address _usdcToken,uint256 _endTime) initializer public {
       
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
      
        marketInfo[address(this)].endTime = _endTime;
        
        marketInfo[address(this)].totalYesShares = 10000 * 1e6;
        marketInfo[address(this)].totalNoShares = 10000 * 1e6;
        
        (marketInfo[address(this)].initialPrice[0],
            marketInfo[address(this)].initialPrice[1]) = PriceCalculation();
            
        usdcToken = ERC20Upgradeable(_usdcToken);
        profitPercentage = 1000; // 10 %
    }

     function bet(uint256 _amount, uint256 _betOn) external {

        if(_betOn != 0 && _betOn != 1){
            revert wrongBetIndex(_betOn);
        }
        if(_amount <= 0){
            revert wrongAmount(_amount);
        }
        
        if(marketInfo[address(this)].resolved){
            revert marketResolved();
        }

        if(!alreadyAdded[msg.sender]){
            
            eachUser[totalUsers] = msg.sender;
            alreadyAdded[msg.sender] = true;
            totalUsers++;
        }

        updateInfo( _amount, _betOn);
        userInfo[msg.sender].betOn[_betOn] = true;

        // console.log("userShares: ", userShares);
        (marketInfo[address(this)].initialPrice[0],marketInfo[address(this)].initialPrice[1]) = PriceCalculation();
        
        
        bool success = usdcToken.transferFrom(msg.sender, address(this), _amount);
        if(!success){
            revert transferFailed(success);
        }

        emit Bet(msg.sender, _amount, _betOn);
    }

    function updateInfo(uint256 _amount, uint256 _betOn)  private {
        
        uint256 _totalShares = marketInfo[address(this)].totalYesShares * marketInfo[address(this)].totalNoShares;
        console.log("_totalShares: ", _totalShares);

        uint256 userShares;
        
        if(_betOn == 0){

            userShares = calculateShares(_amount,_betOn);
            console.log("userShares: ", userShares);
            
            userInfo[msg.sender].noBetAmount += _amount;
            userInfo[msg.sender].noShareAmount += userShares;
            
            console.log("userInfo[msg.sender].noShareAmount: ", userInfo[msg.sender].noShareAmount);
            
            marketInfo[address(this)].totalNoBets++;
            marketInfo[address(this)].totalBetAmountOnNo += _amount;
            console.log("marketInfo[address(this)].totalBetAmountOnNo: ", marketInfo[address(this)].totalBetAmountOnNo);



            console.log("marketInfo[address(this)].totalNoShares: ", marketInfo[address(this)].totalNoShares);
            marketInfo[address(this)].totalNoShares -= userShares;
            console.log("marketInfo[address(this)].totalNoShares: ", marketInfo[address(this)].totalNoShares);
            



            console.log("marketInfo[address(this)].totalYesShares: ", marketInfo[address(this)].totalYesShares);
            console.log("_totalShares: ", _totalShares);
            marketInfo[address(this)].totalYesShares = (_totalShares/marketInfo[address(this)].totalNoShares);

            console.log("marketInfo[address(this)].totalYesShares: ", marketInfo[address(this)].totalYesShares);

        }else{

            userShares = calculateShares(_amount,_betOn);
            console.log("userShares: ", userShares);

            userInfo[msg.sender].yesBetAmount += _amount;
            userInfo[msg.sender].yesShareAmount += userShares;

            console.log("userInfo[msg.sender].yesShareAmount: ", userInfo[msg.sender].yesShareAmount);
            
            marketInfo[address(this)].totalYesBets++; 
            marketInfo[address(this)].totalBetAmountOnYes += _amount;  

            
            
            
            console.log("marketInfo[address(this)].totalYesShares: ", marketInfo[address(this)].totalYesShares);
            marketInfo[address(this)].totalYesShares -= userShares;
            console.log("marketInfo[address(this)].totalYesShares: ", marketInfo[address(this)].totalYesShares);

            
            
            console.log("marketInfo[address(this)].totalYesShares: ", marketInfo[address(this)].totalNoShares);
            console.log("_totalShares: ", _totalShares);
            marketInfo[address(this)].totalNoShares = (_totalShares/ marketInfo[address(this)].totalYesShares);

            console.log("marketInfo[address(this)].totalYesShares: ", marketInfo[address(this)].totalNoShares);
        }
    }




    function PriceCalculation() public view returns(uint256 , uint256 ) {
       
        uint256 __totalShares = marketInfo[address(this)].totalYesShares + marketInfo[address(this)].totalNoShares; // Total number of shares

        console.log("__totalShares: ", __totalShares);
        
        console.log("marketInfo[address(this)].totalYesShares: ", marketInfo[address(this)].totalYesShares);

        uint256 _noPrice =  ((marketInfo[address(this)].totalYesShares * 1e6)/ __totalShares); // Price of "Yes" shares in wei
        console.log("noPrice: ",_noPrice);
        
        console.log("marketInfo[address(this)].totalNoShares ", marketInfo[address(this)].totalNoShares);

        uint256 _yesPrice = ((marketInfo[address(this)].totalNoShares * 1e6) / __totalShares); // Price of "No" shares in wei
        console.log("yesPrice: ",_yesPrice);
        
        return(_noPrice,_yesPrice);
    }

    function sellShare(uint256 _noOfShares, uint256 _price, uint256 _sellOf) external {
        
        if(_sellOf != 0 && _sellOf != 1){
            revert wrongBetIndex(_sellOf);
        }
        if(_noOfShares <= 0){
            revert wrongNoOfShares(_noOfShares);
        }
        
        if(marketInfo[address(this)].resolved){
            revert marketResolved();
        }

        if(!userInfo[msg.sender].betOn[_sellOf]){
            revert notBet(userInfo[msg.sender].betOn[_sellOf]);
        }
        if(_price <= 0){
            revert wrongPrice(_price);
        }
        
        
        if(_sellOf == 0){

            if(_noOfShares > userInfo[msg.sender].noShareAmount){
                revert notEnoughAmount(userInfo[msg.sender].noShareAmount);
            }

            sellInfo[msg.sender][userInfo[msg.sender].listNo].noShare = _noOfShares; 

        }else{

            if(_noOfShares > userInfo[msg.sender].yesShareAmount){
                revert notEnoughAmount(userInfo[msg.sender].yesShareAmount);
            }
            sellInfo[msg.sender][userInfo[msg.sender].listNo].yesShare = _noOfShares; 
        }
        

        sellInfo[msg.sender][userInfo[msg.sender].listNo].list = true;
        sellInfo[msg.sender][userInfo[msg.sender].listNo].price = _price; 
        sellInfo[msg.sender][userInfo[msg.sender].listNo].listOn = _sellOf;
        sellInfo[msg.sender][userInfo[msg.sender].listNo].owner = msg.sender; 
        
        userInfo[msg.sender].listNo++;
    
        emit SellShare(msg.sender, userInfo[msg.sender].listNo, _price);
    }

    function buyShare(uint256 _listNo, address _owner) external {
        
        if(!sellInfo[_owner][_listNo].list){
            revert notListed(_listNo);
        }
        if(sellInfo[_owner][_listNo].sold){
            revert alreadySold(sellInfo[_owner][_listNo].sold);
        }
        
        if(marketInfo[address(this)].resolved){
            revert marketResolved();
        }

        if(sellInfo[_owner][_listNo].owner != _owner){
            revert wrongOwner(_owner);
        }
        
        if(sellInfo[_owner][_listNo].listOn == 0){

            userInfo[_owner].noShareAmount -= sellInfo[_owner][_listNo].noShare;
            userInfo[msg.sender].noShareAmount += sellInfo[_owner][_listNo].noShare;
            userInfo[msg.sender].noBetAmount += sellInfo[_owner][_listNo].price;

        }else{

            userInfo[_owner].noShareAmount -= sellInfo[_owner][_listNo].yesShare;
            userInfo[msg.sender].noShareAmount += sellInfo[_owner][_listNo].yesShare;
            userInfo[msg.sender].yesBetAmount += sellInfo[_owner][_listNo].price;
        }
        
        userInfo[msg.sender].betOn[sellInfo[_owner][_listNo].listOn] = true;
        sellInfo[_owner][_listNo].sold = true;

        if(!alreadyAdded[msg.sender]){
            
            eachUser[totalUsers] = msg.sender;
            alreadyAdded[msg.sender] = true;
            totalUsers++;
        }

        bool success = usdcToken.transferFrom(
            msg.sender,
            _owner,
            sellInfo[_owner][_listNo].price
        );

        if(!success){
            revert transferFaild(success);
        }

        emit BuyShares(msg.sender,_owner, sellInfo[_owner][_listNo].amount, sellInfo[_owner][_listNo].price);
    }

    function resolveMarket(uint256 winningIndex) external   {
        
        if(winningIndex != 0 && winningIndex != 1){
            revert wrongBetIndex(winningIndex);
        }
        
        if(marketInfo[address(this)].resolved){
            revert marketResolved();
        }

        // if(marketInfo[address(this)].endTime > block.timestamp){
        //     revert notResolvedBeforeTime(marketInfo[address(this)].endTime);
        // }

        uint256 _ownerAmount;
        uint256 totalWinnerShare;
        uint256 totalAmount = marketInfo[address(this)].totalBetAmountOnNo + marketInfo[address(this)].totalBetAmountOnYes;
        
        if(winningIndex == 0){

            totalWinnerShare = marketInfo[address(this)].totalNoShares;
        }else{

            totalWinnerShare = marketInfo[address(this)].totalYesShares;
        }

        for (uint256 i = 0; i < totalUsers; i++) {

            if(userInfo[eachUser[i]].betOn[winningIndex]) {

                uint256 userSharePercentage;
                
                if(winningIndex == 0){
                    
                    userSharePercentage = calculatePercentage(userInfo[eachUser[i]].noShareAmount,totalWinnerShare);
                }else{

                    userSharePercentage = calculatePercentage(userInfo[eachUser[i]].yesShareAmount,totalWinnerShare);
                }

                uint256 userAmount = calculatePercentageAmount(totalAmount,userSharePercentage);
                uint256 userProfitAmount;

                if(winningIndex == 0){

                     userProfitAmount = userAmount - userInfo[eachUser[i]].noBetAmount;
                }else{

                    userProfitAmount = userAmount - userInfo[eachUser[i]].yesBetAmount;
                }

                uint256 tenPercentAmount = calculatePercentageAmount(userProfitAmount,profitPercentage);

                _ownerAmount += tenPercentAmount;

                if(usdcToken.balanceOf(address(this)) < (userAmount - tenPercentAmount)){
                    revert contractLowbalance(usdcToken.balanceOf(address(this)));
                }

                bool success = usdcToken.transfer(
                    eachUser[i],
                    userAmount - tenPercentAmount
                );
                if(!success){
                    revert transferFaild(success);
                }

            }
        }

        if(usdcToken.balanceOf(address(this)) < _ownerAmount){
            revert contractLowbalanceForOwner(usdcToken.balanceOf(address(this)));
        }

        marketInfo[address(this)].resolved = true;
        
        bool success1 = usdcToken.transfer(owner(),_ownerAmount);
        if(!success1){
            revert transferFaild(success1);
        }

        emit ResolveMarket( owner(), _ownerAmount, totalWinnerShare, totalAmount);
    }

    

    function calculatePercentage(uint256 userAmount, uint256 totalAmount) public pure returns (uint256) {
        
        require(userAmount > 0, "user amount must be greater than zero");
        require(totalAmount > 0, "Total amount must be greater than zero");

        uint256 percentage = (userAmount * 10000) / totalAmount;
        console.log("percentage : ",percentage);

        return percentage;
    }

    
    function calculateShares(uint256 _amount, uint256 _betOn ) public view returns (uint256) {

        uint256 price =  marketInfo[address(this)].initialPrice[_betOn];
        
        require(price != 0, "_price cannot be zero");
        require(_amount != 0, "_amount cannot be zero");

        uint256 result = (_amount * 1e6) / price;

        console.log("result: ",result);
        
        return result;
    }


    function calculatePercentageAmount(uint256 _amount,uint256 percentageNumber) private pure returns(uint256) {
        
        if(_amount <= 0 ){
            revert zeroPercentageAmount(_amount);
        }
        if(_amount <= 0 ){
            revert zeropercentageNumber(percentageNumber);
        }
    
        uint256 serviceFee = (_amount * percentageNumber)/(10000);
        
        return serviceFee;
    }


    function getInitialPrices() public view returns (uint256, uint256) {
        return (marketInfo[address(this)].initialPrice[0], marketInfo[address(this)].initialPrice[1]);
    }


    function readSellInfo(address _owner, uint256 _id) public view returns (
        bool list,
        bool sold,
        address owner,
        uint256 price,
        uint256 amount,
        uint256 listOn
    ) {
        return (
            sellInfo[_owner][_id].list,
            sellInfo[_owner][_id].sold,
            sellInfo[_owner][_id].owner,
            sellInfo[_owner][_id].price,
            sellInfo[_owner][_id].amount,
            sellInfo[_owner][_id].listOn
        );
    }

    function userBetOn(address _user, uint256 _betIndex) public view returns (bool) {
        return userInfo[_user].betOn[_betIndex];
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}


//  function PriceCalculation(uint256 totalBetAmountOnNo, uint256 totalBetAmountOnYes) public view returns(uint256, uint256){
        
//          uint256 originalNoPrice = marketInfo[address(this)].initialPrice[0];
//          uint256 originalYesPrice = marketInfo[address(this)].initialPrice[1];
         
//          uint256 totalBetAmount = totalBetAmountOnNo + totalBetAmountOnYes;

//         if(totalBetAmountOnNo != 0){
            
//             originalNoPrice = ((totalBetAmountOnNo * 1e6)/(totalBetAmount));
//             console.log("originalNoPrice: ",originalNoPrice);
//         }
//         if(totalBetAmountOnYes != 0){
           
//             originalYesPrice = ((totalBetAmountOnYes * 1e6)/(totalBetAmount));
//             console.log("originalYesPrice: ",originalYesPrice);
//         }

//         return(originalNoPrice, originalYesPrice);
//     }

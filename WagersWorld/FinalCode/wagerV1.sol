// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Wager is Ownable {

    ERC20 public usdcToken;

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
    error wrongBetIndex(uint256 betIndex);
    error wrongNoOfShares(uint256 _noOfShares);
    error transferFailed(bool transfered);
    error zeroPercentageAmount(uint256 _amount);
    error notEnoughAmount(uint256 _useerAmount);
    error notResolvedBeforeTime(uint256 endTime);
    error contractLowbalance(uint256 contractBalance);
    error zeropercentageNumber(uint256 percentageNumber);
    error contractLowbalanceForOwner(uint256 contractBalance);


    constructor(
        address initialOwner,
        address _usdcToken,
        uint256 _endTime ) 

        Ownable(initialOwner) {

            marketInfo[address(this)].endTime = _endTime;
            marketInfo[address(this)].initialPrice[0] = 500000;
            marketInfo[address(this)].initialPrice[1] = 500000;
            usdcToken = ERC20(_usdcToken);
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

        uint256 userShares;

        if(_betOn == 0 ){

            userShares = calculateShares(_amount,_betOn);
            
            userInfo[msg.sender].noBetAmount += _amount;
            userInfo[msg.sender].noShareAmount += userShares;
            
            marketInfo[address(this)].totalNoBets++;
            marketInfo[address(this)].totalNoShares += userShares;
            marketInfo[address(this)].totalBetAmountOnNo += _amount;

        }else {

            userShares = calculateShares(_amount,_betOn);

            userInfo[msg.sender].yesBetAmount += _amount;
            userInfo[msg.sender].yesShareAmount += userShares;
            
            marketInfo[address(this)].totalYesBets++; 
            marketInfo[address(this)].totalYesShares += userShares;  
            marketInfo[address(this)].totalBetAmountOnYes += _amount;  

        }

        userInfo[msg.sender].betOn[_betOn] = true;


        (marketInfo[address(this)].initialPrice[0],marketInfo[address(this)].initialPrice[1]) = 
            PriceCalculation(marketInfo[address(this)].totalBetAmountOnNo, marketInfo[address(this)].totalBetAmountOnYes);
        
        
        bool success = usdcToken.transferFrom(msg.sender, address(this), _amount);
        if(!success){
            revert transferFailed(success);
        }

        emit Bet(msg.sender, _amount, _betOn);
    }


    function PriceCalculation(uint256 totalBetAmountOnNo, uint256 totalBetAmountOnYes) public view returns(uint256, uint256){
        
         uint256 originalNoPrice = marketInfo[address(this)].initialPrice[0];
         uint256 originalYesPrice = marketInfo[address(this)].initialPrice[1];

         uint256 totalBetAmount = totalBetAmountOnNo + totalBetAmountOnYes;

        if(totalBetAmountOnNo != 0){
            
            originalNoPrice = ((totalBetAmountOnNo * 1e6)/(totalBetAmount));
        }
        if(totalBetAmountOnYes != 0){
           
            originalYesPrice = ((totalBetAmountOnYes * 1e6)/(totalBetAmount));
        }

        return(originalNoPrice, originalYesPrice);
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

        return percentage;
    }

    
    function calculateShares(uint256 _amount, uint256 _betOn ) public view returns (uint256) {

        uint256 price =  marketInfo[address(this)].initialPrice[_betOn];
        
        require(price != 0, "_price cannot be zero");
        require(_amount != 0, "_amount cannot be zero");

        uint256 result = (_amount * 1e6) / price;

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
}

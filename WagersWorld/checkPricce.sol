// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract Market is Ownable {

    ERC20 public usdcToken;

    struct MarketInfo {

        bool resolved;
        uint256 endTime;
        uint256 totalBets;
        uint256 totalAmount;
        uint256[2] initialPrice;
        uint256 totalBetsOnYes;
        uint256 totalBetsOnNo;
    }

    struct UserInfo{

        uint256 listNo;
        uint256 noBetAmount;
        uint256 rewardAmount;
        uint256 yesBetAmount;
        uint256 shareAmount;
        mapping(uint256 => bool) betOn;
    }

    struct SellInfo{
        bool list;
        bool sold;
        address owner;
        uint256 price;
        uint256 amount;
        uint256 listOn;
    }

    uint256 public totalUsers;
    uint256 public profitPercentage;

    mapping(uint256 => address) public eachUser;
    mapping(address => UserInfo) public userInfo;
    mapping(address => MarketInfo) public marketInfo;
    mapping(address => mapping(uint256 => SellInfo)) public sellInfo;
    

    event Bet(address indexed user,uint256 indexed _amount,uint256 _betOn);
    event SellShare(address indexed user, uint256 listNo,  uint256 onPrice);
    event BuyShare(address buyer, address seller, uint256 _amountBBuyed, uint256 onPrice);
    event ResolveMarket(address ownerAddress, uint256 ownerAmount, uint256 perShareAmount, uint256 winningIndex);

    error marketResolved();
    error notBet(bool beted);
    error alreadySold(bool sold);
    error wrongPrice(uint256 price);
    error notListed(uint256 listNo);
    error wrongOwner(address owner);
    error wrongAmount(uint256 amount);
    error wrongBetIndex(uint256 betIndex);
    error notResolvedBeforeTime(uint256 endTime);
    error contractLowbalance(uint256 contractBalance);
    error contractLowbalanceForOwner(uint256 contractBalance);


    constructor(
        address initialOwner,
        address _usdcToken,
        uint256 _endTime ) 

        Ownable(initialOwner) {

            marketInfo[address(this)].endTime = _endTime;
            marketInfo[address(this)].initialPrice[0] = 500000000000000000;
            marketInfo[address(this)].initialPrice[1] = 500000000000000000;
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
        

        if(!userInfo[msg.sender].betOn[_betOn]){     
            eachUser[totalUsers] = msg.sender;
            totalUsers++;
        }

        if(_betOn == 0 ){

            marketInfo[address(this)].totalBetsOnNo++;
            userInfo[msg.sender].noBetAmount += _amount;

        }else {

            marketInfo[address(this)].totalBetsOnYes++;  
            userInfo[msg.sender].yesBetAmount += _amount;
        }

        marketInfo[address(this)].totalAmount += _amount;
        marketInfo[address(this)].totalBets++;
        userInfo[msg.sender].betOn[_betOn] = true;


        (marketInfo[address(this)].initialPrice[0],marketInfo[address(this)].initialPrice[1]) = 
            PriceCalculation(marketInfo[address(this)].totalBetsOnNo, marketInfo[address(this)].totalBetsOnYes);
       
        bool success = usdcToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");

        emit Bet(msg.sender, _amount, _betOn);
    }


    function PriceCalculation(uint256 _totalBetAmountOnLahore, uint256 _totalBetAmountOnKarachi) public pure returns (uint256 yesSharePrice, uint256 noSharePrice) {
        uint256 _totalBet = _totalBetAmountOnLahore + _totalBetAmountOnKarachi;
        if (_totalBet == 0) {
            return (0.5 ether, 0.5 ether); // Starting price is 50 cents for both teams
        }

        uint256 lahoreRatio = (_totalBetAmountOnKarachi * 100) / _totalBet;
        uint256 karachiRatio = (_totalBetAmountOnLahore * 100) / _totalBet;

        yesSharePrice = clamp(((lahoreRatio * 99) / 100) + 1, 1, 100) * 1e16;
        noSharePrice = clamp(((karachiRatio * 99) / 100) + 1, 1, 100) * 1e16;
    }

    // Helper function to clamp values
    function clamp(uint256 value, uint256 min, uint256 max) internal pure returns (uint256) {
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }



    function sellShare(uint256 _amount, uint256 _price, uint256 _sellOf) external {
        
        if(_sellOf != 0 && _sellOf != 1){
            revert wrongBetIndex(_sellOf);
        }
        if(_amount <= 0){
            revert wrongAmount(_amount);
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

            require(_amount <= userInfo[msg.sender].noBetAmount, "not enough Amount");
        }else{
            
            require(_amount <= userInfo[msg.sender].yesBetAmount, "not enough Amount");
        }
        
        userInfo[msg.sender].listNo++;

        sellInfo[msg.sender][userInfo[msg.sender].listNo].list = true;
        sellInfo[msg.sender][userInfo[msg.sender].listNo].price = _price; 
        sellInfo[msg.sender][userInfo[msg.sender].listNo].amount = _amount; 
        sellInfo[msg.sender][userInfo[msg.sender].listNo].owner = msg.sender; 
        sellInfo[msg.sender][userInfo[msg.sender].listNo].listOn = _sellOf;
        
    
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

        sellInfo[_owner][_listNo].sold = true;
        sellInfo[_owner][_listNo].owner = msg.sender;
        
        if(sellInfo[_owner][_listNo].listOn == 0){
            
            userInfo[msg.sender].noBetAmount += sellInfo[_owner][_listNo].amount;
            userInfo[_owner].noBetAmount -= sellInfo[_owner][_listNo].amount;
        }else{

            userInfo[_owner].yesBetAmount -= sellInfo[_owner][_listNo].amount;
            userInfo[msg.sender].yesBetAmount += sellInfo[_owner][_listNo].amount;
        }
        
        userInfo[msg.sender].betOn[sellInfo[_owner][_listNo].listOn] = true;
        eachUser[totalUsers] = msg.sender;
        totalUsers++;

        bool success = usdcToken.transferFrom(
            msg.sender,
            _owner,
            sellInfo[_owner][_listNo].price
        );
        require(success, "Transfer failed");

        emit BuyShare(msg.sender,_owner, sellInfo[_owner][_listNo].amount, sellInfo[_owner][_listNo].price);
    }
 
    
    function resolveMarket(uint256 winningIndex) external   {
        
        if(winningIndex != 0 && winningIndex != 1){
            revert wrongBetIndex(winningIndex);
        }
        
        if(marketInfo[address(this)].resolved){
            revert marketResolved();
        }

        if(marketInfo[address(this)].endTime > block.timestamp){
            revert notResolvedBeforeTime(marketInfo[address(this)].endTime);
        }

        uint256 totalWinnerShare;

        for(uint256 i = 0; i < totalUsers; i++){

             if(userInfo[eachUser[i]].betOn[winningIndex]) {

                if(winningIndex == 0 && userInfo[eachUser[i]].noBetAmount != 0){
                    
                    userInfo[eachUser[i]].shareAmount = calculateShares(
                        userInfo[eachUser[i]].noBetAmount,
                        winningIndex
                    );
                    totalWinnerShare += userInfo[eachUser[i]].shareAmount;

                }else{
                
                    userInfo[eachUser[i]].shareAmount = calculateShares(
                        userInfo[eachUser[i]].yesBetAmount,
                        winningIndex
                    );

                    totalWinnerShare += userInfo[eachUser[i]].shareAmount;
                }
             }   
        }

        uint256 _perShare = marketInfo[address(this)].totalAmount / totalWinnerShare;
        uint256 _ownerAmount;
        
        for (uint256 i = 0; i < totalUsers; i++) {
            
            if(userInfo[eachUser[i]].betOn[winningIndex]) {

                uint256 userTotalAmount = userInfo[eachUser[i]].shareAmount * _perShare;
                uint256 userProfitAmountAmount = userTotalAmount - userInfo[eachUser[i]].shareAmount;

                uint256 tenPercentAmount = calculatePercentage(userProfitAmountAmount,profitPercentage);
                _ownerAmount += tenPercentAmount;

                if(usdcToken.balanceOf(address(this)) < (userTotalAmount - tenPercentAmount)){
                    revert contractLowbalance(usdcToken.balanceOf(address(this)));
                }


                bool success = usdcToken.transfer(
                    eachUser[i],
                    userTotalAmount - tenPercentAmount
                );
                require(success, "Transfer failed");

            }
        }

        if(usdcToken.balanceOf(address(this)) < _ownerAmount){
            revert contractLowbalanceForOwner(usdcToken.balanceOf(address(this)));
        }

        marketInfo[address(this)].resolved = true;
        
        bool success1 = usdcToken.transfer(owner(),_ownerAmount);
        require(success1, "Transfer failed");

        emit ResolveMarket( owner(), _ownerAmount, _perShare, winningIndex);
    }

    
    function calculateShares(uint256 _amount, uint256 _betOn ) public view returns (uint256) {

        uint256 price =  marketInfo[address(this)].initialPrice[_betOn];
        
        require(price != 0, "_price cannot be zero");
        uint256 result = _amount / price;
        
        return result;
    }


    function calculatePercentage(uint256 _totalStakeAmount,uint256 percentageNumber) private pure returns(uint256) {
        
        require(_totalStakeAmount !=0 , "_totalStakeAmount can not be zero");
        require(percentageNumber !=0 , "_totalStakeAmount can not be zero");
        uint256 serviceFee = (_totalStakeAmount * percentageNumber)/(10000);
        
        return serviceFee;
    }

    // Function to calculate potential return
    function calculatePotentialReturn(uint256 _shares) private pure returns (uint256) {
    
        uint256 potentialReturn = _shares * 1e18 ;
        return potentialReturn;
    }
    
    function calculateInvestment(uint256 shares, uint256 _betOn) public view returns (uint256) {
        
        require(shares > 0, "Shares must be greater than zero");
        uint256 amountInCents = (shares * marketInfo[address(this)].initialPrice[_betOn]) / 100;
        
        return amountInCents;
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

// function PriceCalculation(uint256 totalBetsOnNo, uint256 totalBetsOnYes) public view returns(uint256, uint256){
        
//          uint256 originalNoPrice = marketInfo[address(this)].initialPrice[0];
//          uint256 originalYesPrice = marketInfo[address(this)].initialPrice[1];
         
//          uint256 totalBets = totalBetsOnNo + totalBetsOnYes;

//         if(totalBetsOnNo != 0){
            
//             originalNoPrice = ((totalBetsOnNo * 100)/(totalBets));
//             originalNoPrice *= 10000000000000000;
//         }
//         if(totalBetsOnYes != 0){
           
//             originalYesPrice = ((totalBetsOnYes * 100)/(totalBets));
//             originalYesPrice *= 10000000000000000;
//         }

//         return(originalNoPrice, originalYesPrice);
//     } 

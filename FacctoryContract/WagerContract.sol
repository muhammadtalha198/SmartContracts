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

    mapping(uint256 => address) public eachUser;
    mapping(address => UserInfo) public userInfo;
    mapping(address => MarketInfo) public marketInfo;
    mapping(address => mapping(uint256 => SellInfo)) public sellInfo;
    

    event Bet(address indexed user,uint256 indexed _amount,uint256 _betOn);
    event SellShare(address indexed user, uint256 listNo,  uint256 onPrice);
    event BuyShare(address buyer, address seller, uint256 _amountBBuyed, uint256 onPrice);
    event ResolveMarket(address ownerAddress, uint256 ownerAmount, uint256 perShareAmount, uint256 winningIndex);


    constructor(
        address initialOwner,
        address _usdcToken,
        uint256 _endTime ) 

        Ownable(initialOwner) {

            marketInfo[address(this)].endTime = _endTime;
            marketInfo[address(this)].initialPrice[0] = 500000000000000000;
            marketInfo[address(this)].initialPrice[1] = 500000000000000000;
            usdcToken = ERC20(_usdcToken);
    }

    function bet(uint256 _amount, uint256 _betOn) external {
       
        require(_betOn == 0 || _betOn == 1, "you either bet yes or no.");
        require(_amount > 0, "Bet amount must be greater than 0");
        require(!marketInfo[address(this)].resolved, "Market is resolved!");
        require(block.timestamp < marketInfo[address(this)].endTime, "Market is closed.");
        

        if(!userInfo[msg.sender].betOn[_betOn] && !userInfo[msg.sender].betOn[_betOn]){     
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


    function PriceCalculation(uint256 totalBetsOnNo, uint256 totalBetsOnYes) public view returns(uint256, uint256){
        
         uint256 originalNoPrice = marketInfo[address(this)].initialPrice[0];
         uint256 originalYesPrice = marketInfo[address(this)].initialPrice[1];
         
         uint256 totalBets = totalBetsOnNo + totalBetsOnYes;

        if(totalBetsOnNo != 0){
            
            originalNoPrice = ((totalBetsOnNo * 100)/(totalBets));
            originalNoPrice *= 10000000000000000;
        }
        if(totalBetsOnYes != 0){
           
            originalYesPrice = ((totalBetsOnYes * 100)/(totalBets));
            originalYesPrice *= 10000000000000000;
        }

        return(originalNoPrice, originalYesPrice);
    } 



    function sellShare(uint256 _amount, uint256 _price, uint256 _sellOf) external {
        
        require(userInfo[msg.sender].betOn[_sellOf], "wrong user.");
        require(_price > 0, "price must be greater than 0");
        require(_amount > 0, "amount must be greater than 0");
        require(_sellOf == 0 || _sellOf == 1, "you either list yes or no.");
        require(!marketInfo[address(this)].resolved, "Market is resolved!");
        require(block.timestamp < marketInfo[address(this)].endTime, "Market has ended");
        
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
        
        require(sellInfo[_owner][_listNo].list, "Not listeed!");
        require(!sellInfo[_owner][_listNo].sold, "allready Sold.");
        require(sellInfo[_owner][_listNo].owner == _owner, "wrong Owner.");
        require(!marketInfo[address(this)].resolved, "Market is resolved!");
        require(block.timestamp < marketInfo[address(this)].endTime, "Market has ended");

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
        
        require(winningIndex == 0 || winningIndex == 1, " either bet yes or no.");
        require(!marketInfo[address(this)].resolved, "Market is resolved!");
        require(block.timestamp >  marketInfo[address(this)].endTime, 
            "Markeeet must be resolved after required Time.");

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
                
                if(winningIndex == 0){

                    _ownerAmount += ((userInfo[eachUser[i]].shareAmount * _perShare) - userInfo[eachUser[i]].noBetAmount) ;
                }
                else{

                    _ownerAmount += ((userInfo[eachUser[i]].shareAmount * _perShare) - userInfo[eachUser[i]].yesBetAmount);
                }

                bool success = usdcToken.transfer(
                    eachUser[i],
                    userInfo[eachUser[i]].shareAmount * _perShare
                );
                require(success, "Transfer failed");

            }
        }

        marketInfo[address(this)].resolved = true;
        
        bool success1 = usdcToken.transfer(owner(),_ownerAmount);
        require(success1, "Transfer failed");

        emit ResolveMarket( owner(), _ownerAmount, _perShare, winningIndex);
    }

    
    function calculateShares(uint256 _amount, uint256 _betOn ) public view returns (uint256) {

        uint256 price =  marketInfo[address(this)].initialPrice[_betOn];
        
        require(price != 0, "_price cannot be zero");
        uint256 result = (_amount * 100) / price;
        
        return result;
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

    function readMarketInfo(address _market) public view returns (
        uint256 endTime,
        uint256 totalBets,
        uint256 totalAmount,
        uint256 initialPriceYes,
        uint256 initialPriceNo,
        uint256 totalBetsOnYes,
        uint256 totalBetsOnNo
    ) {
        return (
            marketInfo[_market].endTime,
            marketInfo[_market].totalBets,
            marketInfo[_market].totalAmount,
            marketInfo[_market].initialPrice[1], // Yes Price
            marketInfo[_market].initialPrice[0], // No Price
            marketInfo[_market].totalBetsOnYes,
            marketInfo[_market].totalBetsOnNo
        );
    }

    function readUserInfo(address _user) public view returns (
        uint256 listNo,
        uint256 noBetAmount,
        uint256 rewardAmount,
        uint256 yesBetAmount,
        uint256 shareAmount
    ) {
        return (
            userInfo[_user].listNo,
            userInfo[_user].noBetAmount,
            userInfo[_user].rewardAmount,
            userInfo[_user].yesBetAmount,
            userInfo[_user].shareAmount
        );
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
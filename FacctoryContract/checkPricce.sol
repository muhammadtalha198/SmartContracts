// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract MyToken  {

    struct MarketInfo {

        bool resolved;
        uint256 endTime;
        uint256 totalBets;
        uint256 totalAmount;
        uint256[2] initialPrice;
        uint256 totalBetsOnYes;
        uint256 totalBetsOnNo;
    }

    uint256 public totalBetAmount;

     mapping(address => MarketInfo)  marketInfo;

    constructor(){

        marketInfo[address(this)].initialPrice[0] = 500000000000000000;
        marketInfo[address(this)].initialPrice[1] = 500000000000000000;
    }
    
    function PriceCalculation(uint256 totalBetAmountOnNo, uint256 totalBetAmountOnYes) private view returns(uint256, uint256){
        
         uint256 originalNoPrice = marketInfo[address(this)].initialPrice[0];
         uint256 originalYesPrice = marketInfo[address(this)].initialPrice[1];
         
         

        if(totalBetAmountOnNo != 0){
            
            originalNoPrice = ((totalBetAmountOnNo * 100)/(totalBetAmount));
            originalNoPrice *= 10000000000000000;
        }
        if(totalBetAmountOnYes != 0){
           
            originalYesPrice = ((totalBetAmountOnYes * 100)/(totalBetAmount));
            originalYesPrice *= 10000000000000000;
        }

        return(originalNoPrice, originalYesPrice);
    } 

    function PriceCalculation1(uint256 totalBetAmountOnNo, uint256 totalBetAmountOnYes) public  returns(uint256, uint256){
        
         totalBetAmount += totalBetAmountOnNo + totalBetAmountOnYes;
         
         (marketInfo[address(this)].initialPrice[0],marketInfo[address(this)].initialPrice[1]) = 
            PriceCalculation(totalBetAmountOnNo, totalBetAmountOnYes);

            return(marketInfo[address(this)].initialPrice[0], marketInfo[address(this)].initialPrice[1]);
    } 

    function getInitialPrices() public view returns (uint256, uint256) {
        return (marketInfo[address(this)].initialPrice[0], marketInfo[address(this)].initialPrice[1]);
    }

    function calculateShares(uint256 _amount, uint256 _betOn ) public view returns (uint256) {

        uint256 price =  marketInfo[address(this)].initialPrice[_betOn];
        
        require(price != 0, "_price cannot be zero");
        uint256 result = (_amount * 100) / price;
        
        return result;
    }
    
}


// 

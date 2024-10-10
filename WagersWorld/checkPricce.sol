// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

        marketInfo[address(this)].initialPrice[0] = 0.5 ether;
        marketInfo[address(this)].initialPrice[1] = 0.5 ether;
    }


    function PriceCalculation1(uint256 totalBetAmountOnNo, uint256 totalBetAmountOnYes) public returns(uint256, uint256){
        
         totalBetAmount += totalBetAmountOnNo + totalBetAmountOnYes;
         
         (marketInfo[address(this)].initialPrice[0],marketInfo[address(this)].initialPrice[1]) = 
            PriceCalculation(totalBetAmountOnNo, totalBetAmountOnYes);

            return(marketInfo[address(this)].initialPrice[0], marketInfo[address(this)].initialPrice[1]);
    } 

    function PriceCalculation(uint256 _totalBetAmountOnNo, uint256 _totalBetAmountOnYes) private pure returns (uint256 noSharePrice, uint256 yesSharePrice) {
        uint256 _totalBet = _totalBetAmountOnNo + _totalBetAmountOnYes;
        if (_totalBet == 0) {
            return (0.5 ether, 0.5 ether); // Starting price is 50 cents for both teams
        }

        uint256 noRatio = (_totalBetAmountOnNo * 100) / _totalBet;
        uint256 yesRatio = (_totalBetAmountOnYes * 100) / _totalBet;

        noSharePrice = clamp(((noRatio * 99) / 100) + 1, 1, 100) * 1e16;
        yesSharePrice = clamp(((yesRatio * 99) / 100) + 1, 1, 100) * 1e16;
    }

    // Helper function to clamp values
    function clamp(uint256 value, uint256 min, uint256 max) internal pure returns (uint256) {
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }

    function getInitialPrices() public view returns (uint256, uint256) {
        return (marketInfo[address(this)].initialPrice[0], marketInfo[address(this)].initialPrice[1]);
    }

    function perPeerson( uint256 totalWinnerShare, uint256 userShareAmount ) view external returns (uint256 _perShare, uint256 userTotalAmount ){
          _perShare = totalBetAmount / totalWinnerShare;
           userTotalAmount = userShareAmount * _perShare;
    }


    function calculateShares(uint256 _amount, uint256 _betOn ) public view returns (uint256) {

        uint256 price =  marketInfo[address(this)].initialPrice[_betOn];
        
        require(price != 0, "_price cannot be zero");
        uint256 result = _amount / price;
        
        return result;
    }
}


 // function PriceCalculation(uint256 totalBetAmountOnNo, uint256 totalBetAmountOnYes) private view returns(uint256 , uint256){
        
    //      uint256 originalNoPrice = marketInfo[address(this)].initialPrice[0];
    //      uint256 originalYesPrice = marketInfo[address(this)].initialPrice[1];
         
         

    //     if(totalBetAmountOnNo != 0){
            
    //         originalNoPrice = ((totalBetAmountOnNo * 100)/(totalBetAmount));
    //         originalNoPrice *= 10000000000000000;
    //     }
    //     if(totalBetAmountOnYes != 0){
           
    //         originalYesPrice = ((totalBetAmountOnYes * 100)/(totalBetAmount));
    //         originalYesPrice *= 10000000000000000;
    //     }

    //     return(originalNoPrice, originalYesPrice);
    // } 


// 

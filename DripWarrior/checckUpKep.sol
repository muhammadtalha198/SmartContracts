// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @dev Example contract which uses the Forwarder
 *
 * @notice important to implement {AutomationCompatibleInterface}
 */

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CounterwForwarder is AutomationCompatibleInterface,Ownable {
    
    uint256 public counter; // counter counts the number of upkeeps performed
    uint256 public interval; // interval specifies the time between upkeeps
   
    uint256 public realInterval; // interval specifies the time between upkeeps
    uint256 public startingTime;
    uint256 public lastTimeStamp; // lastTimeStamp tracks the last upkeep performed
    
    address public s_forwarderAddress;
    
    bool public checkOnce;
    
    
    error wrongTime(uint256 time);
     error wrongInterval(uint256 updateInterval);

    constructor()Ownable(msg.sender) {
        
    }

    function checkUpkeep(bytes calldata /*checkData*/) external override view  returns (bool, bytes memory) {

        bool needsUpkeep = (block.timestamp - lastTimeStamp) > interval;
        return (needsUpkeep, bytes(""));
    }

      function performUpkeep(bytes calldata /*performData*/) external  {

        require(
            msg.sender == s_forwarderAddress,
            "This address does not have permission to call performUpkeep"
        );
       
        if (interval == 0){
            revert wrongInterval(interval);
        }
        
         if(block.timestamp >= startingTime){

            /*
              startExecutionTime =  1728482424 14:00
              lastTimeStamp = 1728482484.      14:01
              executionDuration = 1728482604 - 1728482424 =   14:03 - 14:00 = 
              interval = 60 - 3 = 57

              current = 1728486024  15:00 
            */
            
            uint256 startExecutionTime = lastTimeStamp = block.timestamp;  
            weeklyTransfer();
            uint256 executionDuration = block.timestamp - startExecutionTime; 
            interval = realInterval - executionDuration; // Reduce the interval by the duration taken

        }
        else{
            revert wrongTime(startingTime);
        }
        
    }





    // function performUpkeep(bytes calldata /*performData*/) external override {
         
    //     require(
    //         msg.sender == s_forwarderAddress,
    //         "This address does not have permission to call performUpkeep"
    //     );
       
    //     if (interval == 0){
    //         revert wrongInterval(interval);
    //     }
        
    //     if(!checkOnce){

    //         if(block.timestamp >= startingTime){

    //             lastTimeStamp = block.timestamp;
    //             weeklyTransfer();
    //             interval = realInterval;
    //         }
    //         else{
    //             revert wrongTime(startingTime);
    //         }
    //     }
    //     else{
           
    //         lastTimeStamp = block.timestamp;
    //         weeklyTransfer();
    //     }
       
    //     if(!checkOnce){
    //         checkOnce = true;
    //     }
        
    // }


    function setInterval (uint256 _startingTime, uint256 updateInterval) external  onlyOwner{
         
        if(updateInterval <= 0){
            revert wrongInterval(updateInterval);
        }
        
        if(_startingTime < block.timestamp){
            revert wrongTime(_startingTime);
        }

        interval = _startingTime - block.timestamp;
        startingTime = _startingTime;
        lastTimeStamp = block.timestamp;
        realInterval = updateInterval;

        // emit SetInterval(msg.sender, interval, lastTimeStamp);

    }

    function off () external  onlyOwner{
       
        interval = 0;
        checkOnce = false;
        
    }

    uint256 receiveFromTreasury ;
    uint256 receiveFromOwneerShip ;            
    bool blocked = false;
    uint256 receivedAmount ;
    uint256  totalStakedAmount = 20 ether;

    function weeklyTransfer() public  {

        
        ( uint256 remainFiftyOPool,uint256 dividentPayoutOPoolAmount, uint256 perPersonFromTPool)  = perPoolCalculation();
        
       
        uint256 maxlimit;

        for(uint256 i = 0; i < noOfUsers; i++){

            if(!blocked){

                uint256 eachSharePercentage = (totalStakedAmount * (10000)) / (totalStakedAmount);
                
                uint256 eachSendAmount = calculatePercentage(dividentPayoutOPoolAmount, eachSharePercentage);
                uint256 eachSendAmount1 = calculatePercentage(remainFiftyOPool, eachSharePercentage);
                
                ownerShipPoolAmount -= eachSendAmount;
                        
                maxlimit += eachSendAmount;
                treasuryPoolAmount -= perPersonFromTPool;

                receiveFromTreasury += perPersonFromTPool;
               receiveFromOwneerShip += eachSendAmount;
                
                uint256 totalSendAmount = eachSendAmount + perPersonFromTPool;
               receivedAmount += totalSendAmount;

            }
            
        }

       

    }

   uint256 noOfUsers = 100;

    uint256  ownerShipPoolAmount = 999999999999999999999999 ether ;
     uint256   treasuryPoolAmount = 999999999999999999999999 ether;

     uint256  odividentPayoutPercentage = 200;
       uint256 flowToTreasuryPercentage = 200;
       uint256 maintainceFeePercentage = 200;
        uint256 tdividentPayoutPercentage = 200;

    function perPoolCalculation() private returns(uint256, uint256,uint256){
        

        uint256 remainFiftyOPool = calculatePercentage(ownerShipPoolAmount, 5000);

        uint256 dividentPayoutOPoolAmount = calculatePercentage(remainFiftyOPool, odividentPayoutPercentage);
        uint256 fifteenPercenntToTPoolAmount = calculatePercentage(remainFiftyOPool, flowToTreasuryPercentage);
        uint256 tenPercenntToMaintenceAmount = calculatePercentage(remainFiftyOPool, maintainceFeePercentage);
        uint256 remainFiftyTPoolAmount = calculatePercentage(treasuryPoolAmount, tdividentPayoutPercentage);
        
        uint256 perPersonFromTPool = remainFiftyTPoolAmount/noOfUsers;
        
        ownerShipPoolAmount -= (fifteenPercenntToTPoolAmount + tenPercenntToMaintenceAmount);
        treasuryPoolAmount += fifteenPercenntToTPoolAmount;

        

        return (remainFiftyOPool,dividentPayoutOPoolAmount,perPersonFromTPool);
    }

    function calculatePercentage(uint256 _totalStakeAmount,uint256 percentageNumber) private pure returns(uint256) {
       
        uint256 serviceFee = _totalStakeAmount * (percentageNumber) / (10000);
        
        return serviceFee;
    }

    function setForwarderAddress(address forwarderAddress) external onlyOwner {
        s_forwarderAddress = forwarderAddress;
    }

}




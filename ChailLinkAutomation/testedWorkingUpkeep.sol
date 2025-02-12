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


    function performUpkeep(bytes calldata /*performData*/) external override {
         
        require(
            msg.sender == s_forwarderAddress,
            "This address does not have permission to call performUpkeep"
        );
       
        if (interval == 0){
            revert wrongInterval(interval);
        }
        
        if(!checkOnce){

            if(block.timestamp >= startingTime){

               lastTimeStamp = block.timestamp;
                weeklyTransfer();
                interval = realInterval;
            }
            else{
                revert wrongTime(startingTime);
            }
        }
        else{
           
            lastTimeStamp = block.timestamp;
            weeklyTransfer();
        }
       
        if(!checkOnce){
            checkOnce = true;
        }
        
    }


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

    function weeklyTransfer() public {
        require(
            msg.sender == s_forwarderAddress,
            "This address does not have permission to call performUpkeep"
        );
        counter ++;
    }

    /// @notice Set the address that `performUpkeep` is called from
    /// @dev Only callable by the owner
    /// @param forwarderAddress the address to set
    function setForwarderAddress(address forwarderAddress) external onlyOwner {
        s_forwarderAddress = forwarderAddress;
    }

    function doWee() public {
        if(!checkOnce){
                checkOnce = true;
        }
    }
}

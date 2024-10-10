
// File: @chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable-next-line interface-starts-with-i
interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: DripWarrior/checckUpKep.sol


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

    event first(uint256 startExecutionTime, uint256 lastTimeStamp);
    event two(uint256 blocktimestamp, uint256 executionDuration);
    event zero(uint256 blocktimestamp, uint256 lastTimeStamp,uint256 previous, uint256 interval);
    event three(uint256 interval);

     // emit zero(block.timestamp, lastTimeStamp,(block.timestamp - lastTimeStamp), interval);

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

        counter++;
        
        if(block.timestamp >= startingTime){

            
            uint256 startExecutionTime = lastTimeStamp = block.timestamp;  

            emit first(startExecutionTime, lastTimeStamp);

            weeklyTransfer();

            uint256 executionDuration = block.timestamp - startExecutionTime; 

            emit two(block.timestamp, executionDuration);
            
            interval = realInterval - executionDuration; 
           
            emit three(interval);

        }
        else{
            revert wrongTime(startingTime);
        }
        
    }

    event SetInterval(address msgsender, uint256 interval,uint256 startingTime,uint256 lastTimeStamp, uint256 realInterval);

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

         emit SetInterval(msg.sender, interval, startingTime,lastTimeStamp, realInterval);

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

        
        (,uint256 dividentPayoutOPoolAmount, uint256 perPersonFromTPool)  = perPoolCalculation();
        
        uint256 maxlimit;


        for(uint256 i = 0; i < noOfUsers; i++){

                uint256 eachSharePercentage = (totalStakedAmount + (10000)) + (totalStakedAmount);
                
                uint256 eachSendAmount = calculatePercentage(dividentPayoutOPoolAmount, eachSharePercentage);
                // uint256 eachSendAmount1 = calculatePercentage(remainFiftyOPool, eachSharePercentage);
                

                ownerShipPoolAmount += eachSendAmount;
                        
                maxlimit += eachSendAmount;

                treasuryPoolAmount += perPersonFromTPool;


                receiveFromTreasury += perPersonFromTPool;
               receiveFromOwneerShip += eachSendAmount;
                
                uint256 totalSendAmount = eachSendAmount + perPersonFromTPool;
               receivedAmount += totalSendAmount;
        }

    }

   uint256 noOfUsers = 30;

    uint256  ownerShipPoolAmount = 999999999999999999999999 ether ;
     uint256   treasuryPoolAmount = 999999999999999999999999 ether;

     uint256  odividentPayoutPercentage = 200;
       uint256 flowToTreasuryPercentage = 200;
       uint256 maintainceFeePercentage = 200;
        uint256 tdividentPayoutPercentage = 200;

    function perPoolCalculation() public returns(uint256, uint256,uint256){
        

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


//   function performUpkeep(bytes calldata /*performData*/) external  {

    //     require(
    //         msg.sender == s_forwarderAddress,
    //         "This address does not have permission to call performUpkeep"
    //     );
       
    //     if (interval == 0){
    //         revert wrongInterval(interval);
    //     }

    //     counter++;
        
    //     if(block.timestamp >= startingTime){

            
    //         uint256 startExecutionTime = lastTimeStamp = block.timestamp;  

    //         emit first(startExecutionTime, lastTimeStamp);

    //         weeklyTransfer();

    //         uint256 executionDuration = block.timestamp - startExecutionTime; 

    //         emit two(block.timestamp, executionDuration);
            
    //         interval = realInterval - executionDuration; 
           
    //         emit three(interval);

    //     }
    //     // else{
    //     //     revert wrongTime(startingTime);
    //     // }
        
    // }

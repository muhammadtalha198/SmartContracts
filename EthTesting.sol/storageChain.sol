
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


contract StakingContract  {
   
    struct UserInfo {
        string[] nodeIds;
        uint256 totalStakedAmount;
    }

    struct StakeInfo {
        bool isNodeAlive;
        uint256 stakedAmount;
    }

    bool private locked;
    address public immutable owner;
    uint256 private totalStakedTokens;
    
    mapping(address => UserInfo) private userInfo;
    mapping(address => mapping(string => StakeInfo)) private stakeInfo;

   
    event Transferred(address indexed sender, uint256 value);
    event StakeEvent(string nodeId, address indexed userAddress,uint256 stakedAmount,
                        uint256 totalStakedAmount,bool tokenStaked);

    error OnlyOwnerError();
    error ReentrancyError();
    error invalidFee(uint256 fee);
    error nodeNotExist(bool nodExist);
    error invalidAmount(uint256 amount);
    error withdrawFailed(bool transfered);
    error wrongIdsLength(uint256 idsLength);
    error wrongAddressLength(uint256 addressLength);
    error wrongAmountsLength(uint256 amountsLength);
    error insuficentTrasuryBalance(uint256 treasuryBallance);
    error lengthDontMatch(uint256 addressLength,uint256 idsLength,uint256 amountsLength );

    constructor(address _owner) {
        owner = _owner;
    }
    
    /**
     * @dev Feeds old contract data into the new contract.
     * @param _userAddresses Array of user addresses.
     * @param _nodeIds Array of node IDs corresponding to users.
     * @param _stakedAmounts Array of staked amounts corresponding to each node.
    */

    function feedNodeRecord(
        address[] calldata _userAddresses, 
        string[] calldata _nodeIds, 
        uint256[] calldata _stakedAmounts
    ) external onlyOwner {

        if(_userAddresses.length <= 0){
            revert wrongAddressLength(_userAddresses.length);
        }
        if(_nodeIds.length <= 0){
            revert wrongIdsLength(_nodeIds.length);
        }
        if(_stakedAmounts.length <= 0){
            revert wrongAmountsLength(_stakedAmounts.length);
        }

        if(_userAddresses.length != _nodeIds.length && _nodeIds.length != _stakedAmounts.length){
            revert lengthDontMatch(_userAddresses.length,_nodeIds.length,_stakedAmounts.length);
        }
       
        for (uint i = 0; i < _userAddresses.length; i++) {
            
            totalStakedTokens += _stakedAmounts[i];
            
            userInfo[_userAddresses[i]].nodeIds.push(_nodeIds[i]);
            userInfo[_userAddresses[i]].totalStakedAmount += _stakedAmounts[i];
            stakeInfo[_userAddresses[i]][_nodeIds[i]].stakedAmount = _stakedAmounts[i];
            stakeInfo[_userAddresses[i]][_nodeIds[i]].isNodeAlive = true;

        }

        emit StakeEvent("Node stake info updated", address(0), 0, 0, true);
    }
    
    /**
     * @dev Adds a new node and stakes tokens to it.
     * @param _nodeId The ID of the node to be added.
     */
    
    function addNode(string calldata _nodeId) external payable {
        
        if(msg.value <= 50 wei){
            revert invalidFee(msg.value);
        }
        
        totalStakedTokens += msg.value;

        userInfo[msg.sender].nodeIds.push(_nodeId);
        userInfo[msg.sender].totalStakedAmount += msg.value;
        
        stakeInfo[msg.sender][_nodeId].isNodeAlive = true;
        stakeInfo[msg.sender][_nodeId].stakedAmount = msg.value;

        emit StakeEvent(
            _nodeId, 
            msg.sender, 
            msg.value, 
            userInfo[msg.sender].totalStakedAmount,
            true
        );
    }
    
    /**
     * @dev Deletes an existing node and unstakes the associated tokens.
     * @param _nodeId The ID of the node to be deleted.
    */
    
    function deleteNode(string calldata _nodeId) external nonReentrant {
        

        if(!stakeInfo[msg.sender][_nodeId].isNodeAlive){
            revert nodeNotExist(stakeInfo[msg.sender][_nodeId].isNodeAlive);
        }

        if(address(this).balance < stakeInfo[msg.sender][_nodeId].stakedAmount){
            revert insuficentTrasuryBalance(address(this).balance);
        }
        
        
        userInfo[msg.sender].totalStakedAmount -= stakeInfo[msg.sender][_nodeId].stakedAmount;
        totalStakedTokens -= stakeInfo[msg.sender][_nodeId].stakedAmount;

        stakeInfo[msg.sender][_nodeId].isNodeAlive = false;
        stakeInfo[msg.sender][_nodeId].stakedAmount = 0;
       
      
        (bool success, ) = payable(msg.sender).call{value: stakeInfo[msg.sender][_nodeId].stakedAmount}("");
        
        if(!success){
            revert withdrawFailed(success);
        }
       
        emit StakeEvent(
            _nodeId, msg.sender,
            stakeInfo[msg.sender][_nodeId].stakedAmount,
            userInfo[msg.sender].totalStakedAmount,
            stakeInfo[msg.sender][_nodeId].isNodeAlive
        );
    }


    /**
     * @dev Fills the contract treasury with funds.
    */

    function fillTreasury() external payable onlyOwner {

        if(msg.value <= 0) revert invalidAmount(msg.value);
        emit Transferred(msg.sender, msg.value);
    }

    /**
     * @dev Checks the contract's current treasury balance.
    */

    function checkTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Gets the total staked tokens across all users.
     * Only the owner can view this value.
     * @return The total staked tokens in the contract.
     */
    function totalStakedStorCoins() external view onlyOwner returns (uint256) {
        return totalStakedTokens;
    }
    /**
     * @dev Checks if a specific node exists for a given user.
     * @param _userAddress The address of the user.
     * @param _nodeId The ID of the node to check.
     * @return A boolean indicating if the node exists and is alive.
     */
    function nodeExists(address _userAddress, string memory _nodeId) external view onlyOwner returns (bool) {
        return stakeInfo[_userAddress][_nodeId].isNodeAlive;
    }
    /**
     * @dev Gets the total staked amount for a specific user.
     * @param _userAddress The address of the user.
     * @return The total staked amount by the user.
     */
    function totalStakedOfUser(address _userAddress) external view returns (uint256) {
        return userInfo[_userAddress].totalStakedAmount;
    }
    /**
     * @dev Retrieves all node IDs associated with a specific user.
     * @param _userAddress The address of the user.
     * @return An array of node IDs owned by the user.
     */
    function getNodeIds(address _userAddress) external view returns (string[] memory) {
        return userInfo[_userAddress].nodeIds;
    }
    /**
     * @dev Gets the staked amount for a specific node owned by a user.
     * @param _userAddress The address of the user.
     * @param _nodeId The ID of the node.
     * @return The staked amount for the given node.
     */
    function getStakeAmountOfNode(address _userAddress, string memory _nodeId) external view returns (uint256) {
        return stakeInfo[_userAddress][_nodeId].stakedAmount;
    }

    /**
     * @dev Receive function to accept Ether directly into the contract.
    */
    
    receive() external payable {
        emit Transferred(msg.sender, msg.value);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwnerError();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrancyError();
        locked = true;
        _;
        locked = false;
    }
}
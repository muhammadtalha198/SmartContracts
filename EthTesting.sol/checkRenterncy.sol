
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


contract StakingContract  {
   
   
    struct UserInfo {
        string[] nodeIds;
        uint256 totalStakedAmount;
    }
    
    // Optimized struct with bool last to save storage
    struct StakeInfo {
        uint256 stakedAmount;
        bool isNodeAlive;
    }
    bool private locked;
    address public immutable owner;
    uint256 private totalStakedTokens;
    
    mapping(address => mapping(string => StakeInfo)) private stakeInfo;
    mapping(address => UserInfo) private userInfo;
   
   
   
    event StakeEvent(string nodeId, address indexed userAddress,uint256 stakedAmount,uint256 totalStakedAmount,bool tokenStaked);
    event Transferred(address indexed sender, uint256 value);
    
    constructor() {
        owner = msg.sender;
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
       
        for (uint i = 0; i < _userAddresses.length; i++) {
            address userAddress = _userAddresses[i];
            string memory nodeId = _nodeIds[i];
            uint256 stakedAmount = _stakedAmounts[i];
            totalStakedTokens += stakedAmount;
            userInfo[userAddress].totalStakedAmount += stakedAmount;
            userInfo[userAddress].nodeIds.push(nodeId);
            stakeInfo[userAddress][nodeId] = StakeInfo(stakedAmount, true);
        }
        emit StakeEvent("Node stake info updated", address(0), 0, 0, true);
    }
    
    
    /**
     * @dev Adds a new node and stakes tokens to it.
     * @param _nodeId The ID of the node to be added.
     */
    function addNode(string calldata _nodeId) external payable nonReentrant {
        require(msg.value > 50 wei, "Stake amount must be greater than 50 wei");
        // State update first (CEI pattern)
        totalStakedTokens += msg.value;
        userInfo[msg.sender].totalStakedAmount += msg.value;
        userInfo[msg.sender].nodeIds.push(_nodeId);
        stakeInfo[msg.sender][_nodeId] = StakeInfo(msg.value, true);
        emit StakeEvent(_nodeId, msg.sender, msg.value, userInfo[msg.sender].totalStakedAmount, true);
    }
    
    
    /**
     * @dev Deletes an existing node and unstakes the associated tokens.
     * @param _nodeId The ID of the node to be deleted.
     */
    function deleteNode(string calldata _nodeId) external nonReentrant {
        
        StakeInfo storage stake = stakeInfo[msg.sender][_nodeId];
        
        require(stake.isNodeAlive, "Node does not exist");
        uint256 stakedAmount = stake.stakedAmount;
        
        require(address(this).balance >= stakedAmount, "Insufficient treasury balance");
        
        // State update first (CEI pattern)
        userInfo[msg.sender].totalStakedAmount -= stakedAmount;
        totalStakedTokens -= stakedAmount;
        stake.isNodeAlive = false;
        stake.stakedAmount = 0;
       
        // External interaction after state update
        (bool success, ) = payable(msg.sender).call{value: stakedAmount}("");
        require(success, "Withdrawal failed");
       
        emit StakeEvent(_nodeId, msg.sender, stakedAmount, userInfo[msg.sender].totalStakedAmount, false);
    }


    /**
     * @dev Fills the contract treasury with funds.
     */
    function fillTreasury() external payable onlyOwner {
        require(msg.value > 0, "Invalid Amount");
        emit Transferred(msg.sender, msg.value);
    }


    /**
     * @dev Checks the contract's current treasury balance.
     */
    function checkTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can access");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    /**
     * @dev Receive function to accept Ether directly into the contract.
     */
    receive() external payable {
        emit Transferred(msg.sender, msg.value);
    }
}
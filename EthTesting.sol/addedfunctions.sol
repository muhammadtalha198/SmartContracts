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
     * This triggers the `Transferred` event.
     */
    receive() external payable {
        emit Transferred(msg.sender, msg.value);
    }
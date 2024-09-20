
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


contract StakingContract  {
   

    struct UserInfo {
        string[] nodeIds;
        uint256 totalStakedAmount;
    }

    struct StakeInfo {
        uint256 stakedAmount;
        bool isNodeAlive;
    }

    bool private locked;
    address public immutable owner;
    uint256 private totalStakedTokens;
    
    mapping(address => UserInfo) private userInfo;
    mapping(address => mapping(string => StakeInfo)) private stakeInfo;

   
    event Transferred(address indexed sender, uint256 value);
    event StakeEvent(string nodeId, address indexed userAddress,uint256 stakedAmount,uint256 totalStakedAmount,bool tokenStaked);
    
    error invalidFee(uint256 fee);
    error nodeNotExist(bool nodExist);
    error invalidAmount(uint256 amount);
    error wrongIdsLength( uint256 idsLength);
    error wrongAmountsLength( uint256 amountsLength);
    error wrongAddressLength( uint256 addressLength);
    error insuficentTrasuryBalance(uint256 treasuryBallance);
    error lengthDontMatch( uint256 addressLength,uint256 idsLength,uint256 amountsLength );

    constructor(address _owner) {
        owner = _owner;
    }
    

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
           
            address userAddress = _userAddresses[i];
            string memory nodeId = _nodeIds[i];
            uint256 stakedAmount = _stakedAmounts[i];
            
            totalStakedTokens += stakedAmount;
            
            userInfo[userAddress].nodeIds.push(nodeId);
            userInfo[userAddress].totalStakedAmount += stakedAmount;
            stakeInfo[userAddress][nodeId] = StakeInfo(stakedAmount, true);

        }

        emit StakeEvent("Node stake info updated", address(0), 0, 0, true);
    }
    
    
    
    function addNode(string calldata _nodeId) external payable {
        
        if(msg.value <= 50 wei){
            revert invalidFee(msg.value);
        }
        
        totalStakedTokens += msg.value;

        userInfo[msg.sender].nodeIds.push(_nodeId);
        userInfo[msg.sender].totalStakedAmount += msg.value;
        stakeInfo[msg.sender][_nodeId] = StakeInfo(msg.value, true);

        emit StakeEvent(
            _nodeId, 
            msg.sender, 
            msg.value, 
            userInfo[msg.sender].totalStakedAmount,
            true
        );
    }
    
    
    
    function deleteNode(string calldata _nodeId) external nonReentrant {
        
        StakeInfo storage stake = stakeInfo[msg.sender][_nodeId];

        if(!stake.isNodeAlive){
            revert nodeNotExist(stake.isNodeAlive);
        }

        if(address(this).balance < stake.stakedAmount){
            revert insuficentTrasuryBalance(address(this).balance);
        }
        
        uint256 stakedAmount = stake.stakedAmount;
        
        
        userInfo[msg.sender].totalStakedAmount -= stakedAmount;
        totalStakedTokens -= stakedAmount;
        stake.isNodeAlive = false;
        stake.stakedAmount = 0;
       
      
        (bool success, ) = payable(msg.sender).call{value: stakedAmount}("");
        require(success, "Withdrawal failed");
       
        emit StakeEvent(
            _nodeId, msg.sender,
            stake.stakedAmount,
            userInfo[msg.sender].totalStakedAmount,
            stake.isNodeAlive
        );
    }


    
    function fillTreasury() external payable onlyOwner {

        if(msg.value <= 0){
            revert invalidAmount(msg.value);
        }

        emit Transferred(msg.sender, msg.value);
    }


    
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

    
    receive() external payable {
        emit Transferred(msg.sender, msg.value);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleDistributor is Pausable, Ownable, ReentrancyGuard {
    bytes32 public merkleRoot;

    address public token;
    address public treasury;

    bool public isClaiming;
    uint256 public startClaimingRound;
    uint256 public claimingRoundDuration;

    mapping(address => bool) public claimed;

    event Claimed(address indexed account, uint256 amount);

    modifier onlyClaimingRound() {
        require(
            isClaiming && (block.timestamp >= startClaimingRound &&
                block.timestamp <= startClaimingRound + claimingRoundDuration),
            "It is no period to claim!"
        );
        _;
    }

    constructor(address _owner, address _treasury) Ownable(msg.sender) {
        treasury = _treasury;
        claimingRoundDuration = 86400 * 7; // 7 days
        isClaiming = false;
        transferOwnership(_owner);
        pause();
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setToken(address _token) external onlyOwner {
        require(_token != address(0), "Token shouldn't be zero");
        token = _token;
    }

    function setStartClaimingRound() external onlyOwner {
        isClaiming = true;
        startClaimingRound = block.timestamp;
    }

    function endClaimingRound() external onlyOwner {
        isClaiming = false;
        startClaimingRound = 0;
    }

    function setClaimingRoundDuration(uint256 _duration) external onlyOwner {
        claimingRoundDuration = _duration;
    }

    function verifyUser(
        address _user,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external view returns (bool) {
        bytes32 node = keccak256(abi.encodePacked(_user, _amount));
        return MerkleProof.verify(_merkleProof, merkleRoot, node);
    }

    function claim(
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external whenNotPaused nonReentrant onlyClaimingRound {
        
        require(!claimed[msg.sender], "Already claimed");

        // Verify the merkle proof
        bytes32 node = keccak256(abi.encodePacked(msg.sender, _amount));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, node),
            "Invalid proof"
        );

        require(token != address(0), "Token address shouldn't be zero!");

        // Claim Tokens
        require(
            IERC20(token).balanceOf(address(this)) > _amount,
            "Insufficient Balance!"
        );
        if (_amount > 0) {
            IERC20(token).transfer(msg.sender, _amount);
        }

        // Mark it claimed and transfer the token
        claimed[msg.sender] = true;

        emit Claimed(msg.sender, _amount);
    }

    function unClaimedTokenToTreasury() external onlyOwner {
        IERC20 tokenERC20 = IERC20(token);
        uint256 balance = tokenERC20.balanceOf(address(this));
        tokenERC20.transfer(treasury, balance);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function checkClaimingRound() external view returns (bool) {
        return
            isClaiming && ((startClaimingRound + claimingRoundDuration) >= block.timestamp) &&
            (block.timestamp >= startClaimingRound);
    }
}

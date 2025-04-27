// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract Quantova is ERC20, ERC20Burnable, Ownable {


    address public bridge;
    bool public bridgeInitialized;


    event BridgeUpdated(address indexed newBridge);

    error ZeroAddress();
    error BridgeNotInitialized();

    constructor(address initialOwner)
        ERC20("Quantova", "QTOV")
        Ownable(initialOwner)
    {

    }

    function mint(address to, uint256 amount) public onlyBridge {
        
        if (!bridgeInitialized) revert BridgeNotInitialized();
        _mint(to, amount);
    }

    function setBridge(address _bridge) public onlyOwner {

        if (_bridge == address(0)) revert ZeroAddress();
        bridge = _bridge;
        
        bridgeInitialized = true; // Mark bridge as initialized
        
        emit BridgeUpdated(_bridge);
    }

    modifier onlyBridge() {
        require(msg.sender == bridge, "Only bridge");
        _;
    }
}

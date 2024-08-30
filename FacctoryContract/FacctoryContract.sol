

// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;
import "./WagerContract.sol";

contract FactoryMacketContract {

    address public usdcToken = 0x61242452BBA94aC6A990d35bF5C4c0dAC21bC2C0;
    address private _admin =  0xA33c5875BE1e3aFd5D72C5dF98D3469d95aC85B0;
    Market[] public markets;
    address[] public marketAddresses;

    mapping (address => bool) public marketCreated;

    event MarketCreated(address indexed marketAddress);
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Function to create a new prediction market
    function createMarket( uint256 endTime) external  {
        
        require(block.timestamp < endTime, "End time must be in the future");

        Market newMarket = new Market(msg.sender,usdcToken,endTime);
        address marketAddress = address(newMarket);

        markets.push(newMarket);
        marketAddresses.push(marketAddress);
        marketCreated[marketAddress] = true;


        emit MarketCreated(marketAddress);

    }
    
 
    function getNumberOfMarkets() external view returns (uint256) {
        return markets.length;
    }
    
    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    function admin() public view virtual returns (address) {
        return _admin;
    }

   
    function _checkAdmin() internal view virtual {
        if (admin() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }



     function transferOwnership(address newOwner) public  {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    
    function _transferOwnership(address newOwner) internal  {
        address oldOwner = _admin;
        _admin = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

}


// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor()
        ERC20("TestTokenOne", "T1")
        Ownable(msg.sender)
    {
        mint(0xcCc22A7fc54d184138dfD87B7aD24552cD4E0915, 10000*1e18);
        mint(0xA33c5875BE1e3aFd5D72C5dF98D3469d95aC85B0, 10000*1e18);
        mint(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 10000*1e18);
        mint(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 10000*1e18);
        mint(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, 10000*1e18);
        mint(0x617F2E2fD72FD9D5503197092aC168c91465E7f2, 10000*1e18);
        mint(0x17F6AD8Ef982297579C203069C1DbfFE4348c372, 10000*1e18);
        
    }

    function mint(address to, uint256 amount) public  {
        _mint(to, amount);
    }
}


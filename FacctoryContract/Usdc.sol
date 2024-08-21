// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor(address initialOwner)
        ERC20("MyToken", "MTK")
        Ownable(initialOwner)
    {
        _mint(initialOwner, 100000000*1e18);
        _mint(initialOwner, 100000000*1e18);
        _mint(initialOwner, 100000000*1e18);
        _mint(0x6DdCE86b55741e1fb71999a24C9BD95Db18c934F, 100000000*1e18);

        _mint(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 10000000000000 * 1e18);
        _mint(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 10000 * 1e18);
        _mint(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 10000 * 1e18);
        _mint(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, 10000 * 1e18);
        _mint(0x617F2E2fD72FD9D5503197092aC168c91465E7f2, 10000 * 1e18);
        _mint(0x17F6AD8Ef982297579C203069C1DbfFE4348c372, 10000 * 1e18);
        _mint(0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678, 10000 * 1e18);
        _mint(0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7, 10000 * 1e18);
        _mint(0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C, 10000 * 1e18);
        _mint(0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC, 10000 * 1e18);
        
        _mint(0x6DdCE86b55741e1fb71999a24C9BD95Db18c934F, 10000 * 1e18);
        _mint(0xA33c5875BE1e3aFd5D72C5dF98D3469d95aC85B0, 10000 * 1e18);
        _mint(0xcCc22A7fc54d184138dfD87B7aD24552cD4E0915, 10000 * 1e18);
        _mint(0xCA6e763716eA3a3e425baD2954a65BBb411e5fBC, 10000 * 1e18);
        _mint(0xbEc540D2840BF6c5b52FC98f61e760E6fb1B2659, 10000 * 1e18);
        _mint(0xA33c5875BE1e3aFd5D72C5dF98D3469d95aC85B0, 10000 * 1e18);
    }

    function mint(address to, uint256 amount) public  {
        _mint(to, amount);
    }
}


// 

// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MyContract is Initializable, OwnableUpgradeable, UUPSUpgradeable {


    struct TierConfigStruct {
        uint256 minValue;
        uint256 maxValue;
        uint256 boostPercentage;
    }

   TierConfigStruct[] public tiers;



    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

     function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        _addTier(0, 99 ether, 0);
        _addTier(100 ether, 499 ether, 500 ); // 5%
        _addTier(500 ether, 999 ether, 700); // 7%
        _addTier(1000 ether, 4999 ether, 1000); // 10%
        _addTier(5000 ether, type(uint256).max, 1500); // 15%    
    }

    // Owner functions
    function _updateTier(uint256 tierIndex, uint256 minAmount, uint256 maxAmount, uint256 boostPercentage) external onlyOwner {
        require(tierIndex < tiers.length, "Invalid tier index");
        tiers[tierIndex] = TierConfigStruct(minAmount, maxAmount, boostPercentage);
    }


    function addTier(uint256 minAmount, uint256 maxAmount, uint256 boostPercentage) external onlyOwner {
       _addTier(minAmount, maxAmount, boostPercentage);
    }

    function _addTier(uint256 minAmount, uint256 maxAmount, uint256 boostPercentage) private {
        tiers.push(TierConfigStruct(minAmount, maxAmount, boostPercentage));
    }

    function removeTier(uint256 tierIndex) external onlyOwner {
        require(tierIndex < tiers.length, "Invalid tier index");
        tiers[tierIndex] = tiers[tiers.length - 1];
        tiers.pop();
    }

    function getTierConfigByValue(uint256 value) external view returns (TierConfigStruct memory) {
        for (uint256 i = 0; i < tiers.length; i++) {
            if (value >= tiers[i].minValue && value <= tiers[i].maxValue) {
                return tiers[i];        
            }
        }
        revert("No matching tier found");
    }   


    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}

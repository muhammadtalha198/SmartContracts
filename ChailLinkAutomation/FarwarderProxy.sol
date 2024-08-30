// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import  "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import  "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract CounterwForwarder is Initializable, UUPSUpgradeable, AutomationCompatibleInterface, OwnerIsCreator {
    uint256 public counter; // counter counts the number of upkeeps performed
    uint256 public interval; // interval specifies the time between upkeeps
    uint256 public lastTimeStamp; // lastTimeStamp tracks the last upkeep performed
    address public s_forwarderAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(uint256 updateInterval) external initializer {
        interval = updateInterval;
        __UUPSUpgradeable_init();
        __OwnerIsCreator_init();
    }

    function checkUpkeep(
        bytes calldata /*checkData*/
    ) external view override returns (bool, bytes memory) {
        bool needsUpkeep = (block.timestamp - lastTimeStamp) > interval;
        return (needsUpkeep, bytes(""));
    }

    function performUpkeep(bytes calldata /*performData*/) external override {
        require(
            msg.sender == s_forwarderAddress,
            "This address does not have permission to call performUpkeep"
        );
        lastTimeStamp = block.timestamp;
        counter = counter + 1;
    }

    /// @notice Set the address that `performUpkeep` is called from
    /// @dev Only callable by the owner
    /// @param forwarderAddress the address to set
    function setForwarderAddress(address forwarderAddress) external onlyOwner {
        s_forwarderAddress = forwarderAddress;
    }

    /// @dev Authorization for upgrading the contract
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}

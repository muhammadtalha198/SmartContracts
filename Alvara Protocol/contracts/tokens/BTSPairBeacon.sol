// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract BTSPairBeacon is UpgradeableBeacon {
    constructor(address implementation) UpgradeableBeacon(implementation, _msgSender()) {}
}
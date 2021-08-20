pragma solidity ^0.7.0;

// SPDX-License-Identifier: SimPL-2.0

import "./ContractOwner.sol";
import "./Manager.sol";

abstract contract Member is ContractOwner {
    modifier CheckPermit(string memory permit) {
        require(manager.userPermits(msg.sender, permit), "no permit");
        _;
    }

    Manager public manager;

    function setManager(address addr) external ContractOwnerOnly {
        manager = Manager(addr);
    }

    mapping(address => bool) public blackList;
    modifier validUser(address addr) {
        require(blackList[addr] == false, "user is in blacklist");
        _;
    }

    function addBlackList(address addr, bool res) external ContractOwnerOnly {
        blackList[addr] = res;
    }
}

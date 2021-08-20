pragma solidity ^0.7.0;

// SPDX-License-Identifier: SimPL-2.0

interface IShop {
    function onOpenPackage(
        address to,
        uint256 packageId,
        bytes32 bh
    ) external returns (uint256[] memory);

    function getRarityWeights(uint256 packageId)
        external
        view
        returns (uint256[] memory);
}

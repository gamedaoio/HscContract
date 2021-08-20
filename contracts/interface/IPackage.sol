pragma solidity ^0.7.0;
// SPDX-License-Identifier: SimPL-2.0

interface IPackage {
    function mint(
        address to,
        uint256 tokenAmount,
        uint256 quantity,
        uint256 padding
    ) external;
}

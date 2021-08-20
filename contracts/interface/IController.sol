// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.7.0;

interface IController {
    function withdraw(address, uint256) external;

    function balanceOf(address) external view returns (uint256);

    function earn(address, uint256) external;

    function hasStrategy(address) external view returns (bool);
}

// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.7.0;

interface IStrategy {
    function hasStrategy(address _token) external view returns (bool);

    function deposit(address _token) external;

    function withdraw(address _token, uint256 _amount) external;

    function harvest(address to, bool islend) external;

    function withdrawAll(address _token) external returns (uint256);

    function withdrawAll() external;

    function balanceOf(address _token) external view returns (uint256);
}

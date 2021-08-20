pragma solidity ^0.7.0;

// SPDX-License-Identifier: SimPL-2.0

import {
    IERC20 as SIERC20
} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGDT is SIERC20 {
    function mint(address to, uint256 amount) external returns (bool);

    function totalSupply() external view override returns (uint256);

    function burn(address account, uint256 amount) external;
}

// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interface/IStrategy.sol";
import "../Member.sol";

contract LendHooController is Member {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 public tokenLen;
    mapping(uint256 => address) public tokenIndex;

    address public vault;
    address public strategy;

    constructor() {}

    function setVault(address _vault) public CheckPermit("Config") {
        vault = _vault;
    }

    function setStrategy(address _strategy) public CheckPermit("Config") {
        address _current = strategy;
        if (_current != address(0)) {
            IStrategy(_current).withdrawAll();
        }
        strategy = _strategy;
    }

    function earn(address _token, uint256 _amount) public {
        if (_token == address(0)) {
            address payable sender = payable(strategy);
            sender.transfer(_amount);
        } else {
            IERC20(_token).safeTransfer(strategy, _amount);
        }
        IStrategy(strategy).deposit(_token);
    }

    function harvest(address to, bool islend) public {
        IStrategy(strategy).harvest(to, islend);
    }

    function balanceOf(address _token) public returns (uint256) {
        return IStrategy(strategy).balanceOf(_token);
    }

    function hasStrategy(address _token) external view returns (bool) {
        return IStrategy(strategy).hasStrategy(_token);
    }

    function withdrawAll(address _token) public CheckPermit("Config") {
        IStrategy(strategy).withdrawAll(_token);
    }

    function withdraw(address _token, uint256 _amount) public {
        require(msg.sender == vault, "!vault");
        IStrategy(strategy).withdraw(_token, _amount);
    }

    receive() external payable {}
}

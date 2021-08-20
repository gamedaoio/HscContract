pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// SPDX-License-Identifier: SimPL-2.0

import "../shop/ShopRandom.sol";
import "./CardPoolBase.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interface/IController.sol";

contract ShopCardMine is CardPoolBase, ShopRandom {
    IERC20 public money;

    using SafeMath for uint256;

    uint256 public unitAmount = 1e18;

    mapping(address => address) public controllers;

    mapping(address => uint256) tokenAmounts;

    function setController(address token, address controller)
        external
        CheckPermit("Config")
    {
        controllers[token] = controller;
    }

    function setTokenAmount(address _token, uint256 _amount)
        external
        CheckPermit("Config")
    {
        _getPid(_token);
        tokenAmounts[_token] = _amount;
    }

    function withdraw(address token, uint256 amount) external payable {
        _withdraw(token, msg.sender, amount);

        _withdrawController(token, amount);

        if (token == address(0)) {
            address payable owner = msg.sender;
            owner.transfer(amount);
        } else {
            require(
                IERC20(token).transfer(msg.sender, amount),
                "transfer money failed"
            );
        }
    }

    function deposit(address token, uint256 amount) external payable {
        if (token == address(0)) {
            require(msg.value == amount, "invalid money amount");
        } else {
            require(
                IERC20(token).transferFrom(
                    msg.sender,
                    address(this),
                    uint256(amount)
                ),
                "transfer money failed"
            );
        }

        _deposit(token, msg.sender, amount);

        earn(token);
    }

    function available(address token) public view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(token).balanceOf(address(this));
        }
    }

    function earn(address token) public {
        address controller = controllers[token];

        if (controller == address(0)) {
            return;
        }
        if (IController(controller).hasStrategy(token)) {
            uint256 _bal = available(token);
            if (token == address(0)) {
                if (_bal > 0) {
                    address payable sender = payable(controller);
                    sender.transfer(_bal);
                }
            } else {
                IERC20(token).transfer(controller, _bal);
            }
            IController(controller).earn(address(token), _bal);
        }
    }

    function _withdrawController(address token, uint256 amount) internal {
        address controller = controllers[token];
        if (controller == address(0)) {
            return;
        }
        if (IController(controller).hasStrategy(token)) {
            if (token != address(0)) {
                uint256 b = IERC20(token).balanceOf(address(this));
                if (b < amount) {
                    uint256 _amount = amount.sub(b);
                    IController(controller).withdraw(token, _amount);
                }
            } else {
                uint256 b = address(this).balance;
                if (b < amount) {
                    uint256 _amount = amount.sub(b);
                    IController(controller).withdraw(token, _amount);
                }
            }
        }
    }

    function buy(address token, uint256 quantity) external {
        address owner = msg.sender;
        uint256 cost = unitAmount.mul(quantity);
        uint256 reward = getUserReward(token, msg.sender);
        if (cost > reward) {
            require(false, "insufficent");
        } else {
            _claim(token, owner, cost);
        }
        uint256 amount = tokenAmounts[token];
        _buyRandom(quantity, amount, 0);
    }

    receive() external payable {}
}

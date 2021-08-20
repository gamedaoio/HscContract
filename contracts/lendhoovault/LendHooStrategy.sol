// SPDX-License-Identifier: SimPL-2.0
pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interface/IController.sol";
import "../Member.sol";

interface IUnitroller {
    function claim(address holder) external;
}

interface LendToken is IERC20 {
    function mint(uint256 mintAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function getAccountSnapshot(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );
}

interface LendHoo {
    function mint() external payable;

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function getAccountSnapshot(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );
}

interface IVault {
    function getPoolAmount(address token) external view returns (uint256);
}

contract LendHooStrategy is Member {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public constant ldttrl = 0xF32F276D4deaaDc1A31bb53CD3230A3F6C61fA5B;
    address public ldt = 0xd63F3cceef518e183e27615A7D6404d0803210Af;

    address public controller;
    address public vaultAddress;

    mapping(address => address) lendTokens;
    address[] tokens;

    constructor(address _controller, address _vaultAddress) {
        controller = _controller;
        vaultAddress = _vaultAddress;
    }

    function setLendToken(address _token, address _lend)
        external
        CheckPermit("Config")
    {
        if (_token == address(0)) {
            LendHoo(_lend);
        } else {
            LendToken(_lend);
        }
        if (lendTokens[_token] == address(0)) {
            tokens.push(_token);
        }
        lendTokens[_token] = _lend;
    }

    function setVault(address _address) external CheckPermit("Config") {
        vaultAddress = _address;
    }

    function setController(address _controller) external CheckPermit("Config") {
        controller = _controller;
    }

    function hasStrategy(address _token) external view returns (bool) {
        if (lendTokens[_token] == address(0)) {
            return false;
        } else {
            return true;
        }
    }

    function harvest(address token, address to) external CheckPermit("Config") {
        uint256 totalAmount = IVault(vaultAddress).getPoolAmount(token);

        _withdraw(token, balanceOf(token));
        uint256 balance = balanceOfWant(token);
        if (balance.sub(totalAmount) > 0) {
            _transfer(to, token, balance.sub(totalAmount));
        }
        deposit(token);
    }

    function harvest(address to, bool islend) public onlyBenevolent {
        IUnitroller(ldttrl).claim(address(this));
        uint256 ldtBalance = IERC20(ldt).balanceOf(address(this));

        IERC20(ldt).safeTransfer(to, ldtBalance);

        if (islend) {
            uint256 len = tokens.length;

            for (uint256 i = 0; i < len; i++) {
                address _token = tokens[i];

                uint256 totalAmount =
                    IVault(vaultAddress).getPoolAmount(_token);

                _withdraw(_token, balanceOf(_token));
                uint256 balance = balanceOfWant(_token);
                if (balance.sub(totalAmount) > 0) {
                    _transfer(to, _token, balance.sub(totalAmount));
                }
                deposit(_token);
            }
        }
    }

    function deposit(address _token) public payable onlyBenevolent {
        address lendToken = lendTokens[_token];

        if (_token == address(0)) {
            uint256 amount = address(this).balance;
            if (amount > 0) {
                LendHoo(lendToken).mint{value: amount}();
            }
        } else {
            uint256 amount = IERC20(_token).balanceOf(address(this));

            if (amount > 0) {
                IERC20(_token).safeApprove(lendToken, 0);
                IERC20(_token).safeApprove(lendToken, amount);

                require(LendToken(lendToken).mint(amount) == 0, "deposit fail");
            }
        }
    }

    function withdraw(address _token, uint256 _amount) public onlyBenevolent {
        _withdraw(_token, _amount);
        _transfer(vaultAddress, _token, _amount);
        deposit(_token);
    }

    function _transfer(
        address to,
        address token,
        uint256 amount
    ) internal {
        require(to != address(0), "!to");

        if (token == address(0)) {
            address payable sender = payable(to);
            sender.transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function _withdraw(address _token, uint256 _amount)
        internal
        returns (uint256)
    {
        address lendToken = lendTokens[_token];
        require(
            LendToken(lendToken).redeemUnderlying(_amount) == 0,
            "redeem fail"
        );
    }

    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll(address _token) external returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        _withdraw(_token, balanceOf(_token));
        balance = balanceOfWant(_token);
        _transfer(vaultAddress, _token, balance);
    }

    function withdrawAll() external {
        require(msg.sender == controller, "!controller");
        uint256 len = tokens.length;

        for (uint256 i = 0; i < len; i++) {
            address _token = tokens[i];
            _withdraw(_token, balanceOf(_token));
            uint256 balance = balanceOfWant(_token);
            _transfer(vaultAddress, _token, balance);
        }
    }

    modifier onlyBenevolent {
        require(msg.sender == controller);
        _;
    }

    function balanceOfWant(address _token) public view returns (uint256) {
        if (_token == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(_token).balanceOf(address(this));
        }
    }

    function balanceOfPool(address _token) public view returns (uint256) {
        address lendToken = lendTokens[_token];
        if (_token == address(0)) {
            (, uint256 cTokenBal, , uint256 exchangeRate) =
                LendHoo(lendToken).getAccountSnapshot(address(this));
            return cTokenBal.mul(exchangeRate).div(1e18);
        } else {
            (, uint256 cTokenBal, , uint256 exchangeRate) =
                LendToken(lendToken).getAccountSnapshot(address(this));
            return cTokenBal.mul(exchangeRate).div(1e18);
        }
    }

    function balanceOf(address _token) public view returns (uint256) {
        return balanceOfWant(_token).add(balanceOfPool(_token));
    }

    receive() external payable {}
}

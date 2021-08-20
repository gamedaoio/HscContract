pragma solidity ^0.7.0;

// SPDX-License-Identifier: SimPL-2.0

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../lib/Util.sol";

import "../Member.sol";
import "../interface/IPackage.sol";

abstract contract Shop is Member {
    using SafeMath for uint256;
    IERC20 public token;

    uint256 public quantityMax = 0;
    uint256 public quantityCount = 0;

    uint256 public maxUserForSale = 0;
    mapping(address => uint256) public users;

    uint16[] public cardTypes;

    function setShopToken(string memory _token) external {
        token = IERC20(manager.members(_token));
    }

    function setMaxUserForSale(uint256 max) external CheckPermit("Config") {
        maxUserForSale = max;
    }

    function setQuantityMax(uint256 max) external CheckPermit("Config") {
        quantityMax = max;
    }

    function getRemain() external view returns (uint256) {
        return quantityMax - quantityCount;
    }

    function calcCardType(bytes memory seed) public view returns (uint256) {
        return cardTypes[Util.randomUint(seed, 0, cardTypes.length - 1)];
    }

    function addCardType(uint16 cardType) external CheckPermit("Config") {
        cardTypes.push(cardType);
    }

    function addCardTypes(uint16[] memory cts) external CheckPermit("Config") {
        uint256 length = cts.length;

        for (uint256 i = 0; i != length; ++i) {
            cardTypes.push(cts[i]);
        }
    }

    function setCardTypes(uint16[] memory cts) external CheckPermit("Config") {
        cardTypes = cts;
    }

    function removeCardType(uint256 index) external CheckPermit("Config") {
        cardTypes[index] = cardTypes[cardTypes.length - 1];
        cardTypes.pop();
    }

    // must be high -> low
    function removeCardTypes(uint256[] memory indexs)
        external
        CheckPermit("Config")
    {
        uint256 indexLength = indexs.length;
        uint256 ctLength = cardTypes.length;

        for (uint256 i = 0; i != indexLength; ++i) {
            cardTypes[indexs[i]] = cardTypes[--ctLength];
            cardTypes.pop();
        }
    }

    function removeAllCardTypes() external CheckPermit("Config") {
        delete cardTypes;
    }

    function _buy(
        address to,
        address tokenSender,
        uint256 tokenAmount,
        uint256 quantity,
        uint256 padding
    ) internal {
        quantityCount += quantity;
        if (quantityMax > 0) {
            require(quantityCount <= quantityMax, "quantity exceed");
        }

        if (maxUserForSale > 0) {
            require(
                maxUserForSale >= users[to].add(quantity),
                "user max limit"
            );
            users[to] = users[to].add(quantity);
        }

        if (tokenAmount > 0) {
            address card = manager.members("card");
            if (tokenSender == address(0)) {
                token.transfer(card, tokenAmount.mul(quantity));
            } else {
                require(
                    token.transferFrom(
                        tokenSender,
                        card,
                        tokenAmount.mul(quantity)
                    ),
                    "transfer failed"
                );
            }
        }

        IPackage(manager.members("package")).mint(
            to,
            tokenAmount,
            quantity,
            padding
        );
    }

    function stopShop() external CheckPermit("Admin") {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(manager.members("cashier"), balance);
        quantityMax = quantityCount;
    }

    function onOpenPackage(
        address to,
        uint256 packageId,
        bytes32 bh
    ) external virtual returns (uint256[] memory);

    function getRarityWeights(uint256 packageId)
        external
        view
        virtual
        returns (uint256[] memory);
}

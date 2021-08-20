pragma solidity ^0.7.0;

// SPDX-License-Identifier: SimPL-2.0

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IERC721ReceiverEx is IERC721Receiver {
    // bytes4(keccak256("onERC721ExReceived(address,address,uint256[],bytes)")) = 0x0f7b88e3
    function onERC721ExReceived(address operator, address from,
        uint256[] memory tokenIds, bytes memory data)
        external returns(bytes4);
}

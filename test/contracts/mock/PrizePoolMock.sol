// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

contract PrizePoolMock {
    IERC20 public immutable prizeToken;
    TwabController public immutable twabController;

    constructor(IERC20 _prizeToken, TwabController _twabController) {
        prizeToken = _prizeToken;
        twabController = _twabController;
    }

    function contributePrizeTokens(
        address,
        /* _prizeVault */ uint256 /* _amount */
    ) external view returns (uint256) {
        return prizeToken.balanceOf(address(this));
    }
}

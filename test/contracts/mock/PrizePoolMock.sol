// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

contract PrizePoolMock {

    event MockContribute(address prizeVault, uint256 amount);

    IERC20 public immutable prizeToken;
    TwabController public immutable twabController;

    constructor(IERC20 _prizeToken, TwabController _twabController) {
        prizeToken = _prizeToken;
        twabController = _twabController;
    }

    function contributePrizeTokens(
        address _prizeVault,
        uint256 _amount
    ) external returns (uint256) {
        emit MockContribute(_prizeVault, _amount);
        require(prizeToken.balanceOf(address(this)) >= _amount, "insufficient balance to contribute tokens");
        return _amount;
    }
}

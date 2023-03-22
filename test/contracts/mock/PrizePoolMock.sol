// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

contract PrizePoolMock {
  IERC20 public immutable prizeToken;

  constructor(IERC20 _prizeToken) {
    prizeToken = _prizeToken;
  }

  function contributePrizeTokens(
    address /* _prizeVault */,
    uint256 /* _amount */
  ) external view returns (uint256) {
    return prizeToken.balanceOf(address(this));
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC4626, ERC20, IERC20 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { IYieldVault, IERC4626 } from "../../../src/interfaces/IYieldVault.sol";

contract YieldVault is IYieldVault, ERC4626 {
  constructor(
    IERC20 _asset,
    string memory _name,
    string memory _symbol,
    address _yieldSource
  ) ERC4626(_asset) ERC20(_name, _symbol) {}
}

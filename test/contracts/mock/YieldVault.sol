// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC4626Mock, IERC20Metadata } from "openzeppelin/mocks/ERC4626Mock.sol";

contract YieldVault is ERC4626Mock {
  constructor(
    IERC20Metadata _asset,
    string memory _name,
    string memory _symbol
  ) ERC4626Mock(_asset, _name, _symbol) {}
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

contract ERC20PermitFallbackMock is ERC20Mock {
  constructor() ERC20Mock() {}

  fallback() external payable {
    // catch-all for functions that don't exist, like permit
  }
}

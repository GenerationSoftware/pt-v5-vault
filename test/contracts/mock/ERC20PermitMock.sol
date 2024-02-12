// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { ERC20Permit } from "openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";

contract ERC20PermitMock is ERC20Mock, ERC20Permit {
    constructor(string memory _name) ERC20Mock() ERC20Permit(_name) {}
}

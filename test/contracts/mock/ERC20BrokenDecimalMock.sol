// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

contract ERC20BrokenDecimalMock is ERC20Mock {
    constructor() ERC20Mock() {}

    function decimals() public view override returns(uint8) {
        revert("decimal fail");
    }
}

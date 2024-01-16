// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TwabERC20 } from "../../../src/TwabERC20.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

contract TwabERC20Wrapper is TwabERC20 {

    constructor(
        string memory name_,
        string memory symbol_,
        TwabController twabController_
    ) TwabERC20(name_, symbol_, twabController_) {}

    function mint(address _receiver, uint256 _amount) public {
        _mint(_receiver, _amount);
    }

    function burn(address _owner, uint256 _amount) public {
        _burn(_owner, _amount);
    }

}
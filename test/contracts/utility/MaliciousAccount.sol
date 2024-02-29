// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

contract MaliciousAccount {

    function execute(address _target, bytes calldata data) external returns (bytes memory) {
        (bool success, bytes memory returnData) = _target.call(data);
        require(success, string(abi.encodePacked(returnData)));
        return returnData;
    }

}

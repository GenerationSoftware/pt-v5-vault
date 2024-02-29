// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

struct ReentrantCall {
    uint count;
    address target;
    bytes data;
}

contract ReentrancyWrapper {
    uint[100000] private __gap;
    address payable target;

    mapping(bytes32 key => ReentrantCall reentrancyData) preEnters;
    mapping(bytes32 key => ReentrantCall reentrancyData) postEnters;

    constructor (address payable _target) {
        target = _target;
    }

    function preEnter(bytes calldata _calldata, uint count, address _target, bytes calldata _reentrancyData) external payable {
        preEnters[keccak256(_calldata)] = ReentrantCall(count, _target, _reentrancyData);
    }

    function postEnter(bytes calldata _calldata, uint count, address _target, bytes calldata _reentrancyData) external payable {
        postEnters[keccak256(_calldata)] = ReentrantCall(count, _target, _reentrancyData);
    }

    receive() external payable {}

    fallback(bytes calldata) external payable returns (bytes memory result) {
        bool success;
        bytes32 key = keccak256(msg.data);
        // console2.log("got here????");
        if (preEnters[key].count > 0) {
            preEnters[key].count--;
            // console2.log("PRE ENTERED");
            (success, ) = preEnters[key].target.call(preEnters[key].data);
            require(success, "ReentrancyWrapper: preEnter failed");
        }
        // console2.log("got here???? 1 1111");
        (success, result) = target.delegatecall(msg.data);
        require(success, string(abi.encodePacked(result)));
        // console2.log("got here???? 22 22");
        if (postEnters[key].count > 0) {
            postEnters[key].count--;
            (success, ) = postEnters[key].target.call(postEnters[key].data);
            require(success, "ReentrancyWrapper: postEnter failed");
        }

        return result;
    }

}

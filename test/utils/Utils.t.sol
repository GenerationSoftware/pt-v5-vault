// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";

contract Utils is Test {
  bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));

  function getNextUserAddress() external returns (address payable) {
    address payable user = payable(address(uint160(uint256(nextUser))));
    nextUser = keccak256(abi.encodePacked(nextUser));
    return user;
  }

  // Create users with 100 ETH balance each
  function createUsers(uint256 _userNum) external returns (address payable[] memory) {
    address payable[] memory users = new address payable[](_userNum);

    for (uint256 i = 0; i < _userNum; i++) {
      address payable user = this.getNextUserAddress();
      vm.deal(user, 100 ether);
      users[i] = user;
    }

    return users;
  }

  // Move block.number forward by a given number of blocks
  function mineBlocks(uint256 _numBlocks) external {
    vm.rollFork(block.number + _numBlocks);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

contract Utils is Test {
  // Move block.number forward by a given number of blocks
  function mineBlocks(uint256 _numBlocks) external {
    vm.rollFork(block.number + _numBlocks);
  }
}

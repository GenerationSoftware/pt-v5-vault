// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { Foo } from "../src/Foo.sol";

interface IERC20 {
  function balanceOf(address account) external view returns (uint256);
}

/// @dev See the "Writing Tests" section in the Foundry Book if this is your first time with Forge.
/// https://book.getfoundry.sh/forge/writing-tests
contract FooTest is Test {
  uint256 public mainnetFork;

  Foo public fooContract = new Foo();

  function setUp() public {
    mainnetFork = vm.createFork(vm.rpcUrl("mainnet"), 16_428_000);
  }

  /// @dev Simple test. Run Forge with `-vvvv` to see console logs.
  function test() external {
    string memory foo = fooContract.getFoo();
    console2.log(foo);

    assertEq(foo, "Foo");
  }

  /// @dev Test that runs against a fork of Ethereum Mainnet. You need to set `MAINNET_RPC_URL` in your `.envrc`
  function testFork() external {
    vm.selectFork(mainnetFork);

    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address holder = 0x7713974908Be4BEd47172370115e8b1219F4A5f0;
    uint256 actualBalance = IERC20(usdc).balanceOf(holder);
    uint256 expectedBalance = 196_307_713.810457e6;
    assertEq(actualBalance, expectedBalance);
  }
}

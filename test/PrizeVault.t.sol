// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { ERC20, IERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { console2 } from "forge-std/console2.sol";

import { PrizeVault } from "../src/PrizeVault.sol";
import { IYieldVault, YieldVault } from "./contracts/mock/YieldVault.sol";

contract PrizeVaultTest is Test {
  /* ============ Events ============ */

  event NewYieldVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    IYieldVault indexed yieldVault
  );

  /* ============ Variables ============ */

  ERC20 public asset;

  PrizeVault public prizeVault;
  string public prizeVaultName = "PoolTogether aEthDAI Prize Token (PTaEthDAI)";
  string public prizeVaultSymbol = "PTaEthDAI";

  YieldVault public yieldVault;
  string public yieldVaultName = "PoolTogether aEthDAI Yield (PTaEthDAIY)";
  string public yieldVaultSymbol = "PTaEthDAIY";

  function setUp() public {
    asset = new ERC20("Dai Stablecoin", "DAI");

    yieldVault = new YieldVault(
      asset,
      yieldVaultName,
      yieldVaultSymbol,
      address(0xfCc00A1e250644d89AF0df661bC6f04891E21585) // Aave Mainnet Lenging Pool
    );

    prizeVault = new PrizeVault(asset, prizeVaultName, prizeVaultSymbol, yieldVault);
  }

  function testConstructor() public {
    vm.expectEmit(true, true, true, true);
    emit NewYieldVault(IERC20(address(asset)), prizeVaultName, prizeVaultSymbol, yieldVault);

    PrizeVault testPrizeVault = new PrizeVault(asset, prizeVaultName, prizeVaultSymbol, yieldVault);

    assertEq(testPrizeVault.asset(), address(asset));
    assertEq(testPrizeVault.name(), prizeVaultName);
    assertEq(testPrizeVault.symbol(), prizeVaultSymbol);
    assertEq(address(testPrizeVault.yieldVault()), address(yieldVault));
  }

  function testConstructorAssetZero() external {
    vm.expectRevert(bytes("PV/asset-not-zero-address"));

    new PrizeVault(
      IERC20(address(0)),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      yieldVault
    );
  }

  function testConstructorYieldVaultZero() external {
    vm.expectRevert(bytes("PV/yieldVault-not-zero-address"));

    new PrizeVault(
      asset,
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      IYieldVault(address(0))
    );
  }
}

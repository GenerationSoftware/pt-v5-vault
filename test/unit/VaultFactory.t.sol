// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { VaultFactory } from "../../src/VaultFactory.sol";
import { Vault } from "../../src/Vault.sol";
import { YieldVault } from "../contracts/mock/YieldVault.sol";

contract VaultFactoryTest is Test {
  /* ============ Events ============ */
  event NewFactoryVault(Vault indexed vault, VaultFactory indexed vaultFactory);

  /* ============ Variables ============ */
  VaultFactory public vaultFactory;

  ERC20Mock public asset = new ERC20Mock();
  string public name = "PoolTogether aEthDAI Yield (PTaEthDAIY)";
  string public symbol = "PTaEthDAIY";

  TwabController public twabController =
    TwabController(address(0xDEBef0AD51fEF36a8ea13eEDA6B60Da2fef675cD));

  YieldVault public yieldVault = YieldVault(address(0xc24F43A638E2c32995108415fb3EB402Cd675580));
  PrizePool public prizePool = PrizePool(address(0x46fdfAdF967526047175693C751c920f786248C9));
  address public claimer = address(0xB6719828701798673852BceCadB764aaf26e8814);

  /* ============ Setup ============ */
  function setUp() public {
    vaultFactory = new VaultFactory();
  }

  /* ============ deployVault ============ */
  function testDeployVault() external {
    address _vault;

    // We don't know the vault address in advance, so we don't check topic 1
    vm.expectEmit(false, true, true, true);
    emit NewFactoryVault(Vault(_vault), vaultFactory);

    _vault = vaultFactory.deployVault(
      asset,
      name,
      symbol,
      twabController,
      yieldVault,
      prizePool,
      claimer,
      address(this),
      0,
      address(this)
    );

    assertEq(address(Vault(_vault).asset()), address(asset));

    assertEq(vaultFactory.totalVaults(), 1);
    assertTrue(vaultFactory.deployedVaults(Vault(_vault)));
  }

  function testDeployVault_secondDeployShouldHaveDiffAddress() public {
    Vault _vault1 = Vault(vaultFactory.deployVault(
      asset,
      name,
      symbol,
      twabController,
      yieldVault,
      prizePool,
      claimer,
      address(this),
      0,
      address(this)
    ));

    Vault _vault2 = Vault(vaultFactory.deployVault(
      asset,
      name,
      symbol,
      twabController,
      yieldVault,
      prizePool,
      claimer,
      address(this),
      0,
      address(this)
    ));

    assertNotEq(address(_vault1), address(_vault2));
  }
}

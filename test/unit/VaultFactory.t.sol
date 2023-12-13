// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { VaultFactory } from "../../src/VaultFactory.sol";
import { Vault } from "../../src/Vault.sol";
import { PrizePoolMock, IERC20 } from "../contracts/mock/PrizePoolMock.sol";
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

  PrizePoolMock public prizePool =
    new PrizePoolMock(IERC20(address(0x46fdfAdF967526047175693C751c920f786248C9)), twabController);

  address public claimer = address(0xB6719828701798673852BceCadB764aaf26e8814);

  /* ============ Setup ============ */
  function setUp() public {
    vaultFactory = new VaultFactory();

    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC4626.asset.selector),
      abi.encode(address(asset))
    );
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
      yieldVault,
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      0,
      address(this)
    );

    assertEq(address(Vault(_vault).asset()), address(asset));

    assertEq(vaultFactory.totalVaults(), 1);
    assertTrue(vaultFactory.deployedVaults(address(_vault)));
  }

  function testDeployVault_secondDeployShouldHaveDiffAddress() public {
    Vault _vault1 = Vault(
      vaultFactory.deployVault(
        asset,
        name,
        symbol,
        yieldVault,
        PrizePool(address(prizePool)),
        claimer,
        address(this),
        0,
        address(this)
      )
    );

    Vault _vault2 = Vault(
      vaultFactory.deployVault(
        asset,
        name,
        symbol,
        yieldVault,
        PrizePool(address(prizePool)),
        claimer,
        address(this),
        0,
        address(this)
      )
    );

    assertNotEq(address(_vault1), address(_vault2));
  }
}

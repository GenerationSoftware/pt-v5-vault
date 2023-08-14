// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { BrokenToken } from "brokentoken/BrokenToken.sol";
import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { IERC20, UnitBaseSetup } from "../../utils/UnitBaseSetup.t.sol";
import "../../../src/Vault.sol";

contract VaultDepositTest is UnitBaseSetup, BrokenToken {
  /* ============ Events ============ */
  event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

  event Sponsor(address indexed caller, uint256 assets, uint256 shares);

  event Sweep(address indexed caller, uint256 assets);

  event Transfer(address indexed from, address indexed to, uint256 value);

  /* ============ Tests ============ */

  /* ============ Deposit ============ */
  function testDeposit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.deposit(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testDepositAssetsLivingInVault() external {
    uint256 _vaultAmount = 500e18;
    underlyingAsset.mint(address(vault), _vaultAmount);

    assertEq(underlyingAsset.balanceOf(address(vault)), _vaultAmount);

    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.deposit(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(alice), _amount - _vaultAmount);
    assertEq(underlyingAsset.balanceOf(address(vault)), 0);
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);

    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testDepositOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), bob, _amount);

    vm.expectEmit();
    emit Deposit(alice, bob, _amount, _amount);

    vault.deposit(_amount, bob);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testDepositWithPermit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    _depositWithPermit(underlyingAsset, vault, _amount, alice, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testDepositWithPermitOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit();
    emit Transfer(address(0), bob, _amount);

    vm.expectEmit();
    emit Deposit(alice, bob, _amount, _amount);

    _depositWithPermit(underlyingAsset, vault, _amount, bob, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  /* ============ Deposit - Errors ============ */
  function testDepositMoreThanMax() external {
    vm.startPrank(alice);

    uint256 _amount = uint256(type(uint96).max) + 1;

    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(DepositMoreThanMax.selector, alice, _amount, type(uint96).max)
    );
    vault.deposit(_amount, alice);

    vm.stopPrank();
  }

  function testDepositMoreThanYieldVaultMax() external {
    vm.startPrank(alice);

    uint256 _amount = uint256(type(uint88).max) + 1;

    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC4626.maxDeposit.selector, address(vault)),
      abi.encode(type(uint88).max)
    );

    vm.expectRevert(
      abi.encodeWithSelector(DepositMoreThanMax.selector, alice, _amount, type(uint88).max)
    );

    vault.deposit(_amount, alice);

    vm.stopPrank();
  }

  function testYieldVaultExchangeRateManipulated() external {
    vm.startPrank(alice);

    // Alice deposits in a new YieldVault
    uint256 _yieldVaultAmount = 333e18;

    underlyingAsset.mint(alice, _yieldVaultAmount);
    underlyingAsset.approve(address(yieldVault), type(uint256).max);

    yieldVault.deposit(_yieldVaultAmount, alice);

    // 0.1e18 underlying assets are sent to the YieldVault
    // to manipulate the exchange rate
    underlyingAsset.mint(address(yieldVault), 0.1e18);

    // When Alice deposits in the Vault, her deposit reverts
    // because the amount of assets withdrawable from the YieldVault
    // is lower than the amount deposited by Alice
    uint256 _vaultAmount = 1000e18;

    underlyingAsset.mint(alice, _vaultAmount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(
        YVWithdrawableAssetsLTExpected.selector,
        _vaultAmount - 1,
        _vaultAmount
      )
    );

    vault.deposit(_vaultAmount, alice);
  }

  function testDepositVaultUndercollateralized() external {
    vm.startPrank(alice);

    uint256 _amount = 1000;

    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vault.deposit(_amount, alice);

    underlyingAsset.burn(address(yieldVault), _amount);

    vm.expectRevert(abi.encodeWithSelector(VaultUnderCollateralized.selector));

    vault.deposit(_amount, alice);

    vm.stopPrank();
  }

  /* ============ Deposit - Attacks ============ */
  function testFailDepositInflationAttack() external {
    vm.startPrank(bob);

    uint256 _attackAmount = 1000e18;
    uint256 _bobAmount = 1;
    uint256 _bobTotalAmount = _attackAmount + _bobAmount;

    underlyingAsset.mint(bob, _attackAmount + _bobAmount);

    _deposit(underlyingAsset, vault, _bobAmount, bob);

    // Bob transfers 1,000 underlying assets into the Vault in the hope of manipulating the exchange rate
    underlyingAsset.transfer(address(vault), _attackAmount);

    assertEq(vault.totalSupply(), _bobAmount);
    assertEq(vault.totalAssets(), _bobTotalAmount);

    vm.stopPrank();

    vm.startPrank(alice);

    uint256 _amount = 10_000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.deposit(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    /**
     * If assets are living in the Vault when a user deposits,
     * this amount of assets will offset the deposit amount
     * and we only transfer from the depositor the difference
     * (i.e. _amount - _attackAmount = 10,000 - 1,000 = 9,000)
     */
    assertEq(underlyingAsset.balanceOf(alice), _attackAmount);

    // The exchange rate has not been manipulated and is still equal to 1 unit of asset
    assertEq(vault.exchangeRate(), 10 ** 18);

    /**
     * Alice receives back the same amount of Vault shares than underlying assets deposited
     * despite the attempt by Bob to inflate the exchange rate.
     * This is because the exchange rate does not take into account
     * the amount of underlying assets living in the Vault.
     */
    assertEq(vault.balanceOf(alice), _amount);
    assertEq(IERC20(vault).balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount + _bobAmount);
    assertEq(underlyingAsset.balanceOf(address(vault)), 0);

    assertEq(yieldVault.balanceOf(address(vault)), _amount + _bobAmount);
    assertEq(yieldVault.totalSupply(), _amount + _bobAmount);

    vm.stopPrank();

    vm.startPrank(bob);

    // Bob manipulation failed and he can only withdraw 1 wei of underlying assets
    assertEq(vault.maxWithdraw(bob), _bobAmount);
    assertEq(vault.balanceOf(bob), _bobAmount);

    /**
     * Bob tries to redeem 1.99 shares to benefit from the attack
     * but it reverts cause he can only withdraw 1 wei of shares.
     */
    vault.redeem(vault.exchangeRate() * 2 - 1, bob, bob);
    assertEq(underlyingAsset.balanceOf(bob), 0);

    vm.stopPrank();
  }

  /* ============ Mint ============ */
  function testMint() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.mint(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testMintOnBehalf() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), bob, _amount);

    vm.expectEmit();
    emit Deposit(alice, bob, _amount, _amount);

    vault.mint(_amount, bob);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  /* ============ Mint - Errors ============ */
  function testMintMoreThanMax() external {
    vm.startPrank(alice);

    uint256 _amount = uint256(type(uint96).max) + 1;

    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(MintMoreThanMax.selector, alice, _amount, type(uint96).max)
    );

    vault.mint(_amount, alice);

    vm.stopPrank();
  }

  function testMintMoreThanYieldVaultMax() external {
    vm.startPrank(alice);

    uint256 _amount = uint256(type(uint88).max) + 1;

    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC4626.maxMint.selector, address(vault)),
      abi.encode(type(uint88).max)
    );

    vm.expectRevert(
      abi.encodeWithSelector(MintMoreThanMax.selector, alice, _amount, type(uint88).max)
    );

    vault.mint(_amount, alice);

    vm.stopPrank();
  }

  function testMintZeroShares() external {
    vm.startPrank(alice);

    vm.expectRevert(abi.encodeWithSelector(MintZeroShares.selector));

    vault.mint(0, alice);

    vm.stopPrank();
  }

  function testMintVaultUndercollateralized() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;

    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vault.mint(_amount, alice);

    underlyingAsset.burn(address(yieldVault), _amount);

    vm.expectRevert(abi.encodeWithSelector(VaultUnderCollateralized.selector));

    vault.mint(_amount, alice);

    vm.stopPrank();
  }

  /* ============ Sponsor ============ */
  function testSponsor() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Sponsor(alice, _amount, _amount);

    vault.sponsor(_amount);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testSponsorAlreadyDelegate() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    twabController.delegate(address(vault), twabController.SPONSORSHIP_ADDRESS());

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Sponsor(alice, _amount, _amount);

    vault.sponsor(_amount);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testSponsorWithPermit() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Sponsor(alice, _amount, _amount);

    _sponsorWithPermit(underlyingAsset, vault, _amount, alice, alicePrivateKey);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), SPONSORSHIP_ADDRESS), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  /* ============ Sweep ============ */
  function testSweep() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    underlyingAsset.transfer(address(vault), _amount);

    vm.stopPrank();

    vm.startPrank(bob);

    vm.expectEmit();
    emit Sweep(bob, _amount);

    vault.sweep();

    assertEq(vault.balanceOf(alice), 0);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(vault.balanceOf(bob), 0);

    assertEq(twabController.balanceOf(address(vault), bob), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    assertEq(vault.totalSupply(), 0);
    assertEq(vault.availableYieldBalance(), _amount);

    vm.stopPrank();
  }

  function testSweepZeroAssets() external {
    vm.startPrank(bob);

    vm.expectRevert(abi.encodeWithSelector(SweepZeroAssets.selector));

    vault.sweep();

    vm.stopPrank();
  }

  /* ============ Sweep - Error ============ */

  /* ============ Delegate ============ */
  function testDelegate() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    underlyingAsset.approve(address(vault), type(uint256).max);

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.deposit(_amount, alice);

    twabController.delegate(address(vault), bob);

    assertEq(vault.balanceOf(alice), _amount);
    assertEq(vault.balanceOf(bob), 0);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }
}

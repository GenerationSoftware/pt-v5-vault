// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { ERC20, IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { ILiquidationPair } from "pt-v5-liquidator-interfaces/ILiquidationPair.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { ERC20PermitMock } from "../contracts/mock/ERC20PermitMock.sol";
import { LiquidationPairMock } from "../contracts/mock/LiquidationPairMock.sol";
import { LiquidationRouterMock } from "../contracts/mock/LiquidationRouterMock.sol";
import { PrizePoolMock } from "../contracts/mock/PrizePoolMock.sol";
import { VaultMock } from "../contracts/mock/Vault.sol";
import { YieldVault } from "../contracts/mock/YieldVault.sol";

import { Helpers } from "./Helpers.t.sol";

contract UnitBaseSetup is Test, Helpers {
  /* ============ Variables ============ */
  address internal owner;
  uint256 internal ownerPrivateKey;

  address internal manager;
  uint256 internal managerPrivateKey;

  address internal alice;
  uint256 internal alicePrivateKey;

  address internal bob;
  uint256 internal bobPrivateKey;

  address public constant SPONSORSHIP_ADDRESS = address(1);

  VaultMock public vault;
  string public vaultName = "PoolTogether aEthDAI Prize Token (PTaEthDAI)";
  string public vaultSymbol = "PTaEthDAI";

  YieldVault public yieldVault;
  ERC20PermitMock public underlyingAsset;
  ERC20PermitMock public prizeToken;
  LiquidationRouterMock public liquidationRouter;
  LiquidationPairMock public liquidationPair;
  address public liquidationPairTarget = 0xcbE704e38ddB2E6A8bA9f4d335f2637132C20113;

  address public claimer;
  PrizePoolMock public prizePool;

  uint256 public winningRandomNumber = 123456;
  uint32 public drawPeriodSeconds = 1 days;
  TwabController public twabController;

  /* ============ Setup ============ */
  function setUpUnderlyingAsset() public virtual returns (ERC20PermitMock) {
    return new ERC20PermitMock("Dai Stablecoin");
  }

  function setUp() public virtual {
    (owner, ownerPrivateKey) = makeAddrAndKey("Owner");
    (manager, managerPrivateKey) = makeAddrAndKey("Manager");
    (alice, alicePrivateKey) = makeAddrAndKey("Alice");
    (bob, bobPrivateKey) = makeAddrAndKey("Bob");

    underlyingAsset = setUpUnderlyingAsset();
    prizeToken = new ERC20PermitMock("PoolTogether");

    twabController = new TwabController(1 days, uint32(block.timestamp));

    prizePool = new PrizePoolMock(prizeToken, twabController);

    claimer = address(0xe291d9169F0316272482dD82bF297BB0a11D267f);

    yieldVault = new YieldVault(
      address(underlyingAsset),
      "PoolTogether aEthDAI Yield (PTaEthDAIY)",
      "PTaEthDAIY"
    );

    vault = new VaultMock(
      underlyingAsset,
      vaultName,
      vaultSymbol,
      twabController,
      yieldVault,
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      0,
      address(this)
    );

    liquidationPair = new LiquidationPairMock(
      address(vault),
      address(prizePool),
      address(prizeToken),
      address(vault)
    );

    liquidationRouter = new LiquidationRouterMock();
  }

  /* ============ Helpers ============ */
  function _setLiquidationPair() internal returns (address) {
    return vault.setLiquidationPair(ILiquidationPair(address(liquidationPair)));
  }
}

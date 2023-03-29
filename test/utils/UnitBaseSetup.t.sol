// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { PrizePool } from "v5-prize-pool/PrizePool.sol";
import { TwabController } from "v5-twab-controller/TwabController.sol";
import { Claimer } from "v5-vrgda-claimer/Claimer.sol";

import { Vault } from "src/Vault.sol";

import { ERC20PermitMock } from "test/contracts/mock/ERC20PermitMock.sol";
import { LiquidationPairMock } from "test/contracts/mock/LiquidationPairMock.sol";
import { LiquidationRouterMock } from "test/contracts/mock/LiquidationRouterMock.sol";
import { PrizePoolMock } from "test/contracts/mock/PrizePoolMock.sol";
import { YieldVault } from "test/contracts/mock/YieldVault.sol";

contract UnitBaseSetup is Test {
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

  Vault public vault;
  string public vaultName = "PoolTogether aEthDAI Prize Token (PTaEthDAI)";
  string public vaultSymbol = "PTaEthDAI";

  IERC4626 public yieldVault;
  ERC20PermitMock public underlyingAsset;
  ERC20PermitMock public prizeToken;
  LiquidationRouterMock public liquidationRouter;
  LiquidationPairMock public liquidationPair;
  address public liquidationPairTarget = 0xcbE704e38ddB2E6A8bA9f4d335f2637132C20113;

  Claimer public claimer;
  PrizePoolMock public prizePool;

  uint256 public winningRandomNumber = 123456;
  uint32 public drawPeriodSeconds = 1 days;
  TwabController public twabController;

  /* ============ Setup ============ */

  function setUp() public {
    (owner, ownerPrivateKey) = makeAddrAndKey("Owner");
    (manager, managerPrivateKey) = makeAddrAndKey("Manager");
    (alice, alicePrivateKey) = makeAddrAndKey("Alice");
    (bob, bobPrivateKey) = makeAddrAndKey("Bob");

    underlyingAsset = new ERC20PermitMock("Dai Stablecoin", "DAI", address(this), 0);
    prizeToken = new ERC20PermitMock("PoolTogether", "POOL", address(this), 0);

    twabController = new TwabController();

    prizePool = new PrizePoolMock(prizeToken);

    claimer = Claimer(address(0xe291d9169F0316272482dD82bF297BB0a11D267f));

    yieldVault = new YieldVault(
      underlyingAsset,
      "PoolTogether aEthDAI Yield (PTaEthDAIY)",
      "PTaEthDAIY"
    );

    vault = new Vault(
      underlyingAsset,
      vaultName,
      vaultSymbol,
      twabController,
      yieldVault,
      PrizePool(address(prizePool)),
      claimer,
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
}

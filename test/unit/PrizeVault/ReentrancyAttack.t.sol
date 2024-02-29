// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console2.sol";

import { UnitBaseSetup, PrizePool, TwabController, ERC20, IERC20, IERC4626 } from "./UnitBaseSetup.t.sol";

import "../../../src/PrizeVault.sol";
import { ReentrancyWrapper } from "../../contracts/utility/ReentrancyWrapper.sol";
import { MaliciousAccount } from "../../contracts/utility/MaliciousAccount.sol";
import { LiquidationPairMock } from "../../contracts/mock/LiquidationPairMock.sol";
import { PrizeVaultWrapper, PrizeVault } from "../../contracts/wrapper/PrizeVaultWrapper.sol";

contract PrizeVaultTest is UnitBaseSetup {

    uint32 public constant YIELD_FEE_PERCENTAGE = 100000000; // 0.1 = 10%

    ReentrancyWrapper public reentrantVault;

    MaliciousAccount public account;

    function setUp() public override {
        super.setUp();

        reentrantVault = new ReentrancyWrapper(payable(address(yieldVault)));

        vault = new PrizeVaultWrapper(
            vaultName,
            vaultSymbol,
            IERC4626(address(reentrantVault)),
            PrizePool(address(prizePool)),
            claimer,
            address(this),
            0,
            1e6,
            address(this)
        );

        liquidationPair = new LiquidationPairMock(
            address(vault),
            address(prizePool),
            address(prizeToken),
            address(vault)
        );

        account = new MaliciousAccount();
    }

    function testReentrantDeposit() public {
        underlyingAsset.mint(address(account), 1e18);
        vm.startPrank(address(account));
        underlyingAsset.approve(address(vault), 1e18);
        vm.stopPrank();

        reentrantUnderlyingAsset.preEnter(
            abi.encodeWithSelector(underlyingAsset.transferFrom.selector, address(account), address(vault), 1e18),
            1,
            address(account),
            abi.encodeWithSelector(
                account.execute.selector,
                address(vault),
                abi.encodeWithSelector(vault.deposit.selector, 1e18, address(account))
            )
        );

        account.execute(address(vault), abi.encodeWithSelector(vault.deposit.selector, 1e18, address(account)));
    }

}

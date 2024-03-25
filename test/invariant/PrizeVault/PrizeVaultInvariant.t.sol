// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { PrizeVaultFuzzHarness, PrizeVault } from "./PrizeVaultFuzzHarness.sol";

/// @dev This contract runs tests in a scenario where the yield vault can never lose funds (strictly increasing).
contract PrizeVaultInvariant is Test {
    PrizeVaultFuzzHarness public vaultHarness;

    modifier useCurrentTime() {
        vm.warp(vaultHarness.currentTime());
        _;
    }

    function setUp() external virtual {
        vaultHarness = new PrizeVaultFuzzHarness(1e5);
        targetContract(address(vaultHarness));

        // mint some initial yield (enough to cover the yield buffer)
        vaultHarness.accrueYield(1e5);
    }

    function invariantAssetsCoverDebt() external useCurrentTime {
        uint256 totalAssets = vaultHarness.vault().totalPreciseAssets();
        uint256 totalDebt = vaultHarness.vault().totalDebt();
        assertGe(totalAssets, totalDebt);
    }

    function invariantDebtAtLeastSupply() external useCurrentTime {
        uint256 totalDebt = vaultHarness.vault().totalDebt();
        uint256 totalSupply = vaultHarness.vault().totalSupply();
        assertGe(totalDebt, totalSupply);
    }

    function invariantLiquidBalanceOfAssetsNoMoreThanAvailableYield() external useCurrentTime {
        address asset = address(vaultHarness.underlyingAsset());
        uint256 liquidBalance = vaultHarness.vault().liquidatableBalanceOf(asset);
        uint256 availableYieldBalance = vaultHarness.vault().availableYieldBalance();
        assertLe(liquidBalance, availableYieldBalance);
    }

    function invariantLiquidBalanceOfSharesNoMoreThanAvailableYield() external useCurrentTime {
        address vault = address(vaultHarness.vault());
        uint256 liquidBalance = vaultHarness.vault().liquidatableBalanceOf(vault);
        uint256 availableYieldBalance = vaultHarness.vault().availableYieldBalance();
        assertLe(liquidBalance, availableYieldBalance);
    }

    function invariantYieldFeeBalanceAlwaysClaimable() external useCurrentTime {
        uint256 supplyLimit = type(uint96).max - vaultHarness.vault().totalSupply();
        uint256 yieldFeeBalance = vaultHarness.vault().yieldFeeBalance();
        assertLe(yieldFeeBalance, supplyLimit);
    }

    function invariantAllAssetsAccountedFor() external useCurrentTime {
        PrizeVault vault = vaultHarness.vault();
        uint256 totalAssets = vault.totalPreciseAssets();
        uint256 totalDebt = vault.totalDebt();
        uint256 currentYieldBuffer = vault.currentYieldBuffer();
        uint256 availableYieldBalance = vault.availableYieldBalance();
        uint256 totalAccounted = totalDebt + currentYieldBuffer + availableYieldBalance;
        assertEq(totalAssets, totalAccounted);

        // totalYieldBalance = currentYieldBuffer + availableYieldBalance
        uint256 totalAccounted2 = totalDebt + vault.totalYieldBalance();
        assertEq(totalAssets, totalAccounted2);
    }
}
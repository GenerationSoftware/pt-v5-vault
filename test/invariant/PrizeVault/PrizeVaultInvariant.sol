// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { PrizeVaultFuzzHarness, PrizeVault } from "./PrizeVaultFuzzHarness.sol";

/// @dev This contract runs tests in a scenario where the yield vault can never lose funds (strictly increasing).
contract PrizeVaultInvariant is Test {
    PrizeVaultFuzzHarness public vaultHarness;

    function setUp() external {
        vaultHarness = new PrizeVaultFuzzHarness(1e5);
        targetContract(address(vaultHarness));

        // mint some initial yield (enough to cover the yield buffer)
        vaultHarness.accrueYield(1e5);
    }

    function invariantAssetsCoverDebt() external {
        uint256 totalAssets = vaultHarness.vault().totalAssets();
        uint256 totalDebt = vaultHarness.vault().totalDebt();
        assertGe(totalAssets, totalDebt);
    }

    function invariantDebtAtLeastSupply() external {
        uint256 totalDebt = vaultHarness.vault().totalDebt();
        uint256 totalSupply = vaultHarness.vault().totalSupply();
        assertGe(totalDebt, totalSupply);
    }

    function invariantLiquidBalanceOfAssetsNoMoreThanAvailableYield() external {
        address asset = address(vaultHarness.underlyingAsset());
        uint256 liquidBalance = vaultHarness.vault().liquidatableBalanceOf(asset);
        uint256 availableYieldBalance = vaultHarness.vault().availableYieldBalance();
        assertLe(liquidBalance, availableYieldBalance);
    }

    function invariantLiquidBalanceOfSharesNoMoreThanAvailableYield() external {
        address vault = address(vaultHarness.vault());
        uint256 liquidBalance = vaultHarness.vault().liquidatableBalanceOf(vault);
        uint256 availableYieldBalance = vaultHarness.vault().availableYieldBalance();
        assertLe(liquidBalance, availableYieldBalance);
    }

    function invariantAllAssetsAccountedFor() external {
        PrizeVault vault = vaultHarness.vault();
        uint256 totalAssets = vault.totalAssets();
        uint256 totalDebt = vault.totalDebt();
        uint256 availableYieldBuffer = vault.availableYieldBuffer();
        uint256 availableYieldBalance = vault.availableYieldBalance();
        uint256 totalAccounted = totalDebt + availableYieldBuffer + availableYieldBalance;
        assertEq(totalAssets, totalAccounted);
    }
}
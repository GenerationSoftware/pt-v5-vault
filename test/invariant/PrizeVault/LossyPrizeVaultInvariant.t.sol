// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { LossyPrizeVaultFuzzHarness } from "./LossyPrizeVaultFuzzHarness.sol";

/// @dev This contract runs tests in a scenario where the yield vault can gain or lose funds and checks that the
/// expected lossy behaviors are adhered to.
contract LossyPrizeVaultInvariant is Test {
    LossyPrizeVaultFuzzHarness public lossyVaultHarness;

    function setUp() external {
        lossyVaultHarness = new LossyPrizeVaultFuzzHarness(1e5);
        targetContract(address(lossyVaultHarness));
    }

    function invariantDisableDepositsOnLoss() external {
        uint256 totalPreciseAssets = lossyVaultHarness.vault().totalPreciseAssets();
        uint256 totalDebt = lossyVaultHarness.vault().totalDebt();
        uint256 totalSupply = lossyVaultHarness.vault().totalSupply();
        uint256 yieldBuffer = lossyVaultHarness.vault().yieldBuffer();
        if (totalDebt + yieldBuffer / 2 > totalPreciseAssets || type(uint96).max - totalSupply == 0) {
            assertEq(lossyVaultHarness.vault().maxDeposit(address(this)), 0);
        } else {
            assertGt(lossyVaultHarness.vault().maxDeposit(address(this)), 0);
        }
    }

    function invariantNoYieldWhenDebtExceedsAssets() external {
        uint256 totalPreciseAssets = lossyVaultHarness.vault().totalPreciseAssets();
        uint256 totalDebt = lossyVaultHarness.vault().totalDebt();
        if (totalDebt >= totalPreciseAssets) {
            assertEq(lossyVaultHarness.vault().liquidatableBalanceOf(address(lossyVaultHarness.underlyingAsset())), 0);
            assertEq(lossyVaultHarness.vault().liquidatableBalanceOf(address(lossyVaultHarness.vault())), 0);
            assertEq(lossyVaultHarness.vault().availableYieldBalance(), 0);
        }
    }

    function invariantYieldFeeBalanceAlwaysClaimable() external {
        uint256 supplyLimit = type(uint96).max - lossyVaultHarness.vault().totalSupply();
        uint256 yieldFeeBalance = lossyVaultHarness.vault().yieldFeeBalance();
        assertLe(yieldFeeBalance, supplyLimit);
    }

    function invariantAllAssetsAccountedFor() external {
        uint256 totalPreciseAssets = lossyVaultHarness.vault().totalPreciseAssets();
        uint256 totalDebt = lossyVaultHarness.vault().totalDebt();
        if (totalDebt >= totalPreciseAssets) {
            // 1 wei rounding error since the convertToAssets function rounds down which means up to 1 asset may be lost on total conversion
            assertApproxEqAbs(totalPreciseAssets, lossyVaultHarness.vault().convertToAssets(totalDebt), 1);
        } else {
            // When assets cover debts, we have essentially the same test as the the sister test in `PrizeVaultInvariant.sol`
            // The debt is converted to assets using `convertToAssets` to test that it will always be 1:1 when the vault has ample collateral.
            uint256 currentYieldBuffer = lossyVaultHarness.vault().currentYieldBuffer();
            uint256 availableYieldBalance = lossyVaultHarness.vault().availableYieldBalance();
            uint256 totalAccounted = lossyVaultHarness.vault().convertToAssets(totalDebt) + currentYieldBuffer + availableYieldBalance;
            assertEq(totalPreciseAssets, totalAccounted);

            // totalYieldBalance = currentYieldBuffer + availableYieldBalance
            uint256 totalAccounted2 = totalDebt + lossyVaultHarness.vault().totalYieldBalance();
            assertEq(totalPreciseAssets, totalAccounted2);
        }
    }
}
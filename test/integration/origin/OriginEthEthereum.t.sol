// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

/**
 * Issues Found:
 * - OETH has an issue where transferring a rebasing balance can sometimes result in a 1 or 2 wei rounding error in
 *   the receiver's resulting balance. For example, the `Transfer` event records 1e18, but the resulting balance is 
 *   1e18 - 1. This shouldn't cause any issues in the prize vault since it's built to deal with small rounding errors, 
 *   but it may cause issues with integrations built on top of the prize vault since it may receive less tokens than
 *   expected during a withdraw or redeem. (https://github.com/OriginProtocol/origin-dollar/issues/1411#issuecomment-1536546728)
 */


contract OriginEthEthereumIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 20033559;
    uint256 forkBlockTimestamp = 1717686251;

    address internal _asset = address(0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3);
    address internal _assetWhale = address(0xa4C637e0F704745D182e4D38cAb7E7485321d059);
    address internal _yieldVault = address(0xDcEe70654261AF21C44c093C300eD3Bb97b78192);


    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 3800e18); // approx 1 OETH for $3800
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("mainnet"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 3 gwei;
        assetPrecisionLoss = 1; // loses 1 decimal of precision due to extra 1-wei rounding errors on transfer
        roundingErrorOnTransfer = 1; // loses 1 wei on asset transfer
    }

    function afterSetup() public virtual override { }

    /* ============ helpers to override ============ */

    /// @dev The max amount of assets than can be dealt.
    function maxDeal() public virtual override returns (uint256) {
        return underlyingAsset.balanceOf(_assetWhale);
    }

    /// @dev May revert if the amount requested exceeds the amount available to deal.
    function dealAssets(address to, uint256 amount) public virtual override prankception(_assetWhale) {
        underlyingAsset.transfer(to, amount);
    }

    /// @dev Accrues yield by transferring assets to the yield vault
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        IERC20(_asset).transfer(_yieldVault, (IERC4626(_yieldVault).totalAssets()) / 1000); // 0.1% increase
    }

    /// @dev Loss simulated by transferring assets out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        IERC20(_asset).transfer(_assetWhale, IERC4626(_yieldVault).totalAssets() / 2); // 50% loss
    }

}
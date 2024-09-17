// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract SUsdsEthereumIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 20772374;
    uint256 forkBlockTimestamp = 1726600823;

    address internal _asset = address(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    address internal _assetWhale = address(0x2621CC0B3F3c079c1Db0E80794AA24976F0b9e3c);
    address internal _yieldVault = address(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 1e18);
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
        lowGasPriceEstimate = 7 gwei;
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

    /// @dev Accrues yield by letting some time pass
    function _accrueYield() internal virtual override {
        vm.warp(block.timestamp + 1 days); // let 1 day pass by
    }

    /// @dev Since it's difficult to simulate any loss in the DSR system, we'll simulate loss by removing sDAI from the prize vault
    function _simulateLoss() internal virtual override prankception(address(prizeVault)) {
        yieldVault.transfer(_assetWhale, yieldVault.balanceOf(address(prizeVault)) / 2);
    }

}
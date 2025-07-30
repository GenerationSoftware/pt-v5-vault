// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract MorphoRe7UsdcWorldIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 17278217;
    uint256 forkBlockTimestamp = 1753892073;

    address internal _asset = address(0x79A02482A880bCE3F13e09Da970dC34db4CD24d1);
    address internal _assetWhale = address(0xF977814e90dA44bFA03b6295A0616a897441aceC);
    address internal _yieldVault = address(0xb1E80387EbE53Ff75a89736097D34dC8D9E9045B);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 6, 1e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("world"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.05 gwei;
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

    /// @dev Accrue yield by letting time pass.
    function _accrueYield() internal virtual override {
        vm.warp(block.timestamp + 1 days);
    }

    /// @dev Simulates loss by sending yield vault tokens out of the prize vault
    function _simulateLoss() internal virtual override prankception(address(prizeVault)) {
        yieldVault.transfer(_assetWhale, yieldVault.balanceOf(address(prizeVault)) / 2);
    }

}
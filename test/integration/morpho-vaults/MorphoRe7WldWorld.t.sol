// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract MorphoRe7WldWorldIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 17278217;
    uint256 forkBlockTimestamp = 1753892073;

    address internal _asset = address(0x2cFc85d8E48F8EAB294be644d9E25C3030863003);
    address internal _assetWhale = address(0xF977814e90dA44bFA03b6295A0616a897441aceC);
    address internal _yieldVault = address(0x348831b46876d3dF2Db98BdEc5E3B4083329Ab9f);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 1.08e18);
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

    /// @dev Normally, we would test yield by letting time pass for this vault, but there are no borrows atm so 
    /// we will instead send assets directly into the prize vault.
    function _accrueYield() internal virtual override {
        // vm.warp(block.timestamp + 1 days);
        dealAssets(address(prizeVault), 100e18);
    }

    /// @dev Simulates loss by sending yield vault tokens out of the prize vault
    function _simulateLoss() internal virtual override prankception(address(prizeVault)) {
        yieldVault.transfer(_assetWhale, yieldVault.balanceOf(address(prizeVault)) / 2);
    }

}
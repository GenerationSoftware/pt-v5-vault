// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract MorphoMoonwellWethBaseIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 23787058;
    uint256 forkBlockTimestamp = 1734363463;

    address internal _asset = address(0x4200000000000000000000000000000000000006);
    address internal _assetWhale = address(0x6446021F4E396dA3df4235C62537431372195D38);
    address internal _yieldVault = address(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 4_000e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("base"), forkBlock);
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

    /// @dev Accrues yield by letting some time pass
    function _accrueYield() internal virtual override {
        vm.warp(block.timestamp + 1 days);
    }

    /// @dev Simulates loss by sending yield vault tokens out of the prize vault
    function _simulateLoss() internal virtual override prankception(address(prizeVault)) {
        yieldVault.transfer(_assetWhale, yieldVault.balanceOf(address(prizeVault)) / 2);
    }

}
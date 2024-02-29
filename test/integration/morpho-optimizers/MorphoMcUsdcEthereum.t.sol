// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract MorphoMcUsdcEthereumIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 19284702;
    uint256 forkBlockTimestamp = 1708623756;

    address internal _asset = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address internal _assetWhale = address(0xD6153F5af5679a75cC85D8974463545181f48772);
    address internal _yieldVault = address(0xba9E3b3b684719F80657af1A19DEbc3C772494a0);
    address internal _compoundMorphoProxy = address(0x8888882f8f843896699869179fB6E4f7e3B58888);
    address internal _cUsdc = address(0x39AA39c021dfbaE8faC545936693aC917d5E7563);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 6, 1e18);
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

    /// @dev Accrues yield by transferring USDC to the cUSDC contract
    function _accrueYield() internal virtual override {
        dealAssets(_cUsdc, 10_000e6);
    }

    /// @dev Simulates loss by transferring some cUSDC out of the cUSDC contract
    function _simulateLoss() internal virtual override prankception(_cUsdc) {
        underlyingAsset.transfer(_assetWhale, underlyingAsset.balanceOf(_cUsdc) / 2);
    }

}
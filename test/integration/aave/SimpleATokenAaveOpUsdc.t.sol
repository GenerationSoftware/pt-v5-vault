// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract SimpleATokenAaveOpUsdcIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 116520030;
    uint256 forkBlockTimestamp = 1708638836;

    address internal _asset = address(0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5);
    address internal _assetWhale = address(0x66627C3bF54b9aCDA8409032CaF7b966d101fead);
    address internal _yieldVault = address(0xe16980a976571E217ADD4c32DfA5DA5cE504003B);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 6, 1e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("optimism"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.05 gwei; // just L2 gas, we ignore L1 costs for a super low estimate
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

    /// @dev Simulates loss by transferring some liquid tokens out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        underlyingAsset.transfer(_assetWhale, underlyingAsset.balanceOf(_yieldVault) / 2); // transfer assets out of the yield vault
    }

}
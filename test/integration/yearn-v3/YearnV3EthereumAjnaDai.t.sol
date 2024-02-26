// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract YearnV3EthereumAjnaDaiIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 19284702;
    uint256 forkBlockTimestamp = 1708623756;

    address internal _asset = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address internal _assetWhale = address(0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8);
    address internal _yieldVault = address(0xe24BA27551aBE96Ca401D39761cA2319Ea14e3CB);
    // address internal _ysDaiPool = address(0x95639194F1A0C2F1E83e66Bd994bD7D0477afeBB);
    // address internal _ysDaiPool2 = address(0x3B9A4D5F3e5F578245baF9348bFFf94F5A112dB2);
    address internal _daiPoolUnderlying = address(0x66ea46C6e7F9e5BB065bd3B1090FFF229393BA51);
    address internal _someDepositor = address(0x54C6b2b293297e65b1d163C3E8dbc45338bfE443);

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

    /// @dev Accrues yield by letting time pass
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        vm.warp(block.timestamp + 1 days); // let 1 day pass by
    }

    /// @dev Simulates loss by transferring some yield bearing tokens out of the vault
    function _simulateLoss() internal virtual override prankception(_daiPoolUnderlying) {
        // transfer some yield bearing assets out of the vault
        // IERC20(_ysDaiPool).transfer(_assetWhale, IERC20(_ysDaiPool).balanceOf(_yieldVault)); 
        // IERC20(_ysDaiPool2).transfer(_assetWhale, IERC20(_ysDaiPool2).balanceOf(_yieldVault));

        underlyingAsset.transfer(_assetWhale, underlyingAsset.balanceOf(_daiPoolUnderlying) / 2); // one of the pools experiences a loss

        uint256 totalAssetsBefore = yieldVault.totalAssets();

        startPrank(_someDepositor);
        uint256 shares = yieldVault.maxRedeem(_someDepositor);
        assertEq(shares, 0, "test");
        uint256 assets = yieldVault.redeem(shares, _someDepositor, _someDepositor);
        assertEq(assets, 0, "test");
        assertEq(yieldVault.totalAssets(), totalAssetsBefore, "test");
        stopPrank();
    }

}
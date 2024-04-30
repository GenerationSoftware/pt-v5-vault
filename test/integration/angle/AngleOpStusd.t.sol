// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract AngleOpStusdIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 119403166;
    uint256 forkBlockTimestamp = 1714405109;

    address internal _asset = address(0x0000206329b97DB379d5E1Bf586BbDB969C63274);
    address internal _assetWhale = address(0xaFeb95DEF3B2A3D532D74DaBd51E62048d6c07A4);
    address internal _yieldVault = address(0x0022228a2cc5E7eF0274A7Baa600d44da5aB5776);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 1e18);
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

    /// @dev Transfer tokens to the yield vault
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        dealAssets(_yieldVault, 10 ** assetDecimals);
    }

    /// @dev Transfer tokens out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        underlyingAsset.transfer(_assetWhale, underlyingAsset.balanceOf(_yieldVault) / 2); // transfer assets out of the yield vault
    }

}
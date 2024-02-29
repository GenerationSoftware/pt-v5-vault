// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract MorphoMcUniEthereumIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 19284702;
    uint256 forkBlockTimestamp = 1708623756;

    address internal _asset = address(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    address internal _assetWhale = address(0xF977814e90dA44bFA03b6295A0616a897441aceC);
    address internal _yieldVault = address(0x496da625C736a2fF122638Dc26dCf1bFdEf1778c);
    address internal _compoundMorphoProxy = address(0x8888882f8f843896699869179fB6E4f7e3B58888);
    address internal _cUni = address(0x35A18000230DA775CAc24873d00Ff85BccdeD550);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 1e18 / 10); // about $10 / UNI
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

    /// @dev Accrues yield by transferring UNI to the cUNI contract
    function _accrueYield() internal virtual override {
        dealAssets(_cUni, 100e18);
    }

    /// @dev Simulates loss by transferring some cUNI out of the cUNI contract
    function _simulateLoss() internal virtual override prankception(_cUni) {
        underlyingAsset.transfer(_assetWhale, underlyingAsset.balanceOf(_cUni) / 2);
    }

}
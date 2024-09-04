// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

interface IMorpho {
    function market(bytes32 id) external view returns (Market memory m);
}

struct Market {
    uint128 totalSupplyAssets;
    uint128 totalSupplyShares;
    uint128 totalBorrowAssets;
    uint128 totalBorrowShares;
    uint128 lastUpdate;
    uint128 fee;
}

contract MorphoGauntletWethPrimeEthereumIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 20678002;
    uint256 forkBlockTimestamp = 1725462323;

    address internal _asset = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal _assetWhale = address(0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E);
    address internal _yieldVault = address(0x2371e134e3455e0593363cBF89d3b6cf53740618);
    address internal _morpho = address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    bytes32 internal _assetMarketId = bytes32(0xc54d7acf14de29e0e5527cabd7a576506870346a78a11a6762e2cca66322ec41);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 2500e18);
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
        lowGasPriceEstimate = 0.1 gwei;
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
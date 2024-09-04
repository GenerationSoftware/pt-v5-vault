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

contract MorphoGauntletUsdcEthereumIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 20678002;
    uint256 forkBlockTimestamp = 1725462323;

    address internal _asset = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address internal _assetWhale = address(0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa);
    address internal _yieldVault = address(0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458);
    address internal _morpho = address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    bytes32 internal _assetMarketId = bytes32(0x54efdee08e272e929034a8f26f7ca34b1ebe364b275391169b28c6d7db24dbc8);

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

    /// @dev Simulates loss by mocking the total assets on the market
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        Market memory _marketData = IMorpho(_morpho).market(_assetMarketId);
        _marketData.totalSupplyAssets = _marketData.totalSupplyAssets / 2;
        vm.mockCall(_morpho, abi.encodeWithSelector(IMorpho.market.selector), abi.encode(_marketData));
    }

}
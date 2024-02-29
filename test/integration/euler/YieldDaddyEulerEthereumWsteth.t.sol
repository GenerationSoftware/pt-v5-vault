// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract YieldDaddyEulerEthereumWstethIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 19284702;
    uint256 forkBlockTimestamp = 1708623756;

    address internal _asset = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    address internal _assetWhale = address(0x0B925eD163218f6662a35e0f0371Ac234f9E9371);
    address internal _yieldVault = address(0x60897720AA966452e8706e74296B018990aEc527);
    address internal _ewstEth = address(0xbd1bd5C956684f7EB79DA40f582cbE1373A1D593);
    address internal _ewstEthWhale = address(0xcec2981d8047C401F2A4E972a7e5AdA3f5EcF838);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 3600e18); // $3600 / wsteth
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

    /// @dev Accrues yield by sending some yield bearing tokens to the yield vault
    function _accrueYield() internal virtual override prankception(_ewstEthWhale) {
        IERC20(_ewstEth).transfer(_yieldVault, 1e17);
    }

    /// @dev Accrues yield by sending some yield bearing tokens out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        IERC20(_ewstEth).transfer(_yieldVault, IERC20(_ewstEth).balanceOf(_yieldVault) / 2);
    }

}
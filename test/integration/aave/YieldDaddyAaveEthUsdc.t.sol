// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

import { AaveV3ERC4626, ERC20, IPool, IRewardsController } from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract YieldDaddyAaveEthUsdcIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 20033559;
    uint256 forkBlockTimestamp = 1717686251;

    address internal _asset = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address internal _assetWhale = address(0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa);
    address internal _aToken = address(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c);
    address internal _aTokenWhale = address(0xA91661efEe567b353D55948C0f051C1A16E503A5);

    address internal _aavePool = address(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    address internal _aaveRewards = address(0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb);

    address internal _yieldVault;

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 6, 1e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        AaveV3ERC4626 wrappedVault = new AaveV3ERC4626(
            ERC20(_asset),
            ERC20(_aToken),
            IPool(_aavePool),
            address(this),
            IRewardsController(_aaveRewards)
        );
        _yieldVault = address(wrappedVault);
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("mainnet"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 3 gwei;
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

    /// @dev Accrues yield by sending aTokens to the yield vault as well as letting some time pass
    function _accrueYield() internal virtual override prankception(_aTokenWhale) {
        IERC20(_aToken).transfer(_yieldVault, 10 ** assetDecimals);
        vm.warp(block.timestamp + 1 days);
    }

    /// @dev Simulates loss by transferring some liquid aTokens out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        IERC20(_aToken).transfer(_aTokenWhale, IERC20(_aToken).balanceOf(_yieldVault) / 2); // transfer aTokens out of the yield vault
    }

}
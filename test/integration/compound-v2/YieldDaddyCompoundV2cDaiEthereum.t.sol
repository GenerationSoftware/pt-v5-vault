// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract YieldDaddyCompoundV2cDaiEthereumIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 19311723;
    uint256 forkBlockTimestamp = 1708950275;

    address internal _asset = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address internal _assetWhale = address(0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8);
    address internal _yieldVault = address(0x6D088fe2500Da41D7fA7ab39c76a506D7c91f53b);
    address internal _cDai = address(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    address internal _cDaiWhale = address(0x4bbC507Ca4417625E20199644523f4D92df927b1);

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

    /// @dev Accrues yield by sending cDai to the yield vault
    function _accrueYield() internal virtual override prankception(_cDaiWhale) {
        IERC20(_cDai).transfer(_yieldVault, 100e18);
    }

    /// @dev Simulates loss by transferring some cDai tokens out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        IERC20(_cDai).transfer(_cDaiWhale, IERC20(_cDai).balanceOf(_yieldVault) / 2);
    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC4626Test, IMockERC20 } from "erc4626-tests/ERC4626.test.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { LendingVault } from "../../src/LendingVault.sol";

import { IERC4626, IERC20 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { Strings } from "openzeppelin/utils/Strings.sol";

import { YieldVault } from "../contracts/mock/YieldVault.sol";
import { PrizePoolMock } from "../contracts/mock/PrizePoolMock.sol";

contract LendingVaultERC4626FuzzTest is ERC4626Test {

    TwabController public twabController;
    PrizePoolMock public prizePool;
    ERC20Mock public prizeToken;

    IERC4626 public yieldVault;

    function setUp() public override {
        _underlying_ = address(new ERC20Mock());

        twabController = new TwabController(1 days, uint32(block.timestamp));
        prizeToken = new ERC20Mock();
        prizePool = new PrizePoolMock(prizeToken, twabController);
        yieldVault = new YieldVault(
            _underlying_,
            "Mock Yield Vault",
            "MYV"
        );

        _vault_ = address(
            new LendingVault(
                "PoolTogether Test Vault",
                "pTest",
                yieldVault,
                PrizePool(address(prizePool)),
                address(this),
                address(this),
                0,
                address(this)
            )
        );

        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = true;
    }

    /* ============ Override setup ============ */

    function setUpVault(Init memory init) public virtual override {
        for (uint256 i = 0; i < N; i++) {
        init.user[i] = makeAddr(Strings.toString(i));
        address user = init.user[i];

        vm.assume(_isEOA(user));

        uint256 shares = bound(init.share[i], 0, type(uint96).max);
        try IMockERC20(_underlying_).mint(user, shares) {} catch {
            vm.assume(false);
        }

        _approve(_underlying_, user, _vault_, shares);

        vm.prank(user);
        try IERC4626(_vault_).deposit(shares, user) {} catch {
            vm.assume(false);
        }

        uint256 assets = bound(init.asset[i], 0, type(uint96).max);
        try IMockERC20(_underlying_).mint(user, assets) {} catch {
            vm.assume(false);
        }
        }

        setUpYield(init);
    }

    // Mint yield to the YieldVault
    function setUpYield(Init memory init) public virtual override {
        if (init.yield >= 0) {
            // gain
            uint256 gain = uint256(init.yield);
            try IMockERC20(_underlying_).mint(address(yieldVault), gain) {} catch {
                vm.assume(false);
            }
        } else {
            // loss
            vm.assume(init.yield > type(int256).min); // avoid overflow in conversion
            uint256 loss = uint256(-1 * init.yield);
            try IMockERC20(_underlying_).burn(address(yieldVault), loss) {} catch {
                vm.assume(false);
            }
        }
    }

    function _max_deposit(address from) internal virtual override returns (uint256) {
        if (_unlimitedAmount) return type(uint96).max;
        return uint96(IERC20(_underlying_).balanceOf(from));
    }

    function _max_mint(address from) internal virtual override returns (uint256) {
        if (_unlimitedAmount) return type(uint96).max;
        return uint96(vault_convertToShares(IERC20(_underlying_).balanceOf(from)));
    }

    function _max_withdraw(address from) internal virtual override returns (uint256) {
        if (_unlimitedAmount) return type(uint96).max;
        return uint96(vault_convertToAssets(IERC20(_vault_).balanceOf(from)));
    }

    function _max_redeem(address from) internal virtual override returns (uint256) {
        if (_unlimitedAmount) return type(uint96).max;
        return uint96(IERC20(_vault_).balanceOf(from));
    }
}
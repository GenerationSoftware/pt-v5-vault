// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { IERC20Permit } from "openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import { Math } from "openzeppelin/utils/math/Math.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";

import { IERC4626, Vault } from "../../src/Vault.sol";

import { LiquidationPairMock } from "../contracts/mock/LiquidationPairMock.sol";
import { LiquidationRouterMock } from "../contracts/mock/LiquidationRouterMock.sol";
import { PrizePoolMock } from "../contracts/mock/PrizePoolMock.sol";
import { YieldVault } from "../contracts/mock/YieldVault.sol";

contract Helpers is Test {
  using Math for uint256;

  /* ============ Variables ============ */
  bytes32 private constant _PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  uint256 public constant FEE_PRECISION = 1e9;

  uint256 public constant YIELD_FEE_PERCENTAGE = 100000000; // 0.1 = 10%

  /**
   * For a token with 2 decimal places like gUSD, this is the minimum fee percentage that can be taken for a 2 figure yield.
   * This is because Solidity will truncate down the result to 0 since it won't fit in 2 decimal places.
   * i.e. 10 * 0.01% = 10 * 0.0001 = 1000 * 100000 / 1e9 = 0
   */
  uint256 public constant LOW_YIELD_FEE_PERCENTAGE = 1000000; // 0.001 = 0.1%

  /* ============ Deposit ============ */
  function _deposit(
    IERC20 _underlyingAsset,
    Vault _vault,
    uint256 _assets,
    address _user
  ) internal returns (uint256) {
    _underlyingAsset.approve(address(_vault), type(uint256).max);
    return _vault.deposit(_assets, _user);
  }

  function _depositWithPermit(
    IERC20Permit _underlyingAsset,
    Vault _vault,
    uint256 _assets,
    address _user,
    address _owner,
    uint256 _ownerPrivateKey
  ) internal returns (uint256) {
    uint256 _nonce = _underlyingAsset.nonces(_owner);

    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(
      _ownerPrivateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          _underlyingAsset.DOMAIN_SEPARATOR(),
          keccak256(
            abi.encode(_PERMIT_TYPEHASH, _owner, address(_vault), _assets, _nonce, block.timestamp)
          )
        )
      )
    );

    return _vault.depositWithPermit(_assets, _user, block.timestamp, _v, _r, _s);
  }

  /* ============ Mint ============ */
  function _mint(
    IERC20 _underlyingAsset,
    Vault _vault,
    uint256 _shares,
    address _user
  ) internal returns (uint256) {
    _underlyingAsset.approve(address(_vault), type(uint256).max);
    return _vault.mint(_shares, _user);
  }

  /* ============ Sponsor ============ */
  function _sponsor(
    IERC20 _underlyingAsset,
    Vault _vault,
    uint256 _assets
  ) internal returns (uint256) {
    _underlyingAsset.approve(address(_vault), type(uint256).max);
    return _vault.sponsor(_assets);
  }

  function _sponsorWithPermit(
    IERC20Permit _underlyingAsset,
    Vault _vault,
    uint256 _assets,
    address _owner,
    uint256 _ownerPrivateKey
  ) internal returns (uint256) {
    uint256 _nonce = _underlyingAsset.nonces(_owner);

    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(
      _ownerPrivateKey,
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          _underlyingAsset.DOMAIN_SEPARATOR(),
          keccak256(
            abi.encode(_PERMIT_TYPEHASH, _owner, address(_vault), _assets, _nonce, block.timestamp)
          )
        )
      )
    );

    return _vault.sponsorWithPermit(_assets, block.timestamp, _v, _r, _s);
  }

  /* ============ Undercollateralization ============ */
  function _getMaxWithdraw(
    address _user,
    Vault _vault,
    YieldVault _yieldVault
  ) internal view returns (uint256) {
    return
      _vault.maxRedeem(_user).mulDiv(
        _yieldVault.maxWithdraw(address(_vault)),
        _vault.totalSupply(),
        Math.Rounding.Down
      );
  }

  /* ============ Liquidate ============ */
  function _accrueYield(ERC20Mock _underlyingAsset, IERC4626 _yieldVault, uint256 _yield) internal {
    _underlyingAsset.mint(address(_yieldVault), _yield);
  }

  function _liquidate(
    LiquidationRouterMock _liquidationRouter,
    LiquidationPairMock _liquidationPair,
    IERC20 _prizeToken,
    uint256 _yield,
    address _user
  ) internal returns (uint256 userPrizeTokenBalanceBeforeSwap, uint256 prizeTokenContributed) {
    prizeTokenContributed = _liquidationPair.computeExactAmountIn(_yield);
    userPrizeTokenBalanceBeforeSwap = _prizeToken.balanceOf(_user);

    _prizeToken.approve(address(_liquidationRouter), prizeTokenContributed);
    _liquidationRouter.swapExactAmountOut(_liquidationPair, _user, _yield, prizeTokenContributed);
  }

  function _getYieldFeeShares(
    uint256 _amount,
    uint256 _feePercentage
  ) internal pure returns (uint256) {
    return (_amount * FEE_PRECISION) / (FEE_PRECISION - _feePercentage) - _amount;
  }

  function _getAvailableYieldBalance(
    uint256 _yield,
    uint256 _liquidatedYield,
    uint256 _yieldFeeShares
  ) internal pure returns (uint256) {
    return _yield - (_liquidatedYield + _yieldFeeShares);
  }

  function _getAvailableYieldFeeBalance(
    uint256 _availableYield,
    uint256 _feePercentage
  ) internal pure returns (uint256) {
    return (_availableYield * _feePercentage) / FEE_PRECISION;
  }

  function _getLiquidatableBalanceOf(
    uint256 _availableYield,
    uint256 _feePercentage
  ) internal pure returns (uint256) {
    return _availableYield -= (_availableYield * _feePercentage) / FEE_PRECISION;
  }

  /* ============ Claim ============ */
  function _claim(
    address _claimer,
    Vault _vault,
    PrizePool _prizePool,
    address _user,
    uint8[] memory _tiers
  ) internal returns (uint256) {
    // Claim[] memory claims = new Claim[](1);
    // claims[0] = Claim({ vault: IVault(address(_vault)), winner: _user, tier: _tiers[0] });
    // uint32 _drawPeriodSeconds = _prizePool.drawPeriodSeconds();
    // vm.warp(
    //   _drawPeriodSeconds /
    //     _prizePool.estimatedPrizeCount() +
    //     _prizePool.lastCompletedDrawStartedAt() +
    //     _drawPeriodSeconds +
    //     10
    // );
    // vm.startPrank(_claimer);
    // _vault.claimPrizes(
    // )
    // (, uint256 _totalFees) = _claimer.claimPrizes(0, claims, address(this));
    // uint8 _tier,
    // address[] calldata _winners,
    // uint32[][] calldata _prizeIndices,
    // uint96 _feePerClaim,
    // address _claimFeeRecipient
    // return _totalFees;
  }
}

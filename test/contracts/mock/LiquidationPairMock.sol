// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { ILiquidationSource } from "pt-v5-liquidator-interfaces/ILiquidationSource.sol";
import { MockLiquidatorLib } from "./MockLiquidatorLib.sol";

contract LiquidationPairMock {
  address internal _source;
  address internal _target;
  address internal _tokenIn;
  address internal _tokenOut;
  MockLiquidatorLib internal _liquidatorLib;

  constructor(address source_, address target_, address tokenIn_, address tokenOut_) {
    _source = source_;
    _target = target_;
    _tokenIn = tokenIn_;
    _tokenOut = tokenOut_;
    _liquidatorLib = new MockLiquidatorLib();
  }

  function _availableReserveOut() internal returns (uint256) {
    return ILiquidationSource(_source).liquidatableBalanceOf(_tokenOut);
  }

  function transferTokensOut(
    address _sender,
    address _receiver,
    address _tokenOut,
    uint256 _amountOut
  ) public virtual {
    ERC20Mock(_tokenOut).transfer(_receiver, _amountOut);
  }

  function verifyTokensIn(
    address,
    address,
    address _tokenIn,
    uint256 _amountIn
  ) public virtual {
  }

  function computeExactAmountIn(uint256 _amountOut) external returns (uint256) {
    return _liquidatorLib.computeExactAmountIn(100, 50, _availableReserveOut(), _amountOut);
  }

  function swapExactAmountOut(
    address _account,
    uint256 _amountOut,
    uint256 _amountInMax
  ) external returns (uint256) {
    ILiquidationSource(_source).transferTokensOut(_account, _account, _tokenOut, _amountOut);

    return _amountInMax;
  }

  function target() external view returns (address) {
    return _target;
  }

  function tokenIn() external view returns (address) {
    return _tokenIn;
  }
}

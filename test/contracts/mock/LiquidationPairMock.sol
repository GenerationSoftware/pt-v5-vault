// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { ILiquidationSource } from "pt-v5-liquidator-interfaces/ILiquidationSource.sol";
import { MockLiquidatorLib } from "./MockLiquidatorLib.sol";

contract LiquidationPairMock {
    address public immutable source;
    address public immutable target;
    address public immutable tokenIn;
    address public immutable tokenOut;
    MockLiquidatorLib internal _liquidatorLib;

    constructor(address source_, address target_, address tokenIn_, address tokenOut_) {
        source = source_;
        target = target_;
        tokenIn = tokenIn_;
        tokenOut = tokenOut_;
        _liquidatorLib = new MockLiquidatorLib();
    }

    function _availableReserveOut() internal returns (uint256) {
        return ILiquidationSource(source).liquidatableBalanceOf(tokenOut);
    }

    function transferTokensOut(
        address,
        address _receiver,
        address _tokenOut,
        uint256 _amountOut
    ) public virtual {
        ERC20Mock(_tokenOut).transfer(_receiver, _amountOut);
    }

    function verifyTokensIn(address, address, address _tokenIn, uint256 _amountIn) public virtual {}

    function computeExactAmountIn(uint256 _amountOut) external returns (uint256) {
        return _liquidatorLib.computeExactAmountIn(100, 50, _availableReserveOut(), _amountOut);
    }

    function swapExactAmountOut(
        address _account,
        uint256 _amountOut,
        uint256 _amountInMax
    ) external returns (uint256) {
        ILiquidationSource(source).transferTokensOut(_account, _account, tokenOut, _amountOut);

        return _amountInMax;
    }

}

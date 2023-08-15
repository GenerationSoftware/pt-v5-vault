// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

type UFixed32x4 is uint32;

/**
 * @title FixedMathLib
 * @author PoolTogether Inc. Team
 * @notice A minimal library to do fixed point operations with 4 decimals of precision.
 */
library FixedMathLib {
  uint256 constant multiplier = 1e4;

  /**
   * @notice Multiply a uint256 by a UFixed32x4.
   * @param a The uint256 to multiply.
   * @param b The UFixed32x4 to multiply.
   * @return The product of a and b.
   */
  function mul(uint256 a, UFixed32x4 b) internal pure returns (uint256) {
    require(a <= type(uint224).max, "FixedMathLib/a-less-than-224-bits");
    return (a * UFixed32x4.unwrap(b)) / multiplier;
  }

  /**
   * @notice Divide a uint256 by a UFixed32x4.
   * @param a The uint256 to divide.
   * @param b The UFixed32x4 to divide.
   * @return The quotient of a and b.
   */
  function div(uint256 a, UFixed32x4 b) internal pure returns (uint256) {
    require(UFixed32x4.unwrap(b) > 0, "FixedMathLib/b-greater-than-zero");
    require(a <= type(uint224).max, "FixedMathLib/a-less-than-224-bits");
    return (a * multiplier) / UFixed32x4.unwrap(b);
  }
}

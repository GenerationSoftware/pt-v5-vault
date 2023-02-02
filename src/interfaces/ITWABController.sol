// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

interface ITWABController {
  struct AccountDetails {
    uint112 balance;
    uint112 delegateBalance;
    uint16 nextTwabIndex;
    uint16 cardinality;
  }

  function getAccountDetails(
    address vault,
    address user
  ) external view returns (AccountDetails memory);

  function balanceOf(address vault, address user) external view returns (uint256);

  function delegateBalanceOf(address vault, address user) external returns (uint256);

  function totalSupply(address vault) external view returns (uint256);

  function twabTransfer(address vault, address from, address to, uint256 amount) external;
}

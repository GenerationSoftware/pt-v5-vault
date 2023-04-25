// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IERC20, IERC4626, Claimer, PrizePool, TwabController, Vault } from "src/Vault.sol";

contract VaultMock is Vault {
  constructor(
    IERC20 _asset,
    string memory _name,
    string memory _symbol,
    TwabController twabController_,
    IERC4626 yieldVault_,
    PrizePool prizePool_,
    Claimer claimer_,
    address yieldFeeRecipient_,
    uint256 yieldFeePercentage_,
    address _owner
  )
    Vault(
      _asset,
      _name,
      _symbol,
      twabController_,
      yieldVault_,
      prizePool_,
      claimer_,
      yieldFeeRecipient_,
      yieldFeePercentage_,
      _owner
    )
  {}

  function totalShares() public view returns (uint256) {
    return _totalShares();
  }
}

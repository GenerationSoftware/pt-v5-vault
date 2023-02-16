// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { LiquidationPair } from "v5-liquidator/src/LiquidationPair.sol";
import { PrizePool } from "v5-prize-pool/src/PrizePool.sol";
import { TwabController } from "v5-twab-controller/TwabController.sol";

import { Vault } from "./Vault.sol";

contract VaultFactory {
    /* ============ Events ============ */

  /**
   * @notice Emitted when a new Vault has been deployed by this factory.
   * @param vaultFactory Address of the VaultFactory that deployed `vault`
   * @param vault Address of the vault that was deployed
   */
  event NewFactoryVault(
    Vault indexed vault,
    VaultFactory indexed vaultFactory
  );

  /* ============ Variables ============ */

  /// @notice List of all vaults deployed by this factory.
  Vault[] public allVaults;

  /**
   * @notice Mapping to verify if a Vault has been deployed via this factory.
   * @dev Vault address => boolean
   */
  mapping(Vault => bool) public deployedVaults;

  /* ============ External Functions ============ */

  /**
   * @notice Deploy a new vault
   * @dev `claimer` can be set to address zero if none is available yet.
   * @param _asset Address of the underlying asset used by the vault
   * @param _name Name of the ERC20 share minted by the vault
   * @param _symbol Symbol of the ERC20 share minted by the vault
   * @param _twabController Address of the TwabController used to keep track of balances
   * @param _yieldVault Address of the ERC4626 vault in which assets are deposited to generate yield
   * @param _liquidationPair Address of the LiquidationPair used to liquidate yield for prize token
   * @param _prizePool Address of the PrizePool that computes prizes
   * @param _claimer Address of the claimer
   * @param _owner Address that will gain ownership of this contract
   */
  function deployVault(
    IERC20 _asset,
    string memory _name,
    string memory _symbol,
    TwabController _twabController,
    IERC4626 _yieldVault,
    LiquidationPair _liquidationPair,
    PrizePool _prizePool,
    address _claimer,
    address _owner
  ) external {
    Vault _vault = new Vault(
      _asset,
      _name,
      _symbol,
      _twabController,
      _yieldVault,
      _liquidationPair,
      _prizePool,
      _claimer,
      _owner
    );

    allVaults.push(_vault);
    deployedVaults[_vault] = true;

    emit NewFactoryVault(_vault, VaultFactory(address(this)));
  }

  /**
   * @notice Total number of vaults deployed by this factory.
   * @return Number of vaults deployed by this factory.
  */
  function totalVaults() external view returns (uint256) {
      return allVaults.length;
  }
}

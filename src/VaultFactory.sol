// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Create2 } from "openzeppelin/utils/Create2.sol";
import { IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { ILiquidationPair } from "pt-v5-liquidator-interfaces/ILiquidationPair.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { Vault } from "./Vault.sol";

/**
 * @title  PoolTogether V5 Vault Factory
 * @author PoolTogether Inc Team, Generation Software Team
 * @notice Factory contract for deploying new vaults using a standard underlying ERC4626 yield vault.
 */
contract VaultFactory {
  /* ============ Events ============ */

  /**
   * @notice Emitted when a new Vault has been deployed by this factory.
   * @param vault Address of the vault that was deployed
   * @param vaultFactory Address of the VaultFactory that deployed `vault`
   */
  event NewFactoryVault(Vault indexed vault, VaultFactory indexed vaultFactory);

  /* ============ Variables ============ */

  /// @notice List of all vaults deployed by this factory.
  Vault[] public allVaults;

  /**
   * @notice Mapping to verify if a Vault has been deployed via this factory.
   * @dev Vault address => boolean
   */
  mapping(Vault => bool) public deployedVaults;

  /**
   * @notice Mapping to store deployer nonces for CREATE2
   */
  mapping(address => uint) public deployerNonces;

  /* ============ External Functions ============ */

  /**
   * @notice Deploy a new vault
   * @dev `claimer` can be set to address zero if none is available yet.
   * @param _asset Address of the underlying asset used by the vault
   * @param _name Name of the ERC20 share minted by the vault
   * @param _symbol Symbol of the ERC20 share minted by the vault
   * @param _twabController Address of the TwabController used to keep track of balances
   * @param _yieldVault Address of the ERC4626 vault in which assets are deposited to generate yield
   * @param _prizePool Address of the PrizePool that computes prizes
   * @param _claimer Address of the claimer
   * @param _yieldFeeRecipient Address of the yield fee recipient
   * @param _yieldFeePercentage Yield fee percentage
   * @param _owner Address that will gain ownership of this contract
   * @return address Address of the newly deployed Vault
   */
  function deployVault(
    IERC20 _asset,
    string memory _name,
    string memory _symbol,
    TwabController _twabController,
    IERC4626 _yieldVault,
    PrizePool _prizePool,
    address _claimer,
    address _yieldFeeRecipient,
    uint256 _yieldFeePercentage,
    address _owner
  ) external returns (address) {
    bytes memory bytecode = abi.encodePacked(
      type(Vault).creationCode,
      abi.encode(
        _asset,
        _name,
        _symbol,
        _twabController,
        _yieldVault,
        _prizePool,
        _claimer,
        _yieldFeeRecipient,
        _yieldFeePercentage,
        _owner
      )
    );

    Vault _vault = Vault(Create2.deploy(
      0,
      keccak256(abi.encode(msg.sender, deployerNonces[msg.sender]++)),
      bytecode
    ));

    allVaults.push(_vault);
    deployedVaults[_vault] = true;

    emit NewFactoryVault(_vault, VaultFactory(address(this)));

    return address(_vault);
  }

  /**
   * @notice Total number of vaults deployed by this factory.
   * @return uint256 Number of vaults deployed by this factory.
   */
  function totalVaults() external view returns (uint256) {
    return allVaults.length;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";

import { VaultV2 as Vault } from "./Vault.sol";

/**
 * @title  PoolTogether V5 Vault Factory (Version 2)
 * @author PoolTogether Inc. & G9 Software Inc.
 * @notice Factory contract for deploying new vaults using a standard underlying ERC4626 yield vault.
 */
contract VaultFactoryV2 {
  /* ============ Events ============ */

  /**
   * @notice Emitted when a new Vault has been deployed by this factory.
   * @param vault Address of the vault that was deployed
   * @param vaultFactory Address of the VaultFactory that deployed `vault`
   */
  event NewFactoryVault(Vault indexed vault, VaultFactoryV2 indexed vaultFactory);

  /* ============ Variables ============ */

  /// @notice List of all vaults deployed by this factory.
  Vault[] public allVaults;

  /**
   * @notice Mapping to verify if a Vault has been deployed via this factory.
   * @dev Vault address => boolean
   */
  mapping(address => bool) public deployedVaults;

  /**
   * @notice Mapping to store deployer nonces for CREATE2
   */
  mapping(address => uint256) public deployerNonces;

  /* ============ External Functions ============ */

  /**
   * @notice Deploy a new vault
   * @dev `claimer` can be set to address zero if none is available yet.
   * @param _asset Address of the underlying asset used by the vault
   * @param _name Name of the ERC20 share minted by the vault
   * @param _symbol Symbol of the ERC20 share minted by the vault
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
    IERC4626 _yieldVault,
    PrizePool _prizePool,
    address _claimer,
    address _yieldFeeRecipient,
    uint32 _yieldFeePercentage,
    address _owner
  ) external returns (address) {
    Vault _vault = new Vault{
      salt: keccak256(abi.encode(msg.sender, deployerNonces[msg.sender]++))
    }(
      _asset,
      _name,
      _symbol,
      _yieldVault,
      _prizePool,
      _claimer,
      _yieldFeeRecipient,
      _yieldFeePercentage,
      _owner
    );

    allVaults.push(_vault);
    deployedVaults[address(_vault)] = true;

    emit NewFactoryVault(_vault, VaultFactoryV2(address(this)));

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

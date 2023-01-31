// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC4626, ERC20, IERC20 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { IYieldVault } from "./interfaces/IYieldVault.sol";

contract PrizeVault is ERC4626 {
  /* ============ Events ============ */

  /**
   * @notice Emitted when a new YieldVault has been deployed
   * @param asset Address of the underlying asset used by the vault
   * @param name Name of the ERC20 share minted by the vault
   * @param symbol Symbol of the ERC20 share minted by the vault
   * @param yieldVault Address of the ERC4626 vault in which assets are deposited to generate yield
   */
  event NewYieldVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    IYieldVault indexed yieldVault
  );

  /* ============ Variables ============ */

  /// @notice Address of the ERC4626 vault generating yield
  IYieldVault public yieldVault;

  /**
   * @notice PrizeVault constructor
   * @param _asset Address of the underlying asset used by the vault
   * @param _name Name of the ERC20 share minted by the vault
   * @param _symbol Symbol of the ERC20 share minted by the vault
   * @param _yieldVault Address of the ERC4626 vault in which assets are deposited to generate yield
   */
  constructor(
    IERC20 _asset,
    string memory _name,
    string memory _symbol,
    IYieldVault _yieldVault
  ) ERC4626(_asset) ERC20(_name, _symbol) {
    require(address(_asset) != address(0), "PV/asset-not-zero-address");
    require(address(_yieldVault) != address(0), "PV/yieldVault-not-zero-address");

    yieldVault = _yieldVault;

    emit NewYieldVault(_asset, _name, _symbol, _yieldVault);
  }
}

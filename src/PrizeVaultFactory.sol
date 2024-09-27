// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";

import { PrizeVault } from "./PrizeVault.sol";

/// @title  PoolTogether V5 Prize Vault Factory
/// @author PoolTogether Inc. & G9 Software Inc.
/// @notice Factory contract for deploying new prize vaults using a standard underlying ERC4626 yield vault.
contract PrizeVaultFactory {
    using SafeERC20 for IERC20;

    ////////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when a new PrizeVault has been deployed by this factory.
    /// @param vault The vault that was deployed
    /// @param yieldVault The underlying yield vault
    /// @param prizePool The prize pool the vault contributes to
    /// @param name The name of the vault token
    /// @param symbol The symbol for the vault token
    event NewPrizeVault(
        PrizeVault indexed vault,
        IERC4626 indexed yieldVault,
        PrizePool indexed prizePool,
        string name,
        string symbol
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Variables
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice List of all vaults deployed by this factory.
    PrizeVault[] public allVaults;

    /// @notice Mapping to verify if a Vault has been deployed via this factory.
    mapping(address vault => bool deployedByFactory) public deployedVaults;

    /// @notice Mapping to store deployer nonces for CREATE2
    mapping(address deployer => uint256 nonce) public deployerNonces;

    ////////////////////////////////////////////////////////////////////////////////
    // External Functions
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy a new vault
    /// @dev Emits a `NewPrizeVault` event with the vault details.
    /// @dev The caller MUST approve this factory to spend underlying assets equal to `YIELD_BUFFER` so the yield
    /// buffer can be filled on deployment. This value is unrecoverable and is expected to be insignificant.
    /// @dev The yield buffer is expected to be of insignificant value and is used to cover rounding
    /// errors on deposits and withdrawals. Yield is expected to accrue faster than the yield buffer
    /// can be reasonably depleted.
    ///
    /// The yield buffer should be set as high as possible while still being considered
    /// insignificant for the lowest precision per dollar asset that is expected to be supported.
    /// 
    /// Precision per dollar (PPD) can be calculated by: (10 ^ DECIMALS) / ($ value of 1 asset).
    /// For example, USDC has a PPD of (10 ^ 6) / ($1) = 10e6 p/$.
    /// 
    /// As a rule of thumb, assets with lower PPD than USDC should not be assumed to be compatible since
    /// the potential loss of a single unit rounding error is likely too high to be made up by yield at 
    /// a reasonable rate. Actual results may vary based on expected gas costs, asset fluctuation, and
    /// yield accrual rates.
    ///
    /// This factory will transfer an amount of assets equal to the yield buffer from the deployer to the
    /// prize vault on deployment to cover the initial buffer. For example, if you are deploying a USDC
    /// vault and the yield buffer is set to 1e5, you will have to approve this factory to spend 1e5
    /// USDC ($0.10) to be sent to the prize vault during deployment. Assuming there is no additional 
    /// precision loss in the yield vault, a 1e5 yield buffer will cover the first 100k rounding errors on
    /// deposits and withdraws and is not recoverable by the deployer.
    ///
    /// If the yield buffer is depleted on a vault, the vault will prevent any further 
    /// deposits if it would result in a rounding error and any rounding errors incurred by withdrawals
    /// will not be covered by yield. The yield buffer will be replenished automatically as yield accrues
    /// on deposits.
    /// @param _name Name of the ERC20 share minted by the vault
    /// @param _symbol Symbol of the ERC20 share minted by the vault
    /// @param _yieldVault Address of the ERC4626 vault in which assets are deposited to generate yield
    /// @param _prizePool Address of the PrizePool that computes prizes
    /// @param _claimer Address of the claimer
    /// @param _yieldFeeRecipient Address of the yield fee recipient
    /// @param _yieldFeePercentage Yield fee percentage
    /// @param _yieldBuffer The size of the prize vault yield buffer
    /// @param _owner Address that will gain ownership of this contract
    /// @return PrizeVault The newly deployed PrizeVault
    function deployVault(
      string memory _name,
      string memory _symbol,
      IERC4626 _yieldVault,
      PrizePool _prizePool,
      address _claimer,
      address _yieldFeeRecipient,
      uint32 _yieldFeePercentage,
      uint256 _yieldBuffer,
      address _owner,
      address _extension
    ) external returns (PrizeVault) {
        PrizeVault _vault = new PrizeVault{
            salt: keccak256(abi.encode(msg.sender, deployerNonces[msg.sender]++))
        }(
            _name,
            _symbol,
            _yieldVault,
            _prizePool,
            _claimer,
            _yieldFeeRecipient,
            _yieldFeePercentage,
            _yieldBuffer,
            _owner,
            _extension
        );

        // A donation to fill the yield buffer is made to ensure that early depositors have
        // rounding errors covered in the time before yield is actually generated.
        if (_yieldBuffer > 0) {
            IERC20(_vault.asset()).safeTransferFrom(msg.sender, address(_vault), _yieldBuffer);
        }

        allVaults.push(_vault);
        deployedVaults[address(_vault)] = true;

        emit NewPrizeVault(
            _vault,
            _yieldVault,
            _prizePool,
            _name,
            _symbol
        );

        return _vault;
    }

    /// @notice Total number of vaults deployed by this factory.
    /// @return uint256 Number of vaults deployed by this factory.
    function totalVaults() external view returns (uint256) {
        return allVaults.length;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20, IERC20, IERC20Metadata } from "openzeppelin/token/ERC20/ERC20.sol";
import { IERC4626 } from "openzeppelin/interfaces/IERC4626.sol";
import { ERC20Permit, IERC20Permit } from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "openzeppelin/utils/math/SafeCast.sol";
import { Math } from "openzeppelin/utils/math/Math.sol";
import { Ownable } from "owner-manager-contracts/Ownable.sol";

import { ILiquidationPair } from "pt-v5-liquidator-interfaces/ILiquidationPair.sol";
import { ILiquidationSource } from "pt-v5-liquidator-interfaces/ILiquidationSource.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController, SPONSORSHIP_ADDRESS } from "pt-v5-twab-controller/TwabController.sol";
import { VaultHooks } from "./interfaces/IVaultHooks.sol";

/// @notice Emitted when the TWAB controller is set to the zero address.
error TwabControllerZeroAddress();

/// @notice Emitted when the Yield Vault is set to the zero address.
error YieldVaultZeroAddress();

/// @notice Emitted when the Prize Pool is set to the zero address.
error PrizePoolZeroAddress();

/// @notice Emitted when the Owner is set to the zero address.
error OwnerZeroAddress();

/**
 * @notice Emitted when the underlying asset passed to the constructor is different from the YieldVault one.
 * @param asset Address of the underlying asset passed to the constructor
 * @param yieldVaultAsset Address of the YieldVault underlying asset
 */
error UnderlyingAssetMismatch(address asset, address yieldVaultAsset);

/**
 * @notice Emitted when the amount being deposited for the receiver is greater than the max amount allowed.
 * @param receiver The receiver of the deposit
 * @param amount The amount to deposit
 * @param max The max deposit amount allowed
 */
error DepositMoreThanMax(address receiver, uint256 amount, uint256 max);

/**
 * @notice Emitted when the amount being withdrawn for the owner is greater than the max amount allowed.
 * @param owner The owner of the assets
 * @param amount The amount to withdraw
 * @param max The max withdrawable amount
 */
error WithdrawMoreThanMax(address owner, uint256 amount, uint256 max);

/**
 * @notice Emitted when the amount being redeemed for owner is greater than the max allowed amount.
 * @param owner The owner of the assets
 * @param amount The amount to redeem
 * @param max The max redeemable amount
 */
error RedeemMoreThanMax(address owner, uint256 amount, uint256 max);

/**
 * @notice Emitted when the amount of shares being minted to the receiver is greater than the max amount allowed.
 * @param receiver The receiver address
 * @param shares The shares being minted
 * @param max The max amount of shares that can be minted to the receiver
 */
error MintMoreThanMax(address receiver, uint256 shares, uint256 max);

/// @notice Emitted when `_deposit` is called but no shares are minted back to the receiver.
error MintZeroShares();

/// @notice Emitted when `_withdraw` is called but no assets are being withdrawn.
error WithdrawZeroAssets();

/**
 * @notice Emitted when `_withdraw` is called but the amount of assets withdrawn from the YieldVault
 *         is lower than the amount of assets requested by the caller.
 * @param requestedAssets The amount of assets requested
 * @param withdrawnAssets The amount of assets withdrawn from the YieldVault
 */
error WithdrawAssetsLTRequested(uint256 requestedAssets, uint256 withdrawnAssets);

/// @notice Emitted when `sweep` is called but no underlying assets are currently held by the Vault.
error SweepZeroAssets();

/**
 * @notice Emitted during the liquidation process when the caller is not the liquidation pair contract.
 * @param caller The caller address
 * @param liquidationPair The LP address
 */
error CallerNotLP(address caller, address liquidationPair);

/**
 * @notice Emitted during the liquidation process when the token in is not the prize token.
 * @param tokenIn The provided tokenIn address
 * @param prizeToken The prize token address
 */
error LiquidationTokenInNotPrizeToken(address tokenIn, address prizeToken);

/**
 * @notice Emitted during the liquidation process when the token out is not the vault share token.
 * @param tokenOut The provided tokenOut address
 * @param vaultShare The vault share token address
 */
error LiquidationTokenOutNotVaultShare(address tokenOut, address vaultShare);

/// @notice Emitted during the liquidation process when the liquidation amount out is zero.
error LiquidationAmountOutZero();

/**
 * @notice Emitted during the liquidation process if the amount out is greater than the available yield.
 * @param amountOut The amount out
 * @param availableYield The available yield
 */
error LiquidationAmountOutGTYield(uint256 amountOut, uint256 availableYield);

/**
 * @notice Emitted during the liquidation process if the amount out is greater than the maximum amount of Vault shares mintable.
 * @param amountOut The amount out
 * @param vaultMaxMint The maxmimum amount of Vault shares mintable
 */
error LiquidationAmountOutGTVaultMaxMint(uint256 amountOut, uint256 vaultMaxMint);

/// @notice Emitted when the Vault is under-collateralized.
error VaultUnderCollateralized();

/**
 * @notice Emitted when after a deposit the amount of withdrawable assets from the YieldVault is lower than the expected amount.
 * @param withdrawableAssets The actual amount of assets withdrawable from the YieldVault
 * @param expectedWithdrawableAssets The expected amount of assets withdrawable from the YieldVault
 */
error YVWithdrawableAssetsLTExpected(
  uint256 withdrawableAssets,
  uint256 expectedWithdrawableAssets
);

/**
 * @notice Emitted when the target token is not supported for a given token address.
 * @param token The unsupported token address
 */
error TargetTokenNotSupported(address token);

/**
 * @notice Emitted when the caller is not the prize claimer.
 * @param caller The caller address
 * @param claimer The claimer address
 */
error CallerNotClaimer(address caller, address claimer);

/**
 * @notice Emitted when the minted yield exceeds the yield fee shares available.
 * @param shares The amount of yield shares to mint
 * @param yieldFeeShares The accrued yield fee shares available
 */
error YieldFeeGTAvailableShares(uint256 shares, uint256 yieldFeeShares);

/**
 * @notice Emitted when the minted yield exceeds the amount of available yield in the YieldVault.
 * @param shares The amount of yield shares to mint
 * @param availableYield The amount of yield available
 */
error YieldFeeGTAvailableYield(uint256 shares, uint256 availableYield);

/**
 * @notice Emitted when the minted yield exceeds the maximum amount of Vault shares mintable.
 * @param shares The amount of yield shares to mint
 * @param vaultMaxMint The maxmimum amount of Vault shares mintable
 */
error YieldFeeGTVaultMaxMint(uint256 shares, uint256 vaultMaxMint);

/// @notice Emitted when the Liquidation Pair being set is the zero address.
error LPZeroAddress();

/**
 * @notice Emitted when the yield fee percentage being set is greater than or equal to 1.
 * @param yieldFeePercentage The yield fee percentage in integer format
 * @param maxYieldFeePercentage The max yield fee percentage in integer format (this value is equal to 1 in decimal format)
 */
error YieldFeePercentageGtePrecision(uint256 yieldFeePercentage, uint256 maxYieldFeePercentage);

/**
 * @notice Emitted when the BeforeClaim prize hook fails
 * @param reason The revert reason that was thrown
 */
error BeforeClaimPrizeFailed(bytes reason);

/**
 * @notice Emitted when the AfterClaim prize hook fails
 * @param reason The revert reason that was thrown
 */
error AfterClaimPrizeFailed(bytes reason);

// The maximum amount of shares that can be minted.
uint256 constant UINT112_MAX = type(uint112).max;

/**
 * @title  PoolTogether V5 Vault
 * @author PoolTogether Inc Team, Generation Software Team
 * @notice Vault extends the ERC4626 standard and is the entry point for users interacting with a V5 pool.
 *         Users deposit an underlying asset (i.e. USDC) in this contract and receive in exchange an ERC20 token
 *         representing their share of deposit in the vault.
 *         Underlying assets are then deposited in a YieldVault to generate yield.
 *         This yield is sold for prize tokens (i.e. POOL) via the Liquidator and captured by the PrizePool to be awarded to depositors.
 * @dev    Balances are stored in the TwabController contract.
 */
contract Vault is IERC4626, ERC20Permit, ILiquidationSource, Ownable {
  using Math for uint256;
  using SafeCast for uint256;
  using SafeERC20 for IERC20;

  /* ============ Events ============ */

  /**
   * @notice Emitted when a new Vault has been deployed.
   * @param asset Address of the underlying asset used by the vault
   * @param name Name of the ERC20 share minted by the vault
   * @param symbol Symbol of the ERC20 share minted by the vault
   * @param twabController Address of the TwabController used to keep track of balances
   * @param yieldVault Address of the ERC4626 vault in which assets are deposited to generate yield
   * @param prizePool Address of the PrizePool that computes prizes
   * @param claimer Address of the claimer
   * @param yieldFeeRecipient Address of the yield fee recipient
   * @param yieldFeePercentage Yield fee percentage in integer format with 1e9 precision (50% would be 5e8)
   * @param owner Address of the contract owner
   */
  event NewVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    TwabController twabController,
    IERC4626 indexed yieldVault,
    PrizePool indexed prizePool,
    address claimer,
    address yieldFeeRecipient,
    uint256 yieldFeePercentage,
    address owner
  );

  /**
   * @notice Emitted when a new claimer has been set.
   * @param previousClaimer Address of the previous claimer
   * @param newClaimer Address of the new claimer
   */
  event ClaimerSet(address indexed previousClaimer, address indexed newClaimer);

  /**
   * @notice Emitted when an account sets new hooks
   * @param account The account whose hooks are being configured
   * @param hooks The hooks being set
   */
  event SetHooks(address indexed account, VaultHooks indexed hooks);

  /**
   * @notice Emitted when a new LiquidationPair has been set.
   * @param newLiquidationPair Address of the new liquidationPair
   */
  event LiquidationPairSet(ILiquidationPair indexed newLiquidationPair);

  /**
   * @notice Emitted when yield fee is minted to the yield recipient.
   * @param caller Address that called the function
   * @param recipient Address receiving the Vault shares
   * @param shares Amount of shares minted to `recipient`
   */
  event MintYieldFee(address indexed caller, address indexed recipient, uint256 shares);

  /**
   * @notice Emitted when a new yield fee recipient has been set.
   * @param previousYieldFeeRecipient Address of the previous yield fee recipient
   * @param newYieldFeeRecipient Address of the new yield fee recipient
   */
  event YieldFeeRecipientSet(
    address indexed previousYieldFeeRecipient,
    address indexed newYieldFeeRecipient
  );

  /**
   * @notice Emitted when a new yield fee percentage has been set.
   * @param previousYieldFeePercentage Previous yield fee percentage
   * @param newYieldFeePercentage New yield fee percentage
   */
  event YieldFeePercentageSet(uint256 previousYieldFeePercentage, uint256 newYieldFeePercentage);

  /**
   * @notice Emitted when a user sponsors the Vault.
   * @param caller Address that called the function
   * @param assets Amount of assets deposited into the Vault
   * @param shares Amount of shares minted to the caller address
   */
  event Sponsor(address indexed caller, uint256 assets, uint256 shares);

  /**
   * @notice Emitted when a user sweeps assets held by the Vault into the YieldVault.
   * @param caller Address that called the function
   * @param assets Amount of assets sweeped into the YieldVault
   */
  event Sweep(address indexed caller, uint256 assets);

  /* ============ Variables ============ */

  /// @notice Address of the underlying asset used by the Vault.
  IERC20 private immutable _asset;

  /// @notice Underlying asset decimals.
  uint8 private immutable _underlyingDecimals;

  /// @notice Address of the TwabController used to keep track of balances.
  TwabController private immutable _twabController;

  /// @notice Address of the ERC4626 vault generating yield.
  IERC4626 private immutable _yieldVault;

  /// @notice Address of the PrizePool that computes prizes.
  PrizePool private immutable _prizePool;

  /// @notice Address of the claimer.
  address private _claimer;

  /// @notice Address of the ILiquidationPair used to liquidate yield for prize token.
  ILiquidationPair private _liquidationPair;

  /// @notice Yield fee percentage represented in integer format with 9 decimal places (i.e. 10000000 = 0.01 = 1%).
  uint256 private _yieldFeePercentage;

  /// @notice Address of the yield fee recipient. Receives Vault shares when `mintYieldFee` is called.
  address private _yieldFeeRecipient;

  /// @notice Total yield fee shares available. Can be minted to `_yieldFeeRecipient` by calling `mintYieldFee`.
  uint256 private _yieldFeeShares;

  /// @notice Fee precision denominated in 9 decimal places and used to calculate yield fee percentage.
  uint256 private constant FEE_PRECISION = 1e9;

  /// @notice The gas to give to each of the before and after prize claim hooks.
  /// This should be enough gas to mint an NFT if needed.
  uint256 constant HOOK_GAS = 150_000;

  /// @notice Maps user addresses to hooks that they want to execute when prizes are won.
  mapping(address => VaultHooks) internal _hooks;

  /* ============ Constructor ============ */

  /**
   * @notice Vault constructor
   * @dev `claimer_` can be set to address zero if none is available yet.
   * @param asset_ Address of the underlying asset used by the vault
   * @param name_ Name of the ERC20 share minted by the vault
   * @param symbol_ Symbol of the ERC20 share minted by the vault
   * @param twabController_ Address of the TwabController used to keep track of balances
   * @param yieldVault_ Address of the ERC4626 vault in which assets are deposited to generate yield
   * @param prizePool_ Address of the PrizePool that computes prizes
   * @param claimer_ Address of the claimer
   * @param yieldFeeRecipient_ Address of the yield fee recipient
   * @param yieldFeePercentage_ Yield fee percentage
   * @param owner_ Address that will gain ownership of this contract
   */
  constructor(
    IERC20 asset_,
    string memory name_,
    string memory symbol_,
    TwabController twabController_,
    IERC4626 yieldVault_,
    PrizePool prizePool_,
    address claimer_,
    address yieldFeeRecipient_,
    uint256 yieldFeePercentage_,
    address owner_
  ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(owner_) {
    if (address(twabController_) == address(0)) revert TwabControllerZeroAddress();
    if (address(yieldVault_) == address(0)) revert YieldVaultZeroAddress();
    if (address(prizePool_) == address(0)) revert PrizePoolZeroAddress();
    if (owner_ == address(0)) revert OwnerZeroAddress();
    if (address(asset_) != yieldVault_.asset())
      revert UnderlyingAssetMismatch(address(asset_), yieldVault_.asset());

    (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
    _underlyingDecimals = success ? assetDecimals : 18;
    _asset = asset_;

    _twabController = twabController_;
    _yieldVault = yieldVault_;
    _prizePool = prizePool_;

    _setClaimer(claimer_);
    _setYieldFeeRecipient(yieldFeeRecipient_);
    _setYieldFeePercentage(yieldFeePercentage_);

    // Approve once for max amount
    asset_.safeIncreaseAllowance(address(yieldVault_), type(uint256).max);

    emit NewVault(
      asset_,
      name_,
      symbol_,
      twabController_,
      yieldVault_,
      prizePool_,
      claimer_,
      yieldFeeRecipient_,
      yieldFeePercentage_,
      owner_
    );
  }

  /**
   * @notice Fetch underlying asset decimals.
   * @dev Attempts to fetch the asset decimals. A return value of false indicates that the attempt failed in some way.
   * @param asset_ Address of the underlying asset
   */
  function _tryGetAssetDecimals(IERC20 asset_) private view returns (bool, uint8) {
    (bool success, bytes memory encodedDecimals) = address(asset_).staticcall(
      abi.encodeWithSelector(IERC20Metadata.decimals.selector)
    );
    if (success && encodedDecimals.length >= 32) {
      uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
      if (returnedDecimals <= type(uint8).max) {
        return (true, uint8(returnedDecimals));
      }
    }
    return (false, 0);
  }

  /* ===================================================== */
  /* ============ Public & External Functions ============ */
  /* ===================================================== */

  /**
   * @notice Total available yield amount accrued by this vault.
   * @dev This amount includes the liquidatable yield + yield fee amount.
   * @dev The available yield is equal to the total amount of assets managed by this Vault
   *      minus the total amount of assets supplied to the Vault and current allocated `_yieldFeeShares`.
   * @dev If `_assetsAllocated` is greater than `_withdrawableAssets`, it means that the Vault is undercollateralized.
   *      We must not mint more shares than underlying assets available so we return 0.
   * @return uint256 Total yield amount
   */
  function availableYieldBalance() public view returns (uint256) {
    uint256 _depositedAssets = _totalSupply();
    uint256 _withdrawableAssets = _totalAssets();
    uint256 _assetsAllocated = _convertToAssets(
      _depositedAssets + _yieldFeeShares,
      _depositedAssets,
      _withdrawableAssets,
      Math.Rounding.Down
    );

    return _assetsAllocated > _withdrawableAssets ? 0 : _withdrawableAssets - _assetsAllocated;
  }

  /**
   * @notice Get the available yield fee amount accrued by this vault.
   * @return uint256 Yield fee amount
   */
  function availableYieldFeeBalance() public view returns (uint256) {
    uint256 _availableYield = availableYieldBalance();

    if (_availableYield != 0 && _yieldFeePercentage != 0) {
      return _availableYieldFeeBalance(_availableYield);
    }

    return 0;
  }

  /// @inheritdoc IERC4626
  function asset() public view virtual override returns (address) {
    return address(_asset);
  }

  /// @inheritdoc ERC20
  function balanceOf(
    address _account
  ) public view virtual override(ERC20, IERC20) returns (uint256) {
    return _twabController.balanceOf(address(this), _account);
  }

  /// @inheritdoc IERC20Metadata
  function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
    return _underlyingDecimals;
  }

  /// @inheritdoc IERC4626
  function totalAssets() public view virtual override returns (uint256) {
    return _totalAssets();
  }

  /// @inheritdoc ERC20
  function totalSupply() public view virtual override(ERC20, IERC20) returns (uint256) {
    return _totalSupply();
  }

  /**
   * @notice Check if the Vault is collateralized.
   * @return bool True if the vault is collateralized, false otherwise
   */
  function isVaultCollateralized() public view returns (bool) {
    return _isVaultCollateralized(_totalSupply(), _totalAssets());
  }

  /* ============ Max Functions ============ */

  /**
   * @inheritdoc IERC4626
   * @dev We use type(uint112).max cause this is the type used to store balances in TwabController.
   */
  function maxDeposit(address) public view virtual override returns (uint256) {
    uint256 _depositedAssets = _totalSupply();
    uint256 _withdrawableAssets = _totalAssets();

    if (!_isVaultCollateralized(_depositedAssets, _withdrawableAssets)) return 0;

    uint256 _vaultMaxDeposit = UINT112_MAX -
      _convertToAssets(_depositedAssets, _depositedAssets, _withdrawableAssets, Math.Rounding.Up);

    uint256 _yieldVaultMaxDeposit = _yieldVault.maxDeposit(address(this));

    return _yieldVaultMaxDeposit < _vaultMaxDeposit ? _yieldVaultMaxDeposit : _vaultMaxDeposit;
  }

  /**
   * @inheritdoc IERC4626
   * @dev We use type(uint112).max cause this is the type used to store balances in TwabController.
   */
  function maxMint(address) public view virtual override returns (uint256) {
    uint256 _depositedAssets = _totalSupply();

    if (!_isVaultCollateralized(_depositedAssets, _totalAssets())) return 0;

    uint256 _vaultMaxMint = UINT112_MAX - _depositedAssets;
    uint256 _yieldVaultMaxMint = _yieldVault.maxMint(address(this));

    return _yieldVaultMaxMint < _vaultMaxMint ? _yieldVaultMaxMint : _vaultMaxMint;
  }

  /// @inheritdoc IERC4626
  function maxWithdraw(address _owner) public view virtual override returns (uint256) {
    return _convertToAssets(balanceOf(_owner), _totalSupply(), _totalAssets(), Math.Rounding.Down);
  }

  /// @inheritdoc IERC4626
  function maxRedeem(address owner) public view virtual override returns (uint256) {
    return balanceOf(owner);
  }

  /* ============ Preview Functions ============ */

  /// @inheritdoc IERC4626
  function previewDeposit(uint256 _assets) public view virtual override returns (uint256) {
    return _convertToShares(_assets, _totalSupply(), _totalAssets(), Math.Rounding.Down);
  }

  /// @inheritdoc IERC4626
  function previewMint(uint256 _shares) public view virtual override returns (uint256) {
    return _convertToAssets(_shares, _totalSupply(), _totalAssets(), Math.Rounding.Up);
  }

  /// @inheritdoc IERC4626
  function previewWithdraw(uint256 _assets) public view virtual override returns (uint256) {
    return _convertToShares(_assets, _totalSupply(), _totalAssets(), Math.Rounding.Up);
  }

  /// @inheritdoc IERC4626
  function previewRedeem(uint256 _shares) public view virtual override returns (uint256) {
    uint256 _depositedAssets = _totalSupply();
    uint256 _withdrawableAssets = _totalAssets();

    if (_isVaultCollateralized(_depositedAssets, _withdrawableAssets)) {
      // The Vault is collateralized, shares are backed 1:1 by assets
      // no need to convert to assets
      return
        _yieldVault.previewWithdraw(
          _convertToAssets(_shares, _depositedAssets, _withdrawableAssets, Math.Rounding.Down)
        );
    } else {
      return
        _yieldVault.previewRedeem(
          _convertSharesToYVShares(
            _shares,
            _depositedAssets,
            _withdrawableAssets,
            _yieldVault.maxRedeem(address(this)),
            Math.Rounding.Up
          )
        );
    }
  }

  /* ============ Deposit Functions ============ */

  /// @inheritdoc IERC4626
  function deposit(uint256 _assets, address _receiver) public virtual override returns (uint256) {
    return _depositAssets(_assets, msg.sender, _receiver);
  }

  /**
   * @notice Approve underlying asset with permit, deposit into the Vault and mint Vault shares to `_receiver`.
   * @dev Can't be used to deposit on behalf of another user since `permit` does not accept a receiver parameter.
   *      Meaning that anyone could reuse the signature and pass an arbitrary `_receiver` to this function.
   * @param _assets Amount of assets to approve and deposit
   * @param _owner Address of the owner depositing `_assets` and signing the permit
   * @param _deadline Timestamp after which the approval is no longer valid
   * @param _v V part of the secp256k1 signature
   * @param _r R part of the secp256k1 signature
   * @param _s S part of the secp256k1 signature
   * @return uint256 Amount of Vault shares minted to `_receiver`.
   */
  function depositWithPermit(
    uint256 _assets,
    address _owner,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external returns (uint256) {
    _permit(IERC20Permit(asset()), _owner, address(this), _assets, _deadline, _v, _r, _s);
    return _depositAssets(_assets, _owner, _owner);
  }

  /// @inheritdoc IERC4626
  function mint(uint256 _shares, address _receiver) public virtual override returns (uint256) {
    _deposit(msg.sender, _receiver, _shares);
    return _shares;
  }

  /**
   * @notice Deposit assets into the Vault and delegate to the sponsorship address.
   * @param _assets Amount of assets to deposit
   * @return uint256 Amount of shares minted to caller.
   */
  function sponsor(uint256 _assets) external returns (uint256) {
    return _sponsor(_assets, msg.sender);
  }

  /**
   * @notice Deposit underlying assets that have been mistakenly sent to the Vault into the YieldVault.
   * @dev The deposited assets will contribute to the yield of the YieldVault.
   * @return uint256 Amount of underlying assets deposited
   */
  function sweep() external returns (uint256) {
    uint256 _assets = _asset.balanceOf(address(this));
    if (_assets == 0) revert SweepZeroAssets();

    _yieldVault.deposit(_assets, address(this));

    emit Sweep(msg.sender, _assets);

    return _assets;
  }

  /* ============ Withdraw Functions ============ */

  /// @inheritdoc IERC4626
  function withdraw(
    uint256 _assets,
    address _receiver,
    address _owner
  ) public virtual override returns (uint256) {
    if (_assets > maxWithdraw(_owner))
      revert WithdrawMoreThanMax(_owner, _assets, maxWithdraw(_owner));

    uint256 _depositedAssets = _totalSupply();
    uint256 _withdrawableAssets = _totalAssets();
    bool _vaultCollateralized = _isVaultCollateralized(_depositedAssets, _withdrawableAssets);

    uint256 _shares = _vaultCollateralized
      ? _assets
      : _convertToShares(_assets, _depositedAssets, _withdrawableAssets, Math.Rounding.Up);

    uint256 _withdrawnAssets = _redeem(
      msg.sender,
      _receiver,
      _owner,
      _shares,
      _assets,
      _vaultCollateralized
    );

    if (_withdrawnAssets < _assets) revert WithdrawAssetsLTRequested(_assets, _withdrawnAssets);

    return _shares;
  }

  /// @inheritdoc IERC4626
  function redeem(
    uint256 _shares,
    address _receiver,
    address _owner
  ) public virtual override returns (uint256) {
    if (_shares > maxRedeem(_owner)) revert RedeemMoreThanMax(_owner, _shares, maxRedeem(_owner));

    uint256 _depositedAssets = _totalSupply();
    uint256 _withdrawableAssets = _totalAssets();
    bool _vaultCollateralized = _isVaultCollateralized(_depositedAssets, _withdrawableAssets);

    uint256 _assets = _convertToAssets(
      _shares,
      _depositedAssets,
      _withdrawableAssets,
      Math.Rounding.Down
    );

    return _redeem(msg.sender, _receiver, _owner, _shares, _assets, _vaultCollateralized);
  }

  /**
   * @notice Mint Vault shares to the `_yieldFeeRecipient`.
   * @dev Will revert if the Vault is undercollateralized.
   *      So shares does not need to be converted to assets.
   * @dev Will revert if `_shares` is greater than `_yieldFeeShares`.
   * @dev Will revert if there is not enough yield available in the YieldVault to back `_shares`.
   * @param _shares Amount of shares to mint
   */
  function mintYieldFee(uint256 _shares) external onlyVaultCollateralized {
    uint256 _depositedAssets = _totalSupply();
    uint256 _withdrawableAssets = _totalAssets();

    uint256 _availableYield = _withdrawableAssets -
      _convertToAssets(_depositedAssets, _depositedAssets, _withdrawableAssets, Math.Rounding.Down);

    if (_shares > _availableYield) revert YieldFeeGTAvailableYield(_shares, _availableYield);
    if (_shares > _yieldFeeShares) revert YieldFeeGTAvailableShares(_shares, _yieldFeeShares);

    uint256 _vaultMaxMint = _getVaultMaxMint(_depositedAssets);
    if (_shares > _vaultMaxMint) revert YieldFeeGTVaultMaxMint(_shares, _vaultMaxMint);

    _yieldFeeShares -= _shares;
    _mint(_yieldFeeRecipient, _shares);

    emit MintYieldFee(msg.sender, _yieldFeeRecipient, _shares);
  }

  /* ============ Liquidation Functions ============ */

  /// @inheritdoc ILiquidationSource
  function liquidatableBalanceOf(address _token) public view override returns (uint256) {
    return _liquidatableBalanceOf(_token);
  }

  /**
   * @inheritdoc ILiquidationSource
   * @dev Will revert if the Vault is undercollateralized.
   *      So `_amountOut` does not need to be converted to assets.
   * @dev User provides prize tokens and receives in exchange Vault shares.
   * @dev The yield fee can serve as a buffer in case of undercollateralization of the Vault.
   */
  function transferTokensOut(
    address,
    address _receiver,
    address _tokenOut,
    uint256 _amountOut
  ) public virtual override onlyLiquidationPair onlyVaultCollateralized returns (bytes memory) {
    if (_tokenOut != address(this))
      revert LiquidationTokenOutNotVaultShare(_tokenOut, address(this));

    if (_amountOut == 0) revert LiquidationAmountOutZero();

    uint256 _liquidatableYield = _liquidatableBalanceOf(_tokenOut);

    if (_amountOut > _liquidatableYield)
      revert LiquidationAmountOutGTYield(_amountOut, _liquidatableYield);

    uint256 _vaultMaxMint = _getVaultMaxMint(_totalSupply());
    if (_amountOut > _vaultMaxMint)
      revert LiquidationAmountOutGTVaultMaxMint(_amountOut, _vaultMaxMint);

    // Distributes the specified yield fee percentage.
    // For instance, with a yield fee percentage of 20% and 8e18 Vault shares being liquidated,
    // this calculation assigns 2e18 Vault shares to the yield fee recipient.
    // `_amountOut` is the amount of Vault shares being liquidated after accounting for the yield fee.
    if (_yieldFeePercentage != 0) {
      _increaseYieldFeeBalance(
        (_amountOut * FEE_PRECISION) / (FEE_PRECISION - _yieldFeePercentage) - _amountOut
      );
    }

    _mint(_receiver, _amountOut);

    return "";
  }

  /**
   * @inheritdoc ILiquidationSource
   */
  function verifyTokensIn(
    address _tokenIn,
    uint256 _amountIn,
    bytes calldata
  ) public virtual override onlyLiquidationPair {
    if (_tokenIn != address(_prizePool.prizeToken()))
      revert LiquidationTokenInNotPrizeToken(_tokenIn, address(_prizePool.prizeToken()));

    _prizePool.contributePrizeTokens(address(this), _amountIn);
  }

  /// @inheritdoc ILiquidationSource
  function targetOf(address) external view returns (address) {
    return address(_prizePool);
  }

  /* ============ Claim Functions ============ */

  /* ============ Setter Functions ============ */

  /**
   * @notice Set claimer.
   * @param claimer_ Address of the claimer
   * @return address New claimer address
   */
  function setClaimer(address claimer_) external onlyOwner returns (address) {
    address _previousClaimer = _claimer;
    _setClaimer(claimer_);

    emit ClaimerSet(_previousClaimer, claimer_);
    return claimer_;
  }

  /**
   * @notice Sets the hooks for a winner.
   * @param hooks The hooks to set
   */
  function setHooks(VaultHooks memory hooks) external {
    _hooks[msg.sender] = hooks;

    emit SetHooks(msg.sender, hooks);
  }

  /**
   * @notice Set liquidationPair.
   * @dev We reset approval of the previous liquidationPair and approve max for new one.
   * @param liquidationPair_ New liquidationPair address
   * @return address New liquidationPair address
   */
  function setLiquidationPair(
    ILiquidationPair liquidationPair_
  ) external onlyOwner returns (address) {
    if (address(liquidationPair_) == address(0)) revert LPZeroAddress();

    _liquidationPair = liquidationPair_;

    emit LiquidationPairSet(liquidationPair_);
    return address(liquidationPair_);
  }

  /**
   * @notice Set yield fee percentage.
   * @dev Yield fee is represented in 9 decimals and can't exceed `1e9`.
   * @param yieldFeePercentage_ Yield fee percentage
   * @return uint256 New yield fee percentage
   */
  function setYieldFeePercentage(uint256 yieldFeePercentage_) external onlyOwner returns (uint256) {
    uint256 _previousYieldFeePercentage = _yieldFeePercentage;
    _setYieldFeePercentage(yieldFeePercentage_);

    emit YieldFeePercentageSet(_previousYieldFeePercentage, yieldFeePercentage_);
    return yieldFeePercentage_;
  }

  /**
   * @notice Set fee recipient.
   * @param yieldFeeRecipient_ Address of the fee recipient
   * @return address New fee recipient address
   */
  function setYieldFeeRecipient(address yieldFeeRecipient_) external onlyOwner returns (address) {
    address _previousYieldFeeRecipient = _yieldFeeRecipient;
    _setYieldFeeRecipient(yieldFeeRecipient_);

    emit YieldFeeRecipientSet(_previousYieldFeeRecipient, yieldFeeRecipient_);
    return yieldFeeRecipient_;
  }

  /* ============ Getter Functions ============ */

  /**
   * @notice Address of the yield fee recipient.
   * @return address Yield fee recipient address
   */

  function yieldFeeRecipient() public view returns (address) {
    return _yieldFeeRecipient;
  }

  /**
   * @notice Yield fee percentage.
   * @return uint256 Yield fee percentage
   */

  function yieldFeePercentage() public view returns (uint256) {
    return _yieldFeePercentage;
  }

  /**
   * @notice Get total yield fee accrued by this Vault.
   * @dev If the vault becomes undercollateralized, this total yield fee can be used to collateralize it.
   * @return uint256 Total accrued yield fee
   */
  function yieldFeeShares() public view returns (uint256) {
    return _yieldFeeShares;
  }

  /**
   * @notice Address of the TwabController keeping track of balances.
   * @return address TwabController address
   */
  function twabController() public view returns (address) {
    return address(_twabController);
  }

  /**
   * @notice Address of the ERC4626 vault generating yield.
   * @return address YieldVault address
   */
  function yieldVault() public view returns (address) {
    return address(_yieldVault);
  }

  /**
   * @notice Address of the LiquidationPair used to liquidate yield for prize token.
   * @return address LiquidationPair address
   */
  function liquidationPair() public view returns (address) {
    return address(_liquidationPair);
  }

  /**
   * @notice Address of the PrizePool that computes prizes.
   * @return address PrizePool address
   */
  function prizePool() public view returns (address) {
    return address(_prizePool);
  }

  /**
   * @notice Address of the claimer.
   * @return address Claimer address
   */
  function claimer() public view returns (address) {
    return _claimer;
  }

  /**
   * @notice Gets the hooks for the given user.
   * @param _account The user to retrieve the hooks for
   * @return VaultHooks The hooks for the given user
   */
  function getHooks(address _account) external view returns (VaultHooks memory) {
    return _hooks[_account];
  }

  /* ============================================ */
  /* ============ Internal Functions ============ */
  /* ============================================ */

  /**
   * @notice Total amount of assets managed by this Vault.
   * @return uint256 Total amount of assets
   */
  function _totalAssets() internal view returns (uint256) {
    return _yieldVault.maxWithdraw(address(this));
  }

  /**
   * @notice Total amount of shares minted by this Vault.
   * @return uint256 Total amount of shares
   */
  function _totalSupply() internal view returns (uint256) {
    return _twabController.totalSupply(address(this));
  }

  /* ============ Liquidation Functions ============ */

  /**
   * @notice Return the yield amount (available yield minus fees) that can be liquidated by minting Vault shares.
   * @param _token Address of the token to get available balance for
   * @return uint256 Available amount of `_token`
   */
  function _liquidatableBalanceOf(address _token) internal view returns (uint256) {
    if (_token != address(this)) revert LiquidationTokenOutNotVaultShare(_token, address(this));

    uint256 _availableYield = availableYieldBalance();

    unchecked {
      return _availableYield -= _availableYieldFeeBalance(_availableYield);
    }
  }

  /**
   * @notice Available yield fee amount.
   * @param _availableYield Total amount of yield available
   * @return uint256 Available yield fee balance
   */
  function _availableYieldFeeBalance(uint256 _availableYield) internal view returns (uint256) {
    return (_availableYield * _yieldFeePercentage) / FEE_PRECISION;
  }

  /**
   * @notice Increase yield fee balance accrued by `_yieldFeeRecipient`.
   * @param _shares Amount of shares to increase yield fee balance by
   */
  function _increaseYieldFeeBalance(uint256 _shares) internal {
    _yieldFeeShares += _shares;
  }

  /* ============ Conversion Functions ============ */

  /// @inheritdoc IERC4626
  function convertToShares(uint256 _assets) public view virtual override returns (uint256) {
    return _convertToShares(_assets, _totalSupply(), _totalAssets(), Math.Rounding.Down);
  }

  /// @inheritdoc IERC4626
  function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
    return _convertToAssets(shares, _totalSupply(), _totalAssets(), Math.Rounding.Down);
  }

  /**
   * @notice Convert assets to shares.
   * @param _assets Amount of assets to convert
   * @param _depositedAssets Assets deposited into the YieldVault
   * @param _withdrawableAssets Assets withdrawable from the YieldVault
   * @param _rounding Rounding mode (i.e. down or up)
   * @return uint256 Amount of shares corresponding to the assets
   */
  function _convertToShares(
    uint256 _assets,
    uint256 _depositedAssets,
    uint256 _withdrawableAssets,
    Math.Rounding _rounding
  ) internal pure returns (uint256) {
    if (_assets == 0 || _depositedAssets == 0) {
      return _assets;
    }

    uint256 _collateralAssets = _collateral(_depositedAssets, _withdrawableAssets);

    return
      _collateralAssets == 0 ? 0 : _assets.mulDiv(_depositedAssets, _collateralAssets, _rounding);
  }

  /**
   * @notice Convert shares to assets.
   * @param _shares Amount of shares to convert
   * @param _depositedAssets Assets deposited into the YieldVault
   * @param _withdrawableAssets Assets withdrawable from the YieldVault
   * @param _rounding Rounding mode (i.e. down or up)
   * @return uint256 Amount of assets corresponding to the shares
   */
  function _convertToAssets(
    uint256 _shares,
    uint256 _depositedAssets,
    uint256 _withdrawableAssets,
    Math.Rounding _rounding
  ) internal pure returns (uint256) {
    if (_shares == 0 || _depositedAssets == 0) {
      return _shares;
    }

    uint256 _collateralAssets = _collateral(_depositedAssets, _withdrawableAssets);

    return
      _collateralAssets == 0 ? 0 : _shares.mulDiv(_collateralAssets, _depositedAssets, _rounding);
  }

  /**
   * @notice Calculates the amount of YieldVault shares that can be redeemed.
   * @dev When the Vault is collateralized, the yield is excluded from the redeemable amount
   *      so users can only withdraw up to the amount they deposited
   * @param _depositedAssets Assets deposited into the YieldVault
   * @param _withdrawableAssets Assets withdrawable from the YieldVault
   * @param _maxRedeemableYVShares Maximum amount of shares that can be redeemed from the YieldVault
   * @return uint256 Amount of redeemable YieldVault shares
   */
  function _redeemableYVShares(
    uint256 _depositedAssets,
    uint256 _withdrawableAssets,
    uint256 _maxRedeemableYVShares
  ) internal pure returns (uint256) {
    return
      _isVaultCollateralized(_depositedAssets, _withdrawableAssets)
        ? _depositedAssets // shares are backed 1:1 by assets, no need to convert to YieldVault shares
        : _maxRedeemableYVShares;
  }

  /**
   * @notice Convert Vault shares to YieldVault shares.
   * @param _shares Vault shares to convert
   * @param _depositedAssets Assets deposited into the YieldVault
   * @param _withdrawableAssets Assets withdrawable from the YieldVault
   * @param _maxRedeemableYVShares Maximum amount of shares that can be redeemed from the YieldVault
   * @param _rounding Rounding mode (i.e. down or up)
   * @return uint256 YieldVault shares
   */
  function _convertSharesToYVShares(
    uint256 _shares,
    uint256 _depositedAssets,
    uint256 _withdrawableAssets,
    uint256 _maxRedeemableYVShares,
    Math.Rounding _rounding
  ) internal view returns (uint256) {
    if (_shares == 0) {
      return _shares;
    }

    if (_depositedAssets == 0) {
      return _yieldVault.convertToShares(_shares);
    }

    uint256 _redeemableShares = _redeemableYVShares(
      _depositedAssets,
      _withdrawableAssets,
      _maxRedeemableYVShares
    );

    return
      _redeemableShares == 0 ? 0 : _shares.mulDiv(_redeemableShares, _depositedAssets, _rounding);
  }

  /* ============ Deposit Functions ============ */

  /**
   * @notice Deposit assets and mint shares
   * @param _caller The caller of the deposit
   * @param _receiver The receiver of the deposit shares
   * @param _assets Amount of assets to deposit
   * @dev If there are currently some underlying assets in the vault,
   *      we only transfer the difference from the user wallet into the vault.
   *      The difference is calculated this way:
   *      - if `_vaultAssets` balance is greater than 0 and lower than `_assets`,
   *        we subtract `_vaultAssets` from `_assets` and deposit `_assetsDeposit` amount into the vault
   *      - if `_vaultAssets` balance is greater than or equal to `_assets`,
   *        we know the vault has enough underlying assets to fulfill the deposit
   *        so we don't transfer any assets from the user wallet into the vault
   * @dev Will revert if the Vault is undercollateralized.
   * @dev Will revert if 0 shares are minted back to the receiver.
   */
  function _deposit(
    address _caller,
    address _receiver,
    uint256 _assets
  ) internal onlyVaultCollateralized {
    // It is only possible to deposit when the vault is collateralized
    // Shares are backed 1:1 by assets
    if (_assets == 0) revert MintZeroShares();

    uint256 _vaultAssets = _asset.balanceOf(address(this));

    // If _asset is ERC777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
    // `tokensToSend` hook. On the other hand, the `tokenReceived` hook that is triggered after the transfer
    // calls the vault which is assumed to not be malicious.
    //
    // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
    // assets are transferred and before the shares are minted, which is a valid state.

    // We only need to deposit new assets if there is not enough assets in the vault to fulfill the deposit
    if (_assets > _vaultAssets) {
      uint256 _assetsDeposit;

      unchecked {
        if (_vaultAssets != 0) {
          _assetsDeposit = _assets - _vaultAssets;
        }
      }

      SafeERC20.safeTransferFrom(
        _asset,
        _caller,
        address(this),
        _assetsDeposit != 0 ? _assetsDeposit : _assets
      );
    }

    uint256 _withdrawableAssets = _totalAssets();

    _yieldVault.deposit(_assets, address(this));

    uint256 _expectedWithdrawableAssets = _withdrawableAssets + _assets;
    uint256 _withdrawableAssetsAfter = _totalAssets();

    if (_withdrawableAssetsAfter < _expectedWithdrawableAssets)
      revert YVWithdrawableAssetsLTExpected(_withdrawableAssetsAfter, _expectedWithdrawableAssets);

    if (_assets > maxMint(_receiver))
      revert MintMoreThanMax(_receiver, _assets, maxMint(_receiver));

    _mint(_receiver, _assets);

    emit Deposit(_caller, _receiver, _assets, _assets);
  }

  /**
   * @notice Deposit assets and mint shares.
   * @dev Will revert if the Vault is uncollateralized.
   *      So assets does not need to be converted to shares.
   * @param _assets The assets to deposit
   * @param _owner The owner of the assets
   * @param _receiver The receiver of the deposit shares
   * @return uint256 Amount of shares minted to `_receiver`
   */
  function _depositAssets(
    uint256 _assets,
    address _owner,
    address _receiver
  ) internal onlyVaultCollateralized returns (uint256) {
    if (_assets > maxDeposit(_receiver))
      revert DepositMoreThanMax(_receiver, _assets, maxDeposit(_receiver));

    _deposit(_owner, _receiver, _assets);

    return _assets;
  }

  /**
   * @notice Deposit assets into the Vault and delegate to the sponsorship address.
   * @dev There is no receiver parameter.
   *      The calling address is the one depositing assets and receiving shares.
   * @dev If the caller has not delegated to the sponsorship address yet, this function will.
   * @param _assets Amount of assets to deposit
   * @param _owner Address of the owner depositing `_assets`
   * @return uint256 Amount of shares minted to `_receiver`.
   */
  function _sponsor(uint256 _assets, address _owner) internal returns (uint256) {
    _depositAssets(_assets, _owner, _owner);

    if (_twabController.delegateOf(address(this), _owner) != SPONSORSHIP_ADDRESS) {
      _twabController.sponsor(_owner);
    }

    emit Sponsor(_owner, _assets, _assets);

    return _assets;
  }

  /* ============ Redeem Function ============ */

  /**
   * @notice Redeem/Withdraw common flow
   * @dev When the Vault is collateralized, shares are backed by assets 1:1, `withdraw` is used.
   *      When the Vault is undercollateralized, shares are not backed by assets 1:1.
   *      `redeem` is used to avoid burning too many YieldVault shares in exchange of assets.
   * @param _caller Address of the caller
   * @param _receiver Address of the receiver of the assets
   * @param _owner Owner of the shares
   * @param _shares Shares to burn
   * @param _assets Assets to withdraw
   * @param _vaultCollateralized Whether the Vault is collateralized or not
   */
  function _redeem(
    address _caller,
    address _receiver,
    address _owner,
    uint256 _shares,
    uint256 _assets,
    bool _vaultCollateralized
  ) internal returns (uint256) {
    if (_caller != _owner) {
      _spendAllowance(_owner, _caller, _shares);
    }

    uint256 _yieldVaultShares;

    if (!_vaultCollateralized) {
      _yieldVaultShares = _convertSharesToYVShares(
        _shares,
        _totalSupply(),
        _totalAssets(),
        _yieldVault.maxRedeem(address(this)),
        Math.Rounding.Down
      );
    }

    // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
    // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
    // calls the vault, which is assumed not malicious.
    //
    // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
    // shares are burned and after the assets are transferred, which is a valid state.
    _burn(_owner, _shares);

    // If the Vault is collateralized, users can withdraw their deposit 1:1
    if (_vaultCollateralized) {
      _yieldVault.withdraw(_assets, address(this), address(this));
    } else {
      // Otherwise, redeem is used to avoid burning too many YieldVault shares
      _assets = _yieldVault.redeem(_yieldVaultShares, address(this), address(this));
    }

    if (_assets == 0) revert WithdrawZeroAssets();

    SafeERC20.safeTransfer(_asset, _receiver, _assets);

    emit Withdraw(_caller, _receiver, _owner, _assets, _shares);

    return _assets;
  }

  /* ============ Claim Functions ============ */

  /**
   * @notice Claim prize for a winner
   * @param _winner The winner of the prize
   * @param _tier The prize tier
   * @param _prizeIndex The prize index
   * @param _fee The fee to charge
   * @param _feeRecipient The recipient of the fee
   * @return The total prize amount claimed. Zero if already claimed.
   */
  function claimPrize(
    address _winner,
    uint8 _tier,
    uint32 _prizeIndex,
    uint96 _fee,
    address _feeRecipient
  ) external onlyClaimer returns (uint256) {
    VaultHooks memory hooks = _hooks[_winner];
    address recipient;

    if (hooks.useBeforeClaimPrize) {
      try
        hooks.implementation.beforeClaimPrize{ gas: HOOK_GAS }(
          _winner,
          _tier,
          _prizeIndex,
          _fee,
          _feeRecipient
        )
      returns (address result) {
        recipient = result;
      } catch (bytes memory reason) {
        revert BeforeClaimPrizeFailed(reason);
      }
    } else {
      recipient = _winner;
    }

    uint prizeTotal = _prizePool.claimPrize(
      _winner,
      _tier,
      _prizeIndex,
      recipient,
      _fee,
      _feeRecipient
    );

    if (hooks.useAfterClaimPrize) {
      try
        hooks.implementation.afterClaimPrize{ gas: HOOK_GAS }(
          _winner,
          _tier,
          _prizeIndex,
          prizeTotal,
          recipient
        )
      {} catch (bytes memory reason) {
        revert AfterClaimPrizeFailed(reason);
      }
    }

    return prizeTotal;
  }

  /* ============ Permit Functions ============ */

  /**
   * @notice Approve `_spender` to spend `_assets` of `_owner`'s `_asset` via signature.
   * @param _permitAsset Address of the asset to approve
   * @param _owner Address of the owner of the asset
   * @param _spender Address of the spender of the asset
   * @param _assets Amount of assets to approve
   * @param _deadline Timestamp after which the approval is no longer valid
   * @param _v V part of the secp256k1 signature
   * @param _r R part of the secp256k1 signature
   * @param _s S part of the secp256k1 signature
   */
  function _permit(
    IERC20Permit _permitAsset,
    address _owner,
    address _spender,
    uint256 _assets,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) internal {
    _permitAsset.permit(_owner, _spender, _assets, _deadline, _v, _r, _s);
  }

  /* ============ State Functions ============ */

  /**
   * @notice Creates `_shares` tokens and assigns them to `_receiver`, increasing the total supply.
   * @dev Emits a {Transfer} event with `from` set to the zero address.
   * @dev `_receiver` cannot be the zero address.
   * @param _receiver Address that will receive the minted shares
   * @param _shares Shares to mint
   */
  function _mint(address _receiver, uint256 _shares) internal virtual override {
    if (_shares > maxMint(_receiver))
      revert MintMoreThanMax(_receiver, _shares, maxMint(_receiver));

    _twabController.mint(_receiver, SafeCast.toUint96(_shares));

    emit Transfer(address(0), _receiver, _shares);
  }

  /**
   * @notice Destroys `_shares` tokens from `_owner`, reducing the total supply.
   * @dev Emits a {Transfer} event with `to` set to the zero address.
   * @dev `_owner` cannot be the zero address.
   * @dev `_owner` must have at least `_shares` tokens.
   * @param _owner The owner of the shares
   * @param _shares The shares to burn
   */
  function _burn(address _owner, uint256 _shares) internal virtual override {
    _twabController.burn(_owner, SafeCast.toUint112(_shares));

    emit Transfer(_owner, address(0), _shares);
  }

  /**
   * @notice Updates `_from` and `_to` TWAB balance for a transfer.
   * @dev `_from` cannot be the zero address.
   * @dev `_to` cannot be the zero address.
   * @dev `_from` must have a balance of at least `_shares`.
   * @param _from Address to transfer from
   * @param _to Address to transfer to
   * @param _shares Shares to transfer
   */
  function _transfer(address _from, address _to, uint256 _shares) internal virtual override {
    _twabController.transfer(_from, _to, SafeCast.toUint112(_shares));

    emit Transfer(_from, _to, _shares);
  }

  /**
   * @notice Returns the quantity of withdrawable underlying assets held as collateral by the YieldVault.
   * @dev When the Vault is collateralized, Vault shares are minted at a 1:1 ratio based on the user's deposited underlying assets.
   *      The total supply of shares corresponds directly to the total amount of underlying assets deposited into the YieldVault.
   *      Users have the ability to withdraw only the quantity of underlying assets they initially deposited,
   *      without access to any of the accumulated yield within the YieldVault.
   * @dev In case of undercollateralization, any remaining collateral within the YieldVault can be withdrawn.
   *      Withdrawals can be made by users for their corresponding deposit shares.
   * @param _depositedAssets Assets deposited into the YieldVault
   * @param _withdrawableAssets Assets withdrawable from the YieldVault
   * @return uint256 Available collateral
   */
  function _collateral(
    uint256 _depositedAssets,
    uint256 _withdrawableAssets
  ) internal pure returns (uint256) {
    // If the Vault is collateralized, users can only withdraw the amount of underlying assets they deposited.
    if (_isVaultCollateralized(_depositedAssets, _withdrawableAssets)) {
      return _depositedAssets;
    }

    // Otherwise, any remaining collateral within the YieldVault is available
    // and distributed proportionally among depositors.
    return _withdrawableAssets;
  }

  /**
   * @notice Check if the Vault is collateralized.
   * @dev The vault is collateralized if the total amount of underlying assets currently held by the YieldVault
   *      is greater than or equal to the total supply of shares minted by the Vault.
   * @param _depositedAssets Assets deposited into the YieldVault
   * @param _withdrawableAssets Assets withdrawable from the YieldVault
   * @return bool True if the vault is collateralized, false otherwise
   */
  function _isVaultCollateralized(
    uint256 _depositedAssets,
    uint256 _withdrawableAssets
  ) internal pure returns (bool) {
    return _withdrawableAssets >= _depositedAssets;
  }

  /**
   * @notice Returns the maximum amount of Vault shares that can be minted.
   * @dev It would overflow if minting more shares than the TwabController uint112 max type.
   * @param _depositedAssets Assets deposited into the YieldVault
   */
  function _getVaultMaxMint(uint256 _depositedAssets) internal pure returns (uint256) {
    return type(uint112).max - _depositedAssets;
  }

  /* ============ Modifiers ============ */

  /// @notice Require reverting if the vault is under-collateralized.
  modifier onlyVaultCollateralized() {
    if (!_isVaultCollateralized(_totalSupply(), _totalAssets())) revert VaultUnderCollateralized();
    _;
  }

  /* ============ Setter Functions ============ */

  /**
   * @notice Set claimer address.
   * @param claimer_ Address of the claimer
   */
  function _setClaimer(address claimer_) internal {
    _claimer = claimer_;
  }

  /**
   * @notice Set yield fee percentage.
   * @dev Yield fee is represented in 9 decimals and can't exceed or equal `1e9`.
   * @param yieldFeePercentage_ The new yield fee percentage to set
   */
  function _setYieldFeePercentage(uint256 yieldFeePercentage_) internal {
    if (yieldFeePercentage_ >= FEE_PRECISION) {
      revert YieldFeePercentageGtePrecision(yieldFeePercentage_, FEE_PRECISION);
    }
    _yieldFeePercentage = yieldFeePercentage_;
  }

  /**
   * @notice Set yield fee recipient address.
   * @param yieldFeeRecipient_ Address of the fee recipient
   */
  function _setYieldFeeRecipient(address yieldFeeRecipient_) internal {
    _yieldFeeRecipient = yieldFeeRecipient_;
  }

  /**
   * @notice Requires the caller to be the claimer
   */
  modifier onlyClaimer() {
    if (msg.sender != _claimer) revert CallerNotClaimer(msg.sender, _claimer);
    _;
  }

  /**
   * @notice Requires the caller to be the liquidation pair
   */
  modifier onlyLiquidationPair() {
    if (msg.sender != address(_liquidationPair))
      revert CallerNotLP(msg.sender, address(_liquidationPair));
    _;
  }
}

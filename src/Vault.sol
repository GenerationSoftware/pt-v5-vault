// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC4626, ERC20, IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { Ownable } from "owner-manager-contracts/Ownable.sol";
import { LiquidationPair } from "v5-liquidator/LiquidationPair.sol";
import { ILiquidationSource } from "v5-liquidator-interfaces/ILiquidationSource.sol";
import { PrizePool } from "v5-prize-pool/PrizePool.sol";
import { TwabController } from "v5-twab-controller/TwabController.sol";
import { Claimer } from "v5-vrgda-claimer/Claimer.sol";

/**
 * @title  PoolTogether V5 Vault
 * @author PoolTogether Inc Team
 * @notice Vault extends the ERC4626 standard and is the entry point for users interacting with a V5 pool.
 *         Users deposit an underlying asset (i.e. USDC) in this contract and receive in exchange an ERC20 token
 *         representing their share of deposit in the vault.
 *         Underlying assets are then deposited in a YieldVault to generate yield.
 *         This yield is sold for prize tokens (i.e. POOL) via the Liquidator and captured by the PrizePool to be awarded to depositors.
 * @dev    Balances are stored in the TwabController contract.
 */
contract Vault is ERC4626, ILiquidationSource, Ownable {
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
   * @param owner Address of the owner
   */
  event NewVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    TwabController twabController,
    IERC4626 indexed yieldVault,
    PrizePool indexed prizePool,
    Claimer claimer,
    address owner
  );

  /**
   * @notice Emitted when auto claim has been disabled or activated by a user.
   * @param user Address of the user for which auto claim was disabled or activated
   * @param status Whether auto claim is disabled or not
   */
  event AutoClaimDisabled(address user, bool status);

  /**
   * @notice Emitted when a new claimer has been set.
   * @param previousClaimer Address of the previous claimer
   * @param newClaimer Address of the new claimer
   */
  event ClaimerSet(Claimer previousClaimer, Claimer newClaimer);

  /**
   * @notice Emitted when a new LiquidationPair has been set.
   * @param previousLiquidationPair Address of the previous liquidationPair
   * @param newLiquidationPair Address of the new liquidationPair
   */
  event LiquidationPairSet(
    LiquidationPair previousLiquidationPair,
    LiquidationPair newLiquidationPair
  );

  /**
   * @notice Emitted when a user sponsor the Vault.
   * @param caller Address that called the function
   * @param receiver Address receiving the Vault shares
   * @param assets Amount of assets deposited into the Vault
   * @param shares Amount of shares minted to `receiver`
   */
  event Sponsor(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);

  /* ============ Variables ============ */

  /// @notice Address of the TwabController used to keep track of balances.
  TwabController private immutable _twabController;

  /// @notice Address of the ERC4626 vault generating yield.
  IERC4626 private immutable _yieldVault;

  /// @notice Address of the PrizePool that computes prizes.
  PrizePool private immutable _prizePool;

  /// @notice Address of the claimer.
  Claimer private _claimer;

  /// @notice Address of the LiquidationPair used to liquidate yield for prize token.
  LiquidationPair private _liquidationPair;

  /// @notice Amount of underlying assets supplied to the YieldVault.
  uint256 private _assetSupplyBalance;

  /* ============ Mappings ============ */

  /// @notice Mapping to keep track of users who disabled prize auto claiming.
  mapping(address => bool) public autoClaimDisabled;

  /* ============ Constructor ============ */

  /**
   * @notice Vault constructor
   * @dev `claimer` can be set to address zero if none is available yet.
   * @param _asset Address of the underlying asset used by the vault
   * @param _name Name of the ERC20 share minted by the vault
   * @param _symbol Symbol of the ERC20 share minted by the vault
   * @param twabController_ Address of the TwabController used to keep track of balances
   * @param yieldVault_ Address of the ERC4626 vault in which assets are deposited to generate yield
   * @param prizePool_ Address of the PrizePool that computes prizes
   * @param claimer_ Address of the claimer
   * @param _owner Address that will gain ownership of this contract
   */
  constructor(
    IERC20 _asset,
    string memory _name,
    string memory _symbol,
    TwabController twabController_,
    IERC4626 yieldVault_,
    PrizePool prizePool_,
    Claimer claimer_,
    address _owner
  ) ERC4626(_asset) ERC20(_name, _symbol) Ownable(_owner) {
    require(address(twabController_) != address(0), "Vault/twabCtrlr-not-zero-address");
    require(address(yieldVault_) != address(0), "Vault/YV-not-zero-address");
    require(address(prizePool_) != address(0), "Vault/PP-not-zero-address");
    require(address(_owner) != address(0), "Vault/owner-not-zero-address");

    /// TODO: yield needs to be exposed but also other yield farm tokens => need for ownership

    _twabController = twabController_;
    _yieldVault = yieldVault_;
    _prizePool = prizePool_;
    _claimer = claimer_;

    // Approve once for max amount
    _asset.safeApprove(address(yieldVault_), type(uint256).max);

    emit NewVault(
      _asset,
      _name,
      _symbol,
      twabController_,
      yieldVault_,
      prizePool_,
      claimer_,
      _owner
    );
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ILiquidationSource
  function availableBalanceOf(address _token) public view override returns (uint256) {
    return _availableBalanceOf(_token);
  }

  /// @inheritdoc ERC20
  function balanceOf(
    address _account
  ) public view virtual override(ERC20, IERC20) returns (uint256) {
    return _balanceOf(_account);
  }

  /**
   * @inheritdoc ERC4626
   * @dev The total amount of assets managed by this vault is equal to
   *      the total amount supplied to the YieldVault + the amount living in this vault.
   */
  function totalAssets() public view virtual override returns (uint256) {
    return _assetSupplyBalance + super.totalAssets();
  }

  /// @inheritdoc ERC20
  function totalSupply() public view virtual override(ERC20, IERC20) returns (uint256) {
    return _twabController.totalSupply(address(this));
  }

  /**
   * @inheritdoc ERC4626
   * @dev We check if vault is properly collateralized.
   *      If yes, we return uint112 max value. Otherwise, we return 0.
   * @dev We use type(uint112).max cause this is the type used to store balances in TwabController.
   */
  function maxDeposit(address) public view virtual override returns (uint256) {
    return (totalAssets() > 0 || totalSupply() == 0) ? type(uint112).max : 0;
  }

  /**
   * @inheritdoc ERC4626
   * @dev We use type(uint112).max cause this is the type used to store balances in TwabController.
   */
  function maxMint(address) public view virtual override returns (uint256) {
    return type(uint112).max;
  }

  /**
   * @notice Deposit assets into the Vault and delegate to the sponsorship address.
   * @param _assets Amount of assets to deposit
   * @param _receiver Address of the receiver of the assets
   * @return uint256 Amount of shares minted to `_receiver`.
   */
  function sponsor(uint256 _assets, address _receiver) external returns (uint256) {
    uint256 _shares = super.deposit(_assets, _receiver);

    if (
      _twabController.delegateOf(address(this), _receiver) != _twabController.SPONSORSHIP_ADDRESS()
    ) {
      _twabController.sponsor(_receiver);
    }

    emit Sponsor(msg.sender, _receiver, _assets, _shares);

    return _shares;
  }

  /// @inheritdoc ERC4626
  function withdraw(
    uint256 _assets,
    address _receiver,
    address _owner
  ) public virtual override returns (uint256) {
    _withdrawFromYieldVault(_assets);
    return super.withdraw(_assets, _receiver, _owner);
  }

  /// @inheritdoc ERC4626
  function redeem(
    uint256 _shares,
    address _receiver,
    address _owner
  ) public virtual override returns (uint256) {
    _withdrawFromYieldVault(convertToAssets(_shares));
    return super.redeem(_shares, _receiver, _owner);
  }

  /**
   * @inheritdoc ILiquidationSource
   * @dev User provides prize tokens and receives in exchange Vault shares.
   */
  function liquidate(
    address _account,
    address _tokenIn,
    uint256 _amountIn,
    address _tokenOut,
    uint256 _amountOut
  ) external override returns (bool) {
    require(msg.sender == address(_liquidationPair), "Vault/caller-not-LP");
    require(_tokenIn == address(_prizePool.prizeToken()), "Vault/tokenIn-not-prizeToken");
    require(_tokenOut == address(this), "Vault/tokenOut-not-vaultShare");

    uint256 _availableBalance = availableBalanceOf(_tokenOut);
    require(_availableBalance >= _amountOut, "Vault/amount-gt-available-yield");

    _prizePool.contributePrizeTokens(address(this), _amountIn);
    _mint(_account, _amountOut);

    return true;
  }

  /// @inheritdoc ILiquidationSource
  function targetOf(address _token) external view returns (address) {
    require(_token == _liquidationPair.tokenIn(), "Vault/target-token-unsupported");
    return address(_prizePool);
  }

  /**
   * @notice Claim prize for `_user`.
   * @dev Callable by anyone if claimer has not been set.
   * @dev If claimer has been set:
   *      - caller needs to be claimer address
   *      - If auto claim is disabled for `_user`:
   *        - caller can be any address except claimer address
   * @param _winner Address of the user to claim prize for
   * @param _tier Tier to claim prize for
   * @param _to Address of the recipient that will receive the prize
   * @param _fee Amount in fees paid to `_feeRecipient`
   * @param _feeRecipient Address that will receive the fee for claiming
   */
  function claimPrize(
    address _winner,
    uint8 _tier,
    address _to,
    uint96 _fee,
    address _feeRecipient
  ) external returns (uint256) {
    address _claimerAddress = address(_claimer);

    if (_claimerAddress != address(0)) {
      if (autoClaimDisabled[_winner]) {
        require(msg.sender != _claimerAddress, "Vault/auto-claim-disabled");
      } else {
        require(msg.sender == _claimerAddress, "Vault/caller-not-claimer");
      }
    }

    return _prizePool.claimPrize(_winner, _tier, _to, _fee, _feeRecipient);
  }

  /* ============ Setter Functions ============ */

  /**
   * @notice Allow a user to disable or activate prize auto claiming.
   * @dev Auto claim is active by default for all users.
   * @param _disable Disable or activate auto claim for `msg.sender`
   * @return bool New auto claim status
   */
  function disableAutoClaim(bool _disable) external returns (bool) {
    autoClaimDisabled[msg.sender] = _disable;

    emit AutoClaimDisabled(msg.sender, _disable);
    return _disable;
  }

  /**
   * @notice Set claimer.
   * @param claimer_ New claimer address
   * return address New claimer address
   */
  function setClaimer(Claimer claimer_) external onlyOwner returns (address) {
    Claimer _previousClaimer = _claimer;
    _claimer = claimer_;

    emit ClaimerSet(_previousClaimer, claimer_);
    return address(claimer_);
  }

  /**
   * @notice Set liquidationPair.
   * @dev We reset approval of the previous liquidationPair and approve max for new one.
   * @param liquidationPair_ New liquidationPair address
   * return address New liquidationPair address
   */
  function setLiquidationPair(
    LiquidationPair liquidationPair_
  ) external onlyOwner returns (address) {
    require(address(liquidationPair_) != address(0), "Vault/LP-not-zero-address");

    LiquidationPair _previousLiquidationPair = _liquidationPair;
    _liquidationPair = liquidationPair_;

    IERC20 _asset = IERC20(asset());

    if (address(_previousLiquidationPair) != address(0)) {
      _asset.safeApprove(address(_previousLiquidationPair), 0);
    }

    _asset.safeApprove(address(liquidationPair_), type(uint256).max);

    emit LiquidationPairSet(_previousLiquidationPair, liquidationPair_);
    return address(liquidationPair_);
  }

  /* ============ Getter Functions ============ */

  /**
   * @notice Address of the TwabController keeping track of balances.
   * @return address TwabController address
   */
  function twabController() external view returns (address) {
    return address(_twabController);
  }

  /**
   * @notice Address of the ERC4626 vault generating yield.
   * @return address YieldVault address
   */
  function yieldVault() external view returns (address) {
    return address(_yieldVault);
  }

  /**
   * @notice Address of the LiquidationPair used to liquidate yield for prize token.
   * @return address LiquidationPair address
   */
  function liquidationPair() external view returns (address) {
    return address(_liquidationPair);
  }

  /**
   * @notice Address of the PrizePool that computes prizes.
   * @return address PrizePool address
   */
  function prizePool() external view returns (address) {
    return address(_prizePool);
  }

  /**
   * @notice Address of the claimer.
   * @return address Claimer address
   */
  function claimer() external view returns (address) {
    return address(_claimer);
  }

  /* ============ Internal Functions ============ */

  /**
   * @notice Get available yield that can be liquidated by minting vault shares.
   * @param _token Address of the token to get available balance for
   * @dev The available yield to liquidate is equal to the maximum amount of assets
   *      that can be withdrawn from the YieldVault minus the total amount of assets managed by this vault
   *      which is equal to the total amount supplied to the YieldVault + the amount living in this vault.
   * @dev If `_totalAssets` is greater than `_withdrawableAssets`, it could mean that:
   *      - assets are living in this vault
   *      - this vault is now undercollateralized
   *      In both cases, we should not mint more shares than underlying assets available,
   *      so we return the amount of assets living in this vault
   * @return uint256 Available amount of `_token`.
   */
  function _availableBalanceOf(address _token) internal view returns (uint256) {
    require(_token == address(this), "Vault/token-not-vault-share");

    uint256 _totalAssets = totalAssets();
    uint256 _withdrawableAssets = _yieldVault.convertToAssets(_yieldVault.balanceOf(address(this)));

    unchecked {
      return
        _withdrawableAssets >= _totalAssets
          ? _withdrawableAssets - _totalAssets
          : super.totalAssets(); // equivalent to `_asset.balanceOf(address(this))`
    }
  }

  /**
   * @notice Get balance of `_account`.
   * @param _account Address to retrieve the balance from
   */
  function _balanceOf(address _account) internal view returns (uint256) {
    return _twabController.balanceOf(address(this), _account);
  }

  /**
   * @notice Deposit/mint common workflow.
   * @dev If there are currently some underlying assets in the vault,
   *      we only transfer the difference from the user wallet into the vault.
   *      The difference is calculated this way:
   *      - if `_vaultAssets` balance is greater than 0 and lower than `_assets`,
   *        we substract `_vaultAssets` from `_assets` and deposit `_assetsDeposit` amount into the vault
   *      - if `_vaultAssets` balance is greater than or equal to `_assets`,
   *        we know the vault has enough underlying assets to fulfill the deposit
   *        so we don't transfer any assets from the user wallet into the vault
   */
  function _deposit(
    address _caller,
    address _receiver,
    uint256 _assets,
    uint256 _shares
  ) internal virtual override {
    IERC20 _asset = IERC20(asset());
    uint256 _vaultAssets = _asset.balanceOf(address(this));

    // If _asset is ERC777, `transferFrom` can trigger a reenterancy BEFORE the transfer happens through the
    // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
    // calls the vault, which is assumed not malicious.
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

      // slither-disable-next-line reentrancy-no-eth
      SafeERC20.safeTransferFrom(
        _asset,
        _caller,
        address(this),
        _assetsDeposit != 0 ? _assetsDeposit : _assets
      );
    }

    _depositIntoYieldVault(_assets);
    _mint(_receiver, _shares);

    emit Deposit(_caller, _receiver, _assets, _shares);
  }

  /**
   * @notice Creates `_shares` tokens and assigns them to `_account`, increasing the total supply.
   * @dev Emits a {Transfer} event with `from` set to the zero address.
   * @dev `_account` cannot be the zero address.
   */
  function _mint(address _account, uint256 _shares) internal virtual override {
    require(_account != address(0), "Vault/mint-to-zero-address");

    _twabController.twabMint(_account, uint112(_shares));
    emit Transfer(address(0), _account, _shares);
  }

  /**
   * @notice Destroys `_shares` tokens from `_account`, reducing the total supply.
   * @dev Emits a {Transfer} event with `to` set to the zero address.
   * @dev `_account` cannot be the zero address.
   * @dev `_account` must have at least `_shares` tokens.
   */
  function _burn(address _account, uint256 _shares) internal virtual override {
    require(_account != address(0), "Vault/burn-not-zero-address");

    uint256 _accountBalance = _balanceOf(_account);
    require(_accountBalance >= _shares, "Vault/burn-amount-gt-balance");

    _twabController.twabBurn(_account, uint112(_shares));
    emit Transfer(_account, address(0), _shares);
  }

  /**
   * @notice Updates `_from` and `_to` TWAB balance for a transfer.
   * @dev `_from` cannot be the zero address.
   * @dev `_to` cannot be the zero address.
   * @dev `_from` must have a balance of at least `_shares`.
   */
  function _transfer(address _from, address _to, uint256 _shares) internal virtual override {
    require(_from != address(0), "Vault/from-not-zero-address");
    require(_to != address(0), "Vault/to-not-zero-address");

    uint256 _fromBalance = _balanceOf(_from);
    require(_fromBalance >= _shares, "Vault/transfer-amount-gt-balance");

    _twabController.twabTransfer(_from, _to, uint112(_shares));
    emit Transfer(_from, _to, _shares);
  }

  /**
   * @notice Increase `_assetSupplyBalance` and deposit `_assets` into YieldVault
   * @param _assets Amount of underlying assets to transfer
   */
  function _depositIntoYieldVault(uint256 _assets) internal {
    _assetSupplyBalance += _assets;
    _yieldVault.deposit(_assets, address(this));
  }

  /**
   * @notice Decrease `_assetSupplyBalance` and withdraw `_assets` from YieldVault
   * @param _assets Amount of underlying assets to withdraw
   */
  function _withdrawFromYieldVault(uint256 _assets) internal {
    _assetSupplyBalance -= _assets;
    _yieldVault.withdraw(_assets, address(this), address(this));
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC4626, ERC20, IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { TwabController } from "v5-twab-controller/TwabController.sol";

/**
 * @title  PoolTogether V5 PrizeVault
 * @author PoolTogether Inc Team
 * @notice PrizeVault extends the ERC4626 standard and is the entry point for users interacting with a V5 pool.
 *         Users deposit an underlying asset (i.e. USDC) in this contract and receive in exchange an ERC20 token
 *         representing their share of deposit in the vault.
 *         Underlying assets are then deposited in a YieldVault to generate yield.
 *         This yield is sold for POOL tokens via the Liquidator and captured by the PrizePool to be awarded to depositors.
 * @dev    Balances are stored in the TwabController contract.
 */
contract PrizeVault is ERC4626 {
  using SafeERC20 for IERC20;

  /* ============ Events ============ */

  /**
   * @notice Emitted when a new PrizeVault has been deployed
   * @param asset Address of the underlying asset used by the vault
   * @param name Name of the ERC20 share minted by the vault
   * @param symbol Symbol of the ERC20 share minted by the vault
   * @param twabController Address of the TWABController used to keep track of balances
   * @param yieldVault Address of the ERC4626 vault in which assets are deposited to generate yield
   */
  event NewPrizeVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    TwabController indexed twabController,
    IERC4626 indexed yieldVault
  );

  /* ============ Variables ============ */

  /// @notice Address of the TWABController used to keep track of balances
  TwabController private immutable _twabController;

  /// @notice Address of the ERC4626 vault generating yield
  IERC4626 private immutable _yieldVault;

  /// @notice Amount of underlying assets supplied to the YieldVault
  uint256 private _assetSupplyBalance;

  /**
   * @notice PrizeVault constructor
   * @param _asset Address of the underlying asset used by the vault
   * @param _name Name of the ERC20 share minted by the vault
   * @param _symbol Symbol of the ERC20 share minted by the vault
   * @param twabController_ Address of the TWABController used to keep track of balances
   * @param yieldVault_ Address of the ERC4626 vault in which assets are deposited to generate yield
   */
  constructor(
    IERC20 _asset,
    string memory _name,
    string memory _symbol,
    TwabController twabController_,
    IERC4626 yieldVault_
  ) ERC4626(_asset) ERC20(_name, _symbol) {
    require(address(twabController_) != address(0), "PV/twabCtrlr-not-zero-address");
    require(address(yieldVault_) != address(0), "PV/yieldVault-not-zero-address");
    /// TODO: setup liquidation pair/source
    /// yield needs to be exposed but also other yield farm tokens => need for ownership

    _twabController = twabController_;
    _yieldVault = yieldVault_;

    // Approve once for max amount
    _asset.safeApprove(address(yieldVault_), type(uint256).max);

    emit NewPrizeVault(_asset, _name, _symbol, twabController_, yieldVault_);
  }

  /* ============ External Functions ============ */

  /// @inheritdoc ERC20
  function balanceOf(
    address _account
  ) public view virtual override(ERC20, IERC20) returns (uint256) {
    return _balanceOf(_account);
  }

  /**
   * @inheritdoc ERC4626
   * @dev The total amount of assets managed by this vault is equal to
   *      the amount supplied to the YieldVault + the amount living in this vault.
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

  /// @inheritdoc ERC4626
  function deposit(uint256 _assets, address _receiver) public virtual override returns (uint256) {
    /// TODO: remove, delegation should be handled by TwabController
    _twabController.delegate(address(this), _receiver, _receiver);

    /// TODO: handle use of assets in the vault and move to another PrizeVault
    return super.deposit(_assets, _receiver);
  }

  /// @inheritdoc ERC4626
  function mint(uint256 _shares, address _receiver) public virtual override returns (uint256) {
    /// TODO: remove, delegation should be handled by TwabController
    _twabController.delegate(address(this), _receiver, _receiver);

    return super.mint(_shares, _receiver);
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
   * @notice Address of the TWABController keeping track of balances.
   * @return address TWABController address
   */
  function twabController() external view returns (address) {
    return address(_twabController);
  }

  /**
   * @notice Address of the ERC4626 vault generating yield
   * @return address YieldVault address
   */
  function yieldVault() external view returns (address) {
    return address(_yieldVault);
  }

  /* ============ Internal Functions ============ */

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
   *      - if `_vaultAssets` balance is greater than 0 and lower than `assets`,
   *        we substract `_vaultAssets` from `assets` and deposit `_assetsDeposit` amount into the vault
   *      - if `_vaultAssets` balance is greater than or equal to `assets`,
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
    require(_account != address(0), "PV/mint-to-zero-address");

    _twabController.mint(address(this), _account, _shares);
    emit Transfer(address(0), _account, _shares);
  }

  /**
   * @notice Destroys `_shares` tokens from `_account`, reducing the total supply.
   * @dev Emits a {Transfer} event with `to` set to the zero address.
   * @dev `_account` cannot be the zero address.
   * @dev `_account` must have at least `_shares` tokens.
   */
  function _burn(address _account, uint256 _shares) internal virtual override {
    require(_account != address(0), "PV/burn-not-zero-address");

    uint256 _accountBalance = _balanceOf(_account);
    require(_accountBalance >= _shares, "PV/burn-amount-gt-balance");

    _twabController.burn(address(this), _account, _shares);
    emit Transfer(_account, address(0), _shares);
  }

  /**
   * @notice Updates `_from` and `_to` TWAB balance for a transfer.
   * @dev `_from` cannot be the zero address.
   * @dev `_to` cannot be the zero address.
   * @dev `_from` must have a balance of at least `_shares`.
   */
  function _transfer(address _from, address _to, uint256 _shares) internal virtual override {
    /// TODO: remove, delegation should be handled by TwabController
    _twabController.delegate(address(this), _from, _from);
    _twabController.delegate(address(this), _to, _to);

    require(_from != address(0), "PV/from-not-zero-address");
    require(_to != address(0), "PV/to-not-zero-address");

    uint256 _fromBalance = _balanceOf(_from);
    require(_fromBalance >= _shares, "PV/transfer-amount-gt-balance");

    _twabController.twabTransfer(address(this), _from, _to, _shares);
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC4626 } from "openzeppelin/interfaces/IERC4626.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { Math } from "openzeppelin/utils/math/Math.sol";
import { Ownable } from "owner-manager-contracts/Ownable.sol";

import { Claimable } from "./abstract/Claimable.sol";
import { TwabERC20, ERC20, IERC20, IERC20Metadata, IERC20Permit } from "./TwabERC20.sol";

import { ILiquidationSource } from "pt-v5-liquidator-interfaces/ILiquidationSource.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController, SPONSORSHIP_ADDRESS } from "pt-v5-twab-controller/TwabController.sol";
import { ObservationLib } from "pt-v5-twab-controller/libraries/ObservationLib.sol";

/**
 * @title  PoolTogether V5 Prize Vault
 * @author G9 Software Inc.
 * @notice This vault extends the ERC4626 standard that accepts deposits of an underlying token (ex: USDC) and
 *         deposits it to an underlying yield source while converting any accrued yield to prize tokens (ex: POOL) 
 *         and contributing them to the prize pool, giving the depositors a chance to win prizes. This vault always
 *         assumes a one-to-one ratio of underlying assets to receipt tokens when depositing or minting, but a
 *         depositor's ability to withdraw assets or redeem shares is dependent on underlying market conditions;
 *         as is the the available rate of exchange.
 *
 * TODO:   Add an explanation for dust collection and rounding error mitigation.
 *
 * @dev    Balances are stored in the TwabController contract.
 */
contract PrizeVault is TwabERC20, Claimable, IERC4626, ILiquidationSource, Ownable {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /* ============ Public Constants and Variables ============ */

    /// @notice The yield fee decimal precision.
    uint32 public constant FEE_PRECISION = 1e9;

    /// @notice The yield buffer that is reserved for covering rounding errors on withdrawals and deposits.
    /// @dev The buffer prevents the entire yield balance from being liquidated, which would leave the vault in a
    ///      state where a single rounding error could reduce the totalAssets to less than the totalSupply.
    /// @dev If the yield vault does not accrue yield on a regular basis, it is recommended to set the yieldBuffer
    ///      higher than normal to ensure all rounding errors on deposits and withdrawals are covered between yield
    ///      accrual periods.
    uint256 public immutable yieldBuffer;

    /// @notice Address of the underlying ERC4626 vault generating yield.
    IERC4626 public immutable yieldVault;

    /// @notice Yield fee percentage represented in integer format with decimal precision defined by `FEE_PRECISION`.
    /// @dev For example, if `FEE_PRECISION` were 1e9 a value of 1e7 = 0.01 = 1%.
    uint32 public yieldFeePercentage;

    /// @notice Address of the yield fee recipient.
    address public yieldFeeRecipient;

    /// @notice Address of the liquidation pair used to liquidate yield for prize token.
    address public liquidationPair;

    /* ============ Private Variables ============ */

    /// @notice Address of the underlying asset used by the Vault.
    IERC20 private immutable _asset;

    /// @notice Underlying asset decimals.
    uint8 private immutable _underlyingDecimals;

    /// @notice Yield fees accrued through liquidations.
    uint256 private _accruedYieldFee;

    /* ============ Events ============ */

    /**
     * @notice Emitted when a new yield fee recipient has been set.
     * @param yieldFeeRecipient Address of the new yield fee recipient
     */
    event YieldFeeRecipientSet(address indexed yieldFeeRecipient);

    /**
     * @notice Emitted when a new yield fee percentage has been set.
     * @param yieldFeePercentage New yield fee percentage
     */
    event YieldFeePercentageSet(uint256 yieldFeePercentage);

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
     * @param assets Amount of assets swept into the YieldVault
     */
    event Sweep(address indexed caller, uint256 assets);

    /**
     * @notice Emitted when yield fee is withdrawn to the yield recipient.
     * @param recipient Address receiving the fee
     * @param amount Amount of assets withdrawn to `recipient`
     */
    event WithdrawYieldFee(address indexed recipient, uint256 amount);

    /* ============ Errors ============ */

    /// @notice Thrown when the Yield Vault is set to the zero address.
    error YieldVaultZeroAddress();

    /// @notice Thrown when the Owner is set to the zero address.
    error OwnerZeroAddress();

    /// @notice Thrown when a withdrawal of zero assets on the yield vault is attempted
    error WithdrawZeroAssets();

    /// @notice Thrown when no shares are being burnt during a withdrawal of assets
    error BurnZeroShares();

    /// @notice Thrown when zero assets are being deposited
    error DepositZeroAssets();

    /// @notice Thrown when zero shares are being minted
    error MintZeroShares();

    /// @notice Thrown if `totalAssets` is zero during a withdraw
    error ZeroTotalAssets();

    /// @notice Thrown when the Liquidation Pair being set is the zero address.
    error LPZeroAddress();

    /// @notice Thrown when `sweep` is called but no underlying assets are currently held by the Vault.
    error SweepZeroAssets();

    /// @notice Thrown during the liquidation process when the liquidation amount out is zero.
    error LiquidationAmountOutZero();

    /**
     * @notice Thrown during the liquidation process when the caller is not the liquidation pair contract.
     * @param caller The caller address
     * @param liquidationPair The LP address
     */
    error CallerNotLP(address caller, address liquidationPair);

    /**
     * @notice Thrown when the caller of a permit function is not the owner of the assets being permitted.
     * @param caller The address of the caller
     * @param owner The address of the owner
     */
    error PermitCallerNotOwner(address caller, address owner);

    /**
     * @notice Thrown when the caller that is withdrawing the yield fee is not the fee recipient.
     * @param caller The caller address
     * @param yieldFeeRecipient The yield fee recipient address
     */
    error CallerNotYieldFeeRecipient(address caller, address yieldFeeRecipient);

    /**
     * @notice Thrown when a permit call on the underlying asset failed to set the spending allowance.
     * @dev This is likely thrown when the underlying asset does not support permit, but has a fallback function.
     * @param owner The owner of the assets
     * @param spender The spender of the assets
     * @param amount The amount of assets permitted
     * @param allowance The allowance after the permit was called
     */
    error PermitAllowanceNotSet(address owner, address spender, uint256 amount, uint256 allowance);

    /**
     * @notice Thrown when the yield fee percentage being set is greater than 100%.
     * @param yieldFeePercentage The yield fee percentage in integer format
     * @param maxYieldFeePercentage The max yield fee percentage in integer format (this value is equal to 1 in decimal format)
     */
    error YieldFeePercentageGtPrecision(uint256 yieldFeePercentage, uint256 maxYieldFeePercentage);

    /**
     * @notice Thrown during the liquidation process when the token in is not the prize token.
     * @param tokenIn The provided tokenIn address
     * @param prizeToken The prize token address
     */
    error LiquidationTokenInNotPrizeToken(address tokenIn, address prizeToken);

    /**
     * @notice Thrown when the fee being withdrawn exceeds the available yield fee balance.
     * @param amount The fee being withdrawn
     * @param yieldFeeBalance The available yield fee balance
     */
    error AmountExceedsYieldFeeBalance(uint256 amount, uint256 yieldFeeBalance);

    /**
     * @notice Thrown during the liquidation process when the token out is not the vault asset.
     * @param tokenOut The provided tokenOut address
     * @param vaultAsset The vault asset address
     */
    error LiquidationTokenOutNotAsset(address tokenOut, address vaultAsset);

    /**
     * @notice Thrown during the liquidation process if the amount out is greater than the available yield.
     * @param amountOut The amount out
     * @param availableYield The available yield
     */
    error LiquidationAmountOutGtYield(uint256 amountOut, uint256 availableYield);

    /**
     * @notice Thrown when a deposit results in a state where the total assets are less than the total share supply.
     * @param totalAssets The total assets controlled by the vault
     * @param totalSupply The total shares minted by the vault
     */
    error LossyDeposit(uint256 totalAssets, uint256 totalSupply);

    /* ============ Modifiers ============ */

    /// @notice Requires the caller to be the liquidation pair.
    modifier onlyLiquidationPair() {
        if (msg.sender != liquidationPair) {
            revert CallerNotLP(msg.sender, liquidationPair);
        }
        _;
    }

    /// @notice Requires the caller to be the yield fee recipient.
    modifier onlyYieldFeeRecipient() {
        if (msg.sender != yieldFeeRecipient) {
            revert CallerNotYieldFeeRecipient(msg.sender, yieldFeeRecipient);
        }
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Vault constructor
     * @param name_ Name of the ERC20 share minted by the vault
     * @param symbol_ Symbol of the ERC20 share minted by the vault
     * @param yieldVault_ Address of the underlying ERC4626 vault in which assets are deposited to generate yield
     * @param prizePool_ Address of the PrizePool that computes prizes
     * @param claimer_ Address of the claimer
     * @param yieldFeeRecipient_ Address of the yield fee recipient
     * @param yieldFeePercentage_ Yield fee percentage
     * @param yieldBuffer_ Amount of yield to keep as a buffer
     * @param owner_ Address that will gain ownership of this contract
     */
    constructor(
        string memory name_,
        string memory symbol_,
        IERC4626 yieldVault_,
        PrizePool prizePool_,
        address claimer_,
        address yieldFeeRecipient_,
        uint32 yieldFeePercentage_,
        uint256 yieldBuffer_,
        address owner_
    ) TwabERC20(name_, symbol_, prizePool_.twabController()) Claimable(prizePool_, claimer_) Ownable(owner_) {
        if (address(yieldVault_) == address(0)) revert YieldVaultZeroAddress();
        if (owner_ == address(0)) revert OwnerZeroAddress();

        IERC20 asset_ = IERC20(yieldVault_.asset());
        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        _underlyingDecimals = success ? assetDecimals : 18;
        _asset = asset_;

        yieldVault = yieldVault_;
        yieldBuffer = yieldBuffer_;

        _setYieldFeeRecipient(yieldFeeRecipient_);
        _setYieldFeePercentage(yieldFeePercentage_);
    }

    /* ============ ERC20 Overrides ============ */

    /// @inheritdoc IERC20Metadata
    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return _underlyingDecimals;
    }

    /* ============ ERC4626 Implementation ============ */

    /// @inheritdoc IERC4626
    function asset() external view returns (address) {
        return address(_asset);
    }

    /// @inheritdoc IERC4626
    /// @dev TODO: add reasoning for inclusion of latent balance
    function totalAssets() public view returns (uint256) {
        return yieldVault.convertToAssets(yieldVault.balanceOf(address(this))) + _asset.balanceOf(address(this));
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 _assets) public pure returns (uint256) {
        /**
         * Shares represent how much an account has deposited. This is unlike most vaults that treat
         * shares as a direct proportional ownership of assets in the vault. This is because yield
         * goes to the prize pool or yield fee instead of accruing on deposits.
         */
        return _assets;
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 _shares) public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        uint256 _totalAssets = totalAssets();
        if (_totalAssets >= _totalSupply) {
            return _shares;
        } else {
            /**
             * If the vault controls less assets than what has been deposited a share will be worth a
             * proportional amount of the total assets. This can happen due to fees, slippage, or loss
             * of funds in the underlying yield vault.
             */
            return _shares.mulDiv(_totalAssets, _totalSupply, Math.Rounding.Down);
        }
    }

    /// @inheritdoc IERC4626
    /// @dev Considers the uint96 limit on total share supply in the TwabController
    /// @dev Returns zero if any deposit would result in a loss of assets
    /// @dev TODO: add reasoning for exclusion of latent balance
    function maxDeposit(address) public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        if (totalAssets() < _totalSupply) return 0;

        // the vault will never mint more than 1 share per asset, so no need to convert supply buffer to assets
        uint256 _supplyBuffer = type(uint96).max - _totalSupply;
        uint256 _maxDeposit;
        uint256 _latentBalance = _asset.balanceOf(address(this));
        uint256 _maxYieldVaultDeposit = yieldVault.maxDeposit(address(this));
        if (_latentBalance >= _maxYieldVaultDeposit) {
            return 0;
        } else {
            unchecked {
                _maxDeposit = _maxYieldVaultDeposit - _latentBalance;
            }
            return _supplyBuffer < _maxDeposit ? _supplyBuffer : _maxDeposit;
        }
    }

    /// @inheritdoc IERC4626
    /// @dev Returns the same value as `maxDeposit` since shares and assets are 1:1 on mint.
    function maxMint(address _owner) public view returns (uint256) {
        return maxDeposit(_owner);
    }

    /// @inheritdoc IERC4626
    /// @dev TODO: add reasoning for inclusion of latent balance
    function maxWithdraw(address _owner) public view returns (uint256) {
        uint256 _maxWithdraw = yieldVault.maxWithdraw(address(this)) + _asset.balanceOf(address(this));

        // the owner may receive less than 1 asset per share, so we must convert their balance here
        uint256 _ownerAssets = convertToAssets(balanceOf(_owner));
        return _ownerAssets < _maxWithdraw ? _ownerAssets : _maxWithdraw;
    }

    /// @inheritdoc IERC4626
    /// @dev TODO: add reasoning for inclusion of latent balance
    function maxRedeem(address _owner) public view returns (uint256) {
        // the owner will never receive more than 1 asset per share, so no need to convert max withdraw to shares
        uint256 _maxRedeem = yieldVault.maxWithdraw(address(this)) + _asset.balanceOf(address(this));
        uint256 _ownerShares = balanceOf(_owner);
        return _ownerShares < _maxRedeem ? _ownerShares : _maxRedeem;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 _assets) public pure returns (uint256) {
        // shares represent how many assets an account has deposited, so they are 1:1 on deposit
        return _assets;
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 _shares) public pure returns (uint256) {
        // shares represent how many assets an account has deposited, so they are 1:1 on mint
        return _shares;
    }

    /// @inheritdoc IERC4626
    /// @dev Reverts if `totalAssets` in the vault is zero
    function previewWithdraw(uint256 _assets) public view returns (uint256) {
        uint256 _totalAssets = totalAssets();

        // No withdrawals can occur if the vault controls no assets.
        if (_totalAssets == 0) revert ZeroTotalAssets();

        uint256 _totalSupply = totalSupply();
        if (_totalAssets >= _totalSupply) {
            return _assets;
        } else {
            // Follows the inverse conversion of `convertToAssets`
            return _assets.mulDiv(_totalSupply, _totalAssets, Math.Rounding.Up);
        }
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 _shares) public view returns (uint256) {
        return convertToAssets(_shares);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) external returns (uint256) {
        uint256 _shares = previewDeposit(_assets);
        _depositAndMint(msg.sender, _receiver, _assets, _shares);
        return _shares;
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) external returns (uint256) {
        uint256 _assets = previewMint(_shares);
        _depositAndMint(msg.sender, _receiver, _assets, _shares);
        return _assets;
    }

    /// @inheritdoc IERC4626
    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    ) external returns (uint256) {
        uint256 _shares = previewWithdraw(_assets);
        _burnAndWithdraw(msg.sender, _receiver, _owner, _shares, _assets);
        return _shares;
    }

    /// @inheritdoc IERC4626
    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    ) external returns (uint256) {
        uint256 _assets = previewRedeem(_shares);
        _burnAndWithdraw(msg.sender, _receiver, _owner, _shares, _assets);
        return _assets;
    }

    /* ============ Additional Deposit Flows ============ */

    /**
     * @notice Approve underlying asset with permit, deposit into the Vault and mint Vault shares to `_owner`.
     * @dev Can't be used to deposit on behalf of another user since `permit` does not accept a receiver parameter.
     *      Meaning that anyone could reuse the signature and pass an arbitrary receiver to this function.
     * @param _assets Amount of assets to approve and deposit
     * @param _owner Address of the owner depositing `_assets` and signing the permit
     * @param _deadline Timestamp after which the approval is no longer valid
     * @param _v V part of the secp256k1 signature
     * @param _r R part of the secp256k1 signature
     * @param _s S part of the secp256k1 signature
     * @return Amount of Vault shares minted to `_owner`.
     */
    function depositWithPermit(
        uint256 _assets,
        address _owner,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (uint256) {
        if (_owner != msg.sender) {
            revert PermitCallerNotOwner(msg.sender, _owner);
        }

        IERC20Permit(address(_asset)).permit(_owner, address(this), _assets, _deadline, _v, _r, _s);

        uint256 _allowance = _asset.allowance(_owner, address(this));
        if (_allowance != _assets) {
            revert PermitAllowanceNotSet(_owner, address(this), _assets, _allowance);
        }

        uint256 _shares = previewDeposit(_assets);
        _depositAndMint(_owner, _owner, _assets, _shares);
        return _shares;
    }

    /**
     * @notice Deposit assets into the Vault and delegate to the sponsorship address.
     * @param _assets Amount of assets to deposit
     * @return Amount of shares minted to caller.
     */
    function sponsor(uint256 _assets) external returns (uint256) {
        address _owner = msg.sender;

        uint256 _shares = previewDeposit(_assets);
        _depositAndMint(_owner, _owner, _assets, _shares);

        if (twabController.delegateOf(address(this), _owner) != SPONSORSHIP_ADDRESS) {
            twabController.sponsor(_owner);
        }

        emit Sponsor(_owner, _assets, _shares);

        return _shares;
    }

    /* ============ Yield Functions ============ */

    /**
     * @notice Total available yield on the vault.
     * @return The available yield balance
     */
    function availableYieldBalance() public view returns (uint256) {
        uint256 _totalAssets = totalAssets();
        uint256 _allocatedAssets = totalSupply() + yieldBuffer;
        if (_allocatedAssets >= _totalAssets) {
            return 0;
        } else {
            unchecked {
                return _totalAssets - _allocatedAssets;
            }
        }
    }

    /**
     * @notice The available yield fee balance that can be withdrawn by the fee recipient.
     * @dev Returns the full excess asset balance if the fee percentage has been set to
     * 100%. This enables LPs to be bypassed on 100% fee vaults.
     * @dev Limits the accrued fee to the amount of excess assets available in the vault.
     * This ensures that the yield fee is used to make depositors whole in the case of an
     * asset shortage.
     * @return The accrued yield fee balance.
     */
    function yieldFeeBalance() public view returns (uint256) {
        uint256 _availableYieldBalance = availableYieldBalance();
        if (yieldFeePercentage == FEE_PRECISION) {
            return _availableYieldBalance;
        } else {
            return _accruedYieldFee >= _availableYieldBalance ? _availableYieldBalance : _accruedYieldFee;
        }
    }

    /**
     * @notice Withdraws the yield fee to the yield fee recipient.
     * @dev Will revert if the caller is not the recipient.
     * @dev Will revert if the entire amount cannot be withdrawn due to yield vault limits.
     * @dev Will revert if the amount exceeds the available fee balance.
     */
    function withdrawYieldFee(uint256 _amount) external onlyYieldFeeRecipient {
        uint256 _yieldFeeBalance = yieldFeeBalance();

        if (_amount > _yieldFeeBalance) revert AmountExceedsYieldFeeBalance(_amount, _yieldFeeBalance);
        
        unchecked {
            _accruedYieldFee = _yieldFeeBalance - _amount;
        }
        _withdraw(yieldFeeRecipient, _amount);

        emit WithdrawYieldFee(msg.sender, _amount);
    }

    /* ============ LiquidationSource Functions ============ */

    /// @inheritdoc ILiquidationSource
    /// @dev Returns the withdrawable amount of the available yield minus any yield fees.
    function liquidatableBalanceOf(address _token) public view returns (uint256) {
        if (_token != address(_asset)) {
            return 0;
        } else {
            // TODO: Add rounding error explanation for subtracting yield buffer from the available yield balance.
            uint256 _maxLiquidation = availableYieldBalance() - _accruedYieldFee;
            uint256 _maxLiquidationMinusFees = _maxLiquidation - (_maxLiquidation * yieldFeePercentage) / FEE_PRECISION;
            uint256 _maxWithdraw = yieldVault.maxWithdraw(address(this));
            return _maxWithdraw < _maxLiquidationMinusFees ? _maxWithdraw : _maxLiquidationMinusFees;
        }
    }

    /// @inheritdoc ILiquidationSource
    function transferTokensOut(
        address,
        address _receiver,
        address _tokenOut,
        uint256 _amountOut
    ) external onlyLiquidationPair returns (bytes memory) {
        if (_tokenOut != address(_asset)) {
            revert LiquidationTokenOutNotAsset(_tokenOut, address(_asset));
        }
        if (_amountOut == 0) revert LiquidationAmountOutZero();

        uint256 _liquidatableYield = liquidatableBalanceOf(_tokenOut);
        uint32 _yieldFeePercentage = yieldFeePercentage;

        if (_amountOut > _liquidatableYield) {
            revert LiquidationAmountOutGtYield(_amountOut, _liquidatableYield);
        }

        // Distributes the specified yield fee percentage.
        // For instance, with a yield fee percentage of 20% and 8e18 assets being liquidated,
        // this calculation assigns 2e18 assets to the yield fee recipient.
        // `_amountOut` is the amount of assets being liquidated after accounting for the yield fee.
        if (_yieldFeePercentage != 0) {
            _accruedYieldFee += (_amountOut * FEE_PRECISION) / (FEE_PRECISION - _yieldFeePercentage) - _amountOut;
        }

        _withdraw(_receiver, _amountOut);

        return "";
    }

    /// @inheritdoc ILiquidationSource
    function verifyTokensIn(
        address _tokenIn,
        uint256 _amountIn,
        bytes calldata
    ) external onlyLiquidationPair {
        if (_tokenIn != address(prizePool.prizeToken())) {
            revert LiquidationTokenInNotPrizeToken(_tokenIn, address(prizePool.prizeToken()));
        }

        prizePool.contributePrizeTokens(address(this), _amountIn);
    }

    /// @inheritdoc ILiquidationSource
    function targetOf(address) external view returns (address) {
        return address(prizePool);
    }

    /// @inheritdoc ILiquidationSource
    function isLiquidationPair(
        address _tokenOut,
        address _liquidationPair
    ) external view returns (bool) {
        return _tokenOut == address(_asset) && _liquidationPair == liquidationPair;
    }

    /* ============ Setter Functions ============ */

    /**
     * @notice Set claimer.
     * @param _claimer Address of the claimer
     */
    function setClaimer(address _claimer) external onlyOwner {
        _setClaimer(_claimer);
    }

    /**
     * @notice Set liquidationPair.
     * @param _liquidationPair New liquidationPair address
     */
    function setLiquidationPair(address _liquidationPair) external onlyOwner {
        if (address(_liquidationPair) == address(0)) revert LPZeroAddress();

        liquidationPair = _liquidationPair;

        emit LiquidationPairSet(address(this), address(_liquidationPair));
    }

    /**
     * @notice Set yield fee percentage.
     * @dev Yield fee is defined on a scale from `0` to `FEE_PRECISION`, inclusive.
     * @param _yieldFeePercentage The new yield fee percentage to set
     */
    function setYieldFeePercentage(uint32 _yieldFeePercentage) external onlyOwner {
        _setYieldFeePercentage(_yieldFeePercentage);
    }

    /**
     * @notice Set fee recipient.
     * @param _yieldFeeRecipient Address of the fee recipient
     */
    function setYieldFeeRecipient(address _yieldFeeRecipient) external onlyOwner {
        _setYieldFeeRecipient(_yieldFeeRecipient);
    }

    /* ============ Internal Functions ============ */

    /**
     * @notice Fetch decimals of the underlying asset.
     * @dev Attempts to fetch the asset decimals. A return value of false indicates that the attempt failed in some way.
     * @param asset_ Address of the underlying asset
     * @return True if the attempt was successful, false otherwise
     * @return Number of token decimals
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

    /**
     * @notice Deposits assets to the yield vault and mints shares
     * @param _caller The caller of the deposit
     * @param _receiver The receiver of the deposit shares
     * @param _assets Amount of assets to deposit
     * @param _shares Amount of shares to mint
     * @dev Emits a `Deposit` event.
     * @dev Will revert if 0 shares are minted back to the receiver or if 0 assets are deposited.
     * @dev Will revert if the deposit may result in the loss of funds.
     */
    function _depositAndMint(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal {
        if (_shares == 0) revert MintZeroShares();
        if (_assets == 0) revert DepositZeroAssets();

        // If _asset is ERC777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook that is triggered after the transfer
        // calls the vault which is assumed to not be malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transferred and before the shares are minted, which is a valid state.

        _asset.safeTransferFrom(
            _caller,
            address(this),
            _assets
        );
        uint256 _assetsWithDust = _asset.balanceOf(address(this)); // try to sweep previously accumulated dust into the deposit as well
        _asset.approve(address(yieldVault), _assetsWithDust);

        uint256 _yieldVaultShares = yieldVault.previewDeposit(_assetsWithDust); // should include any fees charged against the deposit, so the following mint call should not fail
        uint256 _assetsUsed = yieldVault.mint(_yieldVaultShares, address(this));
        if (_assetsUsed != _assetsWithDust) {
            _asset.approve(address(yieldVault), 0); // set back to zero for weird tokens like USDT (and for gas refund)
        }

        _mint(_receiver, _shares);

        if (totalAssets() < totalSupply()) revert LossyDeposit(totalAssets(), totalSupply());

        emit Deposit(_caller, _receiver, _assets, _shares);
    }

    /**
     * @notice Burns shares and withdraws assets from the underlying yield vault.
     * @param _caller Address of the caller
     * @param _receiver Address of the receiver of the assets
     * @param _owner Owner of the shares
     * @param _shares Shares to burn
     * @param _assets Assets to withdraw
     * @dev Emits a `Withdraw` event.
     * @dev Will revert if 0 assets are withdrawn or if 0 shares are burned
     */
    function _burnAndWithdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _shares,
        uint256 _assets
    ) internal {
        if (_assets == 0) revert WithdrawZeroAssets();
        if (_shares == 0) revert BurnZeroShares();
        if (_caller != _owner) {
            _spendAllowance(_owner, _caller, _shares);
        }

        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(_owner, _shares);
        _withdraw(_receiver, _assets);

        emit Withdraw(_caller, _receiver, _owner, _assets, _shares);
    }

    /**
     * @notice Withdraws assets to the receiver while accounting for rounding errors.
     * @param _receiver The receiver of the assets
     * @param _assets The assets to withdraw
     */
    function _withdraw(address _receiver, uint256 _assets) internal {
        // The vault accumulates dust from rounding errors over time, so if we can fulfill the withdrawal from the
        // latent balance, we don't need to redeem any yield vault shares.
        uint256 _latentAssets = _asset.balanceOf(address(this));
        if (_assets > _latentAssets) {
            uint256 _yieldVaultShares = yieldVault.previewWithdraw(_assets - _latentAssets); // should include any fees and round up, so the following redeem call should return enough assets
            yieldVault.redeem(_yieldVaultShares, address(this), address(this)); // send assets to this contract so any leftover dust can be redeposited later
        }
        _asset.transfer(_receiver, _assets);
    }

    /**
     * @notice Set yield fee percentage.
     * @dev Yield fee is defined on a scale from `0` to `FEE_PRECISION`, inclusive.
     * @param _yieldFeePercentage The new yield fee percentage to set
     */
    function _setYieldFeePercentage(uint32 _yieldFeePercentage) internal {
        if (_yieldFeePercentage > FEE_PRECISION) {
            revert YieldFeePercentageGtPrecision(_yieldFeePercentage, FEE_PRECISION);
        }
        yieldFeePercentage = _yieldFeePercentage;
        emit YieldFeePercentageSet(_yieldFeePercentage);
    }

    /**
     * @notice Set yield fee recipient address.
     * @param _yieldFeeRecipient Address of the fee recipient
     */
    function _setYieldFeeRecipient(address _yieldFeeRecipient) internal {
        yieldFeeRecipient = _yieldFeeRecipient;
        emit YieldFeeRecipientSet(_yieldFeeRecipient);
    }

}
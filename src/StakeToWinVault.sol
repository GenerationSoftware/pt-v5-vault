// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC4626 } from "openzeppelin/interfaces/IERC4626.sol";
import { SafeERC20, IERC20Permit } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ERC20, IERC20, IERC20Metadata } from "openzeppelin/token/ERC20/ERC20.sol";

import { Claimable } from "./abstract/Claimable.sol";
import { TwabERC20 } from "./TwabERC20.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";

/// @dev The TWAB supply limit is the max number of shares that can be minted in the TWAB controller.
uint256 constant TWAB_SUPPLY_LIMIT = type(uint96).max;

/// @title  PoolTogether V5 Stake to Win Vault
/// @author G9 Software Inc.
contract StakeToWinVault is TwabERC20, Claimable, IERC4626 {
    using SafeERC20 for IERC20;

    ////////////////////////////////////////////////////////////////////////////////
    // Private Variables
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Address of the underlying asset used by the Vault.
    IERC20 private immutable _asset;

    /// @notice Underlying asset decimals.
    uint8 private immutable _underlyingDecimals;

    ////////////////////////////////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the underlying asset does not specify it's number of decimals.
    /// @param asset The underlying asset that was checked
    error FailedToGetAssetDecimals(address asset);

    /// @notice Thrown when the caller of a permit function is not the owner of the assets being permitted.
    /// @param caller The address of the caller
    /// @param owner The address of the owner
    error PermitCallerNotOwner(address caller, address owner);

    /// @notice Thrown when a withdrawal of zero assets on the yield vault is attempted
    error WithdrawZeroAssets();

    /// @notice Thrown when zero assets are being deposited
    error DepositZeroAssets();

    ////////////////////////////////////////////////////////////////////////////////
    // Constructor
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Vault constructor
    /// @param name_ Name of the ERC20 share minted by the vault
    /// @param symbol_ Symbol of the ERC20 share minted by the vault
    /// @param prizePool_ Address of the PrizePool that computes prizes
    /// @param claimer_ Address of the claimer
    constructor(
        string memory name_,
        string memory symbol_,
        address asset_,
        PrizePool prizePool_,
        address claimer_
    ) TwabERC20(name_, symbol_, prizePool_.twabController()) Claimable(prizePool_, claimer_) {
        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(IERC20(asset_));
        if (success) {
            _underlyingDecimals = assetDecimals;
        } else {
            revert FailedToGetAssetDecimals(asset_);
        }
        _asset = IERC20(asset_);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // ERC20 Overrides
    ////////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC20Metadata
    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return _underlyingDecimals;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // ERC4626 Implementation
    ////////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC4626
    function asset() external view returns (address) {
        return address(_asset);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 _assets) external pure returns (uint256) {
        return _assets;
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 _shares) external pure returns (uint256) {
        return _shares;
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address /* receiver */) external view returns (uint256) {
        return TWAB_SUPPLY_LIMIT - totalSupply();
    }

    /// @inheritdoc IERC4626
    function maxMint(address /* receiver */) external view returns (uint256) {
        return TWAB_SUPPLY_LIMIT - totalSupply();
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address _owner) external view returns (uint256) {
        return balanceOf(_owner);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address _owner) external view returns (uint256) {
        return balanceOf(_owner);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 _assets) external pure returns (uint256) {
        return _assets;
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 _shares) external pure returns (uint256) {
        return _shares;
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 _assets) external pure returns (uint256) {
        return _assets;
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 _shares) external pure returns (uint256) {
        return _shares;
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) external returns (uint256) {
        _deposit(msg.sender, _receiver, _assets);
        return _assets;
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) external returns (uint256) {
        _deposit(msg.sender, _receiver, _shares);
        return _shares;
    }

    /// @inheritdoc IERC4626
    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    ) external returns (uint256) {
        _withdraw(msg.sender, _receiver, _owner, _assets);
        return _assets;
    }

    /// @inheritdoc IERC4626
    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    ) external returns (uint256) {
        _withdraw(msg.sender, _receiver, _owner, _shares);
        return _shares;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Additional Deposit Flows
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Approve underlying asset with permit, deposit into the Vault and mint Vault shares to `_owner`.
    /// @dev Can't be used to deposit on behalf of another user since `permit` does not accept a receiver parameter,
    /// meaning that anyone could reuse the signature and pass an arbitrary receiver to this function.
    /// @param _assets Amount of assets to approve and deposit
    /// @param _owner Address of the owner depositing `_assets` and signing the permit
    /// @param _deadline Timestamp after which the approval is no longer valid
    /// @param _v V part of the secp256k1 signature
    /// @param _r R part of the secp256k1 signature
    /// @param _s S part of the secp256k1 signature
    /// @return Amount of Vault shares minted to `_owner`.
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

        // Skip the permit call if the allowance has already been set to exactly what is needed. This prevents
        // griefing attacks where the signature is used by another actor to complete the permit before this
        // function is executed.
        if (_asset.allowance(_owner, address(this)) != _assets) {
            IERC20Permit(address(_asset)).permit(_owner, address(this), _assets, _deadline, _v, _r, _s);
        }

        _deposit(_owner, _owner, _assets);
        return _assets;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internal Functions
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Fetch decimals of the underlying asset.
    /// @dev A return value of false indicates that the attempt failed in some way.
    /// @param asset_ Address of the underlying asset
    /// @return True if the attempt was successful, false otherwise
    /// @return Number of token decimals
    function _tryGetAssetDecimals(IERC20 asset_) internal view returns (bool, uint8) {
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

    /// @notice Deposits assets and mints shares
    /// @param _caller The caller of the deposit
    /// @param _receiver The receiver of the deposit shares
    /// @param _assets Amount of assets to deposit
    /// @dev Emits a `Deposit` event.
    /// @dev Will revert if 0 assets are deposited.
    function _deposit(address _caller, address _receiver, uint256 _assets) internal {
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
        _mint(_receiver, _assets);

        emit Deposit(_caller, _receiver, _assets, _assets);
    }

    /// @notice Burns shares and withdraws assets.
    /// @param _caller Address of the caller
    /// @param _receiver Address of the receiver of the assets
    /// @param _owner Owner of the shares
    /// @param _assets Assets to withdraw
    /// @dev Emits a `Withdraw` event.
    /// @dev Will revert if 0 assets are withdrawn.
    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assets
    ) internal {
        if (_assets == 0) revert WithdrawZeroAssets();
        if (_caller != _owner) {
            _spendAllowance(_owner, _caller, _assets);
        }

        // If _asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(_owner, _assets);
        _asset.safeTransfer(_receiver, _assets);

        emit Withdraw(_caller, _receiver, _owner, _assets, _assets);
    }

}
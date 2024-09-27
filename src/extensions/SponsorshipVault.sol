// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PrizeVault, IERC4626, PrizePool, ILiquidationSource } from "../PrizeVault.sol";

/// @title  PoolTogether V5 Sponsorship Vault
/// @author G9 Software Inc.
/// @notice Creates a prize vault that contributes prizes on behalf of a `contributionBeneficiary`
/// address rather than on behalf of itself. This allows someone to create a vault with the asset
/// and yield source of their choice in order to sponsor a different vault with the generated
/// yield.
contract SponsorshipVault is PrizeVault {

    /// @notice The address that yield is contributed to the prize pool on behalf of.
    address public immutable contributionBeneficiary;

    /// @notice Sponsorship vault constructor
    /// @param name_ Name of the ERC20 share minted by the vault
    /// @param symbol_ Symbol of the ERC20 share minted by the vault
    /// @param yieldVault_ Address of the underlying ERC4626 vault in which assets are deposited to generate yield
    /// @param prizePool_ Address of the PrizePool that computes prizes
    /// @param claimer_ Address of the claimer
    /// @param yieldFeeRecipient_ Address of the yield fee recipient
    /// @param yieldFeePercentage_ Yield fee percentage
    /// @param yieldBuffer_ Amount of yield to keep as a buffer
    /// @param owner_ Address that will gain ownership of this contract
    /// @param contributionBeneficiary_ Address that will be sponsored with prize pool contributions.
    constructor(
        string memory name_,
        string memory symbol_,
        IERC4626 yieldVault_,
        PrizePool prizePool_,
        address claimer_,
        address yieldFeeRecipient_,
        uint32 yieldFeePercentage_,
        uint256 yieldBuffer_,
        address owner_,
        address _extension,
        address contributionBeneficiary_
    ) PrizeVault(
        name_,
        symbol_,
        yieldVault_,
        prizePool_,
        claimer_,
        yieldFeeRecipient_,
        yieldFeePercentage_,
        yieldBuffer_,
        owner_,
        _extension
    ) {
        assert(contributionBeneficiary_ != address(0));
        assert(contributionBeneficiary_ != address(this));
        contributionBeneficiary = contributionBeneficiary_;
    }

    /// @inheritdoc ILiquidationSource
    /// @dev Contributes prize tokens on behalf of the `contributionBeneficiary` if set. Otherwise,
    /// contributes on behalf of this vault.
    function verifyTokensIn(
        address _tokenIn,
        uint256 _amountIn,
        bytes calldata /* transferTokensOutData */
    ) external override onlyLiquidationPair {
        address _prizeToken = address(prizePool.prizeToken());
        if (_tokenIn != _prizeToken) {
            revert LiquidationTokenInNotPrizeToken(_tokenIn, _prizeToken);
        }

        prizePool.contributePrizeTokens(contributionBeneficiary, _amountIn);
    }

}
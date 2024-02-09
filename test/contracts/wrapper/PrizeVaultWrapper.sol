// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PrizeVault, IERC4626, IERC20, PrizePool } from "../../../src/PrizeVault.sol";

contract PrizeVaultWrapper is PrizeVault {

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
    ) PrizeVault(name_, symbol_, yieldVault_, prizePool_, claimer_, yieldFeeRecipient_, yieldFeePercentage_, yieldBuffer_, owner_) { }

    function tryGetAssetDecimals(IERC20 asset_) public view returns (bool, uint8) {
        return _tryGetAssetDecimals(asset_);
    }

    function depositAndMint(address _caller, address _receiver, uint256 _assets, uint256 _shares) public {
        _depositAndMint(_caller, _receiver, _assets, _shares);
    }

    function burnAndWithdraw(address _caller, address _receiver, address _owner, uint256 _shares, uint256 _assets) public {
        _burnAndWithdraw(_caller, _receiver, _owner, _shares, _assets);
    }

}
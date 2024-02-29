// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PrizeVault } from "../../../src/PrizeVault.sol";
import { IERC20Permit } from "openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import { CommonBase } from "forge-std/Base.sol";

abstract contract Permit is CommonBase {

    bytes32 private constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    function _signPermit(
        IERC20Permit _underlyingAsset,
        PrizeVault _vault,
        uint256 _assets,
        address _owner,
        uint256 _ownerPrivateKey
    ) internal view returns (uint8 _v, bytes32 _r, bytes32 _s) {
        uint256 _nonce = _underlyingAsset.nonces(_owner);
        (_v, _r, _s) = vm.sign(
            _ownerPrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    _underlyingAsset.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(_PERMIT_TYPEHASH, _owner, address(_vault), _assets, _nonce, block.timestamp)
                    )
                )
            )
        );
    }
}
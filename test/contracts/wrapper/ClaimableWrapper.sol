// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Claimable, PrizePool } from "../../../src/abstract/Claimable.sol";

contract ClaimableWrapper is Claimable {

    constructor(PrizePool prizePool_, address claimer_) Claimable(prizePool_, claimer_) { }

    function setClaimer(address _claimer) public {
        _setClaimer(_claimer);
    }

}
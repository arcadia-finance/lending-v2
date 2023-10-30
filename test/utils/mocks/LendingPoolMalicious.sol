/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { RiskModule } from "lib/accounts-v2/src/RiskModule.sol";

contract LendingPoolMalicious {
    constructor() { }

    uint80 public maxInitiatorFee;

    function startLiquidation(
        address account,
        uint256 initiatorRewardWeight,
        uint256 penaltyWeight,
        uint256 closingRewardWeight
    ) external returns (uint80 maxInitiatorFee_) { }
}

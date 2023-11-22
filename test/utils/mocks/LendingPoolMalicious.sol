/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { RiskModule } from "lib/accounts-v2/src/RiskModule.sol";

contract LendingPoolMalicious {
    constructor() { }

    uint80 public maxInitiationFee;

    function startLiquidation(
        address account,
        uint256 initiatorRewardWeight,
        uint256 penaltyWeight,
        uint256 closingRewardWeight
    ) external returns (uint256 initiationReward, uint256 closingReward, uint256 liquidationPenalty) { }
}

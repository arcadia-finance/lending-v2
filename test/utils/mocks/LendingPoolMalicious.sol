/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { RiskModule } from "lib/accounts-v2/src/RiskModule.sol";

contract LendingPoolMalicious {
    constructor() { }

    function startLiquidation(address account) external { }
}

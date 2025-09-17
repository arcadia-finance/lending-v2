/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LendingPoolGuardian } from "../../../src/guardians/LendingPoolGuardian.sol";

contract LendingPoolGuardianExtension is LendingPoolGuardian {
    constructor(address owner_) LendingPoolGuardian(owner_) { }

    function setPauseTimestamp(uint256 pauseTimestamp_) public {
        pauseTimestamp = uint96(pauseTimestamp_);
    }

    function setFlags(
        bool repayPaused_,
        bool withdrawPaused_,
        bool borrowPaused_,
        bool depositPaused_,
        bool liquidationPaused_
    ) public {
        repayPaused = repayPaused_;
        withdrawPaused = withdrawPaused_;
        borrowPaused = borrowPaused_;
        depositPaused = depositPaused_;
        liquidationPaused = liquidationPaused_;
    }
}

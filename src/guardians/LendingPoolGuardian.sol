/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity 0.8.19;

import { BaseGuardian } from "../../lib/accounts-v2/src/guardians/BaseGuardian.sol";

/**
 * @title LendingPool Guardian
 * @author Pragma Labs
 * @notice This module provides the logic for the LendingPool that allows authorized accounts to trigger an emergency stop.
 */
abstract contract LendingPoolGuardian is BaseGuardian {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag indicating if the repay() function is paused.
    bool internal repayPaused;
    // Flag indicating if the withdraw() function is paused.
    bool public withdrawPaused;
    // Flag indicating if the borrow() function is paused.
    bool internal borrowPaused;
    // Flag indicating if the deposit() function is paused.
    bool public depositPaused;
    // Flag indicating if the liquidation() function is paused.
    bool internal liquidationPaused;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event PauseUpdate(
        bool repayPauseUpdate,
        bool withdrawPauseUpdate,
        bool borrowPauseUpdate,
        bool depositPauseUpdate,
        bool liquidationPauseUpdate
    );

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    // Thrown when the contract is paused for a certain action.
    error LendingPoolGuardian_FunctionIsPaused();

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for repay.
     * It throws if repay is paused.
     */
    modifier whenRepayNotPaused() {
        if (repayPaused) revert LendingPoolGuardian_FunctionIsPaused();
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for withdraw.
     * It throws if withdraw is paused.
     */
    modifier whenWithdrawNotPaused() {
        if (withdrawPaused) revert LendingPoolGuardian_FunctionIsPaused();
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for borrow.
     * It throws if borrow is paused.
     */
    modifier whenBorrowNotPaused() {
        if (borrowPaused) revert LendingPoolGuardian_FunctionIsPaused();
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for deposit.
     * It throws if deposit is paused.
     */
    modifier whenDepositNotPaused() {
        if (depositPaused) revert LendingPoolGuardian_FunctionIsPaused();
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for liquidation.
     * It throws if liquidation is paused.
     */
    modifier whenLiquidationNotPaused() {
        if (liquidationPaused) revert LendingPoolGuardian_FunctionIsPaused();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() { }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc BaseGuardian
     */
    function pause() external override onlyGuardian {
        require(block.timestamp > pauseTimestamp + 32 days, "G_P: Cannot pause");
        repayPaused = true;
        withdrawPaused = true;
        borrowPaused = true;
        depositPaused = true;
        liquidationPaused = true;
        pauseTimestamp = block.timestamp;

        emit PauseUpdate(true, true, true, true, true);
    }

    /**
     * @notice This function is used to unpause one or more flags.
     * @param repayPaused_ false when repay functionality should be unPaused.
     * @param withdrawPaused_ false when withdraw functionality should be unPaused.
     * @param borrowPaused_ false when borrow functionality should be unPaused.
     * @param depositPaused_ false when deposit functionality should be unPaused.
     * @param liquidationPaused_ false when liquidation functionality should be unPaused.
     * @dev This function can unPause repay, withdraw, borrow, and deposit individually.
     * @dev Can only update flags from paused (true) to unPaused (false), cannot be used the other way around
     * (to set unPaused flags to paused).
     */
    function unPause(
        bool repayPaused_,
        bool withdrawPaused_,
        bool borrowPaused_,
        bool depositPaused_,
        bool liquidationPaused_
    ) external onlyOwner {
        repayPaused = repayPaused && repayPaused_;
        withdrawPaused = withdrawPaused && withdrawPaused_;
        borrowPaused = borrowPaused && borrowPaused_;
        depositPaused = depositPaused && depositPaused_;
        liquidationPaused = liquidationPaused && liquidationPaused_;

        emit PauseUpdate(repayPaused, withdrawPaused, borrowPaused, depositPaused, liquidationPaused);
    }

    /**
     * @inheritdoc BaseGuardian
     */
    function unPause() external override {
        require(block.timestamp > pauseTimestamp + 30 days, "G_UP: Cannot unPause");
        repayPaused = false;
        withdrawPaused = false;
        borrowPaused = false;
        depositPaused = false;
        liquidationPaused = false;

        emit PauseUpdate(false, false, false, false, false);
    }
}

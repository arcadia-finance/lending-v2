/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity 0.8.19;

import { BaseGuardian } from "../../lib/accounts-v2/src/guardians/BaseGuardian.sol";

/**
 * @title LendingPool Guardian.
 * @author Pragma Labs
 * @notice Logic inherited by the LendingPool that allows an authorized guardian to trigger an emergency stop.
 */
abstract contract LendingPoolGuardian is BaseGuardian {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag indicating if the repay() function is paused.
    bool public repayPaused;
    // Flag indicating if the withdraw() function is paused.
    bool public withdrawPaused;
    // Flag indicating if the borrow() function is paused.
    bool public borrowPaused;
    // Flag indicating if the deposit() function is paused.
    bool public depositPaused;
    // Flag indicating if the liquidation() function is paused.
    bool public liquidationPaused;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event PauseFlagsUpdated(
        bool repayPauseFlagsUpdated,
        bool withdrawPauseFlagsUpdated,
        bool borrowPauseFlagsUpdated,
        bool depositPauseFlagsUpdated,
        bool liquidationPauseFlagsUpdated
    );

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for repay.
     * It throws if repay is paused.
     */
    modifier whenRepayNotPaused() {
        if (repayPaused) revert FunctionIsPaused();
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for withdraw.
     * It throws if withdraw is paused.
     */
    modifier whenWithdrawNotPaused() {
        if (withdrawPaused) revert FunctionIsPaused();
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for borrow.
     * It throws if borrow is paused.
     */
    modifier whenBorrowNotPaused() {
        if (borrowPaused) revert FunctionIsPaused();
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for deposit.
     * It throws if deposit is paused.
     */
    modifier whenDepositNotPaused() {
        if (depositPaused) revert FunctionIsPaused();
        _;
    }

    /**
     * @dev This modifier is used to restrict access to certain functions when the contract is paused for liquidation.
     * It throws if liquidation is paused.
     */
    modifier whenLiquidationNotPaused() {
        if (liquidationPaused) revert FunctionIsPaused();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc BaseGuardian
     * @dev This function can be called by the guardian to pause all functionality in the event of an emergency.
     */
    function pause() external override onlyGuardian {
        if (block.timestamp <= pauseTimestamp + 32 days) revert CannotPause();
        pauseTimestamp = block.timestamp;

        emit PauseFlagsUpdated(
            repayPaused = true,
            withdrawPaused = true,
            borrowPaused = true,
            depositPaused = true,
            liquidationPaused = true
        );
    }

    /**
     * @notice This function is used to unpause one or more flags.
     * @param repayPaused_ False when repay functionality should be unPaused.
     * @param withdrawPaused_ False when withdraw functionality should be unPaused.
     * @param borrowPaused_ False when borrow functionality should be unPaused.
     * @param depositPaused_ False when deposit functionality should be unPaused.
     * @param liquidationPaused_ False when liquidation functionality should be unPaused.
     * @dev This function can unPause repay, withdraw, borrow, and deposit individually.
     * @dev Can only update flags from paused (true) to unPaused (false), cannot be used the other way around
     * (to set unPaused flags to paused).
     */
    function unpause(
        bool repayPaused_,
        bool withdrawPaused_,
        bool borrowPaused_,
        bool depositPaused_,
        bool liquidationPaused_
    ) external onlyOwner {
        emit PauseFlagsUpdated(
            repayPaused = repayPaused && repayPaused_,
            withdrawPaused = withdrawPaused && withdrawPaused_,
            borrowPaused = borrowPaused && borrowPaused_,
            depositPaused = depositPaused && depositPaused_,
            liquidationPaused = liquidationPaused && liquidationPaused_
        );
    }

    /**
     * @inheritdoc BaseGuardian
     * @dev This function can be called by the guardian to unpause all functionality.
     */
    function unpause() external override {
        if (block.timestamp <= pauseTimestamp + 30 days) revert CannotUnpause();

        emit PauseFlagsUpdated(
            repayPaused = false,
            withdrawPaused = false,
            borrowPaused = false,
            depositPaused = false,
            liquidationPaused = false
        );
    }
}

/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { BaseGuardian, GuardianErrors } from "../../lib/accounts-v2/src/guardians/BaseGuardian.sol";

/**
 * @title LendingPool Guardian.
 * @author Pragma Labs
 * @notice Logic inherited by the LendingPool that allows:
 * - An authorized guardian to trigger an emergency stop.
 * - The protocol owner to unpause functionalities one-by-one.
 * - Anyone to unpause all functionalities after a fixed cool-down period.
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
     * @dev Throws if the repay functionality is paused.
     */
    modifier whenRepayNotPaused() {
        if (repayPaused) revert GuardianErrors.FunctionIsPaused();
        _;
    }

    /**
     * @dev Throws if the withdraw functionality is paused.
     */
    modifier whenWithdrawNotPaused() {
        if (withdrawPaused) revert GuardianErrors.FunctionIsPaused();
        _;
    }

    /**
     * @dev Throws if the borrow functionality is paused.
     */
    modifier whenBorrowNotPaused() {
        if (borrowPaused) revert GuardianErrors.FunctionIsPaused();
        _;
    }

    /**
     * @dev Throws if the deposit functionality is paused.
     */
    modifier whenDepositNotPaused() {
        if (depositPaused) revert GuardianErrors.FunctionIsPaused();
        _;
    }

    /**
     * @dev Throws if the liquidation functionality is paused.
     */
    modifier whenLiquidationNotPaused() {
        if (liquidationPaused) revert GuardianErrors.FunctionIsPaused();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                            PAUSING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @inheritdoc BaseGuardian
     * @dev This function will pause the functionality to:
     * - Repay debt.
     * - Withdraw liquidity.
     * - Borrow.
     * - Deposit liquidity.
     * - Liquidate positions.
     */
    function pause() external override onlyGuardian afterCoolDownOf(32 days) {
        pauseTimestamp = uint96(block.timestamp);

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
     * @dev This function will unpause the functionality to:
     * - Repay debt.
     * - Withdraw liquidity.
     * - Liquidate positions.
     */
    function unpause() external override afterCoolDownOf(30 days) {
        emit PauseFlagsUpdated(
            repayPaused = false, withdrawPaused = false, borrowPaused, depositPaused, liquidationPaused = false
        );
    }
}

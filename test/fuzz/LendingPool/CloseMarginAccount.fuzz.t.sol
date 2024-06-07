/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { LendingPoolErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "closeMarginAccount" of contract "LendingPool".
 */
contract CloseMarginAccount_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_closeMarginAccount_OpenPositionNonZero(uint112 amountLoaned) public {
        // Given: collateralValue is smaller than maxExposure.
        amountLoaned = uint112(bound(amountLoaned, 0, type(uint112).max - 1));

        // Given: an Account has taken out debt
        vm.assume(amountLoaned > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);

        depositTokenInAccount(account, mockERC20.stable1, amountLoaned);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), users.accountOwner, emptyBytes3);

        // When: the margin account is tried to be closed
        vm.expectRevert(LendingPoolErrors.OpenPositionNonZero.selector);
        pool.closeMarginAccount(address(account));
    }

    function testFuzz_Success_closeMarginAccount_OpenPositionIsZero(address account_) public {
        // Given: account does not have an open position
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(account));

        // When: the margin account is tried to be closed
        pool.closeMarginAccount(account_);

        // Then: the margin account should be closed
        assertEq(pool.getOpenPosition(account_), 0);

        // Note: Since the closeMarginAccount does not do state changes, we cannot check if the account is closed.
    }
}

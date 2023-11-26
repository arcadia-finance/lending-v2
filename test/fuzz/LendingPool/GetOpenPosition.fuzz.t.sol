/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getOpenPosition" of contract "LendingPool".
 */
contract GetOpenPosition_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getOpenPosition(uint112 amountLoaned) public {
        // Given: collateralValue is smaller than maxExposure.
        amountLoaned = uint112(bound(amountLoaned, 0, type(uint112).max - 1));

        // Given: an Account has taken out debt
        vm.assume(amountLoaned > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // When: the Account fetches its open position
        uint256 openPosition = pool.getOpenPosition(address(proxyAccount));

        // Then: The open position should equal the amount loaned
        assertEq(amountLoaned, openPosition);
    }
}

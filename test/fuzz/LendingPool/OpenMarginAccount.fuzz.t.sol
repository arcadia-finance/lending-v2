/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "openMarginAccount" of contract "LendingPool".
 */
contract OpenMarginAccount_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_openMarginAccount_InvalidAccountVersion(uint256 accountVersion, uint96 minimumMargin)
        public
    {
        // Given: accountVersion is invalid
        vm.startPrank(users.creatorAddress);
        pool.setAccountVersion(accountVersion, false);
        pool.setMinimumMargin(minimumMargin);
        vm.stopPrank();

        // When: Account opens a margin proxyAccount
        (bool success, address numeraire, address liquidator_, uint256 minimumMargin_) =
            pool.openMarginAccount(accountVersion);

        // Then: openMarginAccount should return false and the zero address
        assertTrue(!success);
        assertEq(address(0), numeraire);
        assertEq(address(0), liquidator_);
        assertEq(0, minimumMargin_);
    }

    function testFuzz_Success_openMarginAccount_ValidAccountVersion(uint256 accountVersion, uint96 minimumMargin)
        public
    {
        // Given: accountVersion is valid
        vm.startPrank(users.creatorAddress);
        pool.setAccountVersion(accountVersion, true);
        pool.setMinimumMargin(minimumMargin);
        vm.stopPrank();

        // When: Account opens a margin proxyAccount
        (bool success, address numeraire, address liquidator_, uint256 minimumMargin_) =
            pool.openMarginAccount(accountVersion);

        // Then: openMarginAccount should return success and correct contract addresses
        assertTrue(success);
        assertEq(address(mockERC20.stable1), numeraire);
        assertEq(address(liquidator), liquidator_);
        assertEq(minimumMargin, minimumMargin_);
    }
}

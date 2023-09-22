/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "openMarginAccount" of contract "LendingPool".
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
    function testSuccess_openMarginAccount_InvalidAccountVersion(uint256 accountVersion, uint96 fixedLiquidationCost)
        public
    {
        // Given: accountVersion is invalid
        vm.startPrank(users.creatorAddress);
        pool.setAccountVersion(accountVersion, false);
        pool.setFixedLiquidationCost(fixedLiquidationCost);
        vm.stopPrank();

        // When: Account opens a margin proxyAccount
        (bool success, address baseCurrency, address liquidator_, uint256 fixedLiquidationCost_) =
            pool.openMarginAccount(accountVersion);

        // Then: openMarginAccount should return false and the zero address
        assertTrue(!success);
        assertEq(address(0), baseCurrency);
        assertEq(address(0), liquidator_);
        assertEq(0, fixedLiquidationCost_);
    }

    function testSuccess_openMarginAccount_ValidAccountVersion(uint256 accountVersion, uint96 fixedLiquidationCost)
        public
    {
        // Given: accountVersion is valid
        vm.startPrank(users.creatorAddress);
        pool.setAccountVersion(accountVersion, true);
        pool.setFixedLiquidationCost(fixedLiquidationCost);
        vm.stopPrank();

        // When: Account opens a margin proxyAccount
        (bool success, address baseCurrency, address liquidator_, uint256 fixedLiquidationCost_) =
            pool.openMarginAccount(accountVersion);

        // Then: openMarginAccount should return success and correct contract addresses
        assertTrue(success);
        assertEq(address(mockERC20.stable1), baseCurrency);
        assertEq(address(liquidator), liquidator_);
        assertEq(fixedLiquidationCost, fixedLiquidationCost_);
    }
}

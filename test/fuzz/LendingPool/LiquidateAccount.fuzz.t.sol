/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "liquidateAccount" of contract "LendingPool".
 */

contract LiquidateAccount_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_liquidateAccount_Paused(address liquidationInitiator, address account_) public {
        vm.warp(35 days);
        vm.prank(users.guardian);
        pool.pause();

        vm.expectRevert(LendingPoolGuardian_FunctionIsPaused.selector);
        vm.prank(liquidationInitiator);
        pool.liquidateAccount(account_);
    }

    function testFuzz_Revert_liquidateAccount_NoDebt(address liquidationInitiator, address account_) public {
        // Given: Account has no debt

        // When: liquidationInitiator tries to liquidate the proxyAccount
        // Then: liquidateAccount should revert with "LP_LV: Not a Account with debt"
        vm.startPrank(liquidationInitiator);
        vm.expectRevert(LendingPool_IsNotAnAccountWithDebt.selector);
        pool.liquidateAccount(account_);
        vm.stopPrank();
    }

    function testFuzz_Success_liquidateAccount_NoOngoingAuctions(address liquidationInitiator, uint128 amountLoaned)
        public
    {
        // Given: Account has debt
        vm.assume(amountLoaned > 0);
        vm.assume(amountLoaned <= type(uint128).max - 1); // No overflow when debt is increased
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(amountLoaned + 1);

        // When: Liquidator calls liquidateAccount
        vm.prank(liquidationInitiator);
        pool.liquidateAccount(address(proxyAccount));

        // Then: liquidationInitiator should be set
        assertEq(pool.getLiquidationInitiator(address(proxyAccount)), liquidationInitiator);

        // Then: The debt of the Account should be decreased with amountLiquidated
        assertEq(debt.balanceOf(address(proxyAccount)), 0);
        assertEq(debt.totalSupply(), 0);

        // Then: auctionsInProgress should increase
        assertEq(pool.getAuctionsInProgress(), 1);
        // and the most junior tranche should be locked
        // ToDo: Check for emit
        assertTrue(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testFuzz_Success_liquidateAccount_WithOngoingAuctions(
        address liquidationInitiator,
        uint128 amountLoaned,
        uint16 auctionsInProgress
    ) public {
        // Given: Account has debt
        vm.assume(amountLoaned > 0);
        vm.assume(amountLoaned <= type(uint128).max - 1); // No overflow when debt is increased
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(amountLoaned + 1);

        //And: an auction is ongoing
        vm.assume(auctionsInProgress > 0);
        vm.assume(auctionsInProgress < type(uint16).max);
        pool.setAuctionsInProgress(auctionsInProgress);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator calls liquidateAccount
        vm.prank(liquidationInitiator);
        pool.liquidateAccount(address(proxyAccount));

        // Then: liquidationInitiator should be set
        assertEq(pool.getLiquidationInitiator(address(proxyAccount)), liquidationInitiator);

        // Then: The debt of the Account should be decreased with amountLiquidated
        assertEq(debt.balanceOf(address(proxyAccount)), 0);
        assertEq(debt.totalSupply(), 0);

        // Then: auctionsInProgress should increase
        assertEq(pool.getAuctionsInProgress(), auctionsInProgress + 1);
        // and the most junior tranche should be locked
        assertTrue(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }
}

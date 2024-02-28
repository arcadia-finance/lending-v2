/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { AssetValuationLib } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "syncInterests" of contract "LendingPool".
 */
contract SyncInterests_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_syncInterests(
        uint24 deltaTimestamp,
        uint128 realisedDebt,
        uint120 realisedLiquidity,
        uint80 interestRate
    ) public {
        vm.assume(realisedDebt <= type(uint256).max / AssetValuationLib.ONE_4); // No overflow Risk Module
        // Given: deltaTimestamp than 5 years, realisedDebt than 3402823669209384912995114146594816 and bigger than 0
        vm.assume(deltaTimestamp <= 5 * 365 * 24 * 60 * 60);
        //5 year
        vm.assume(interestRate <= 10 * 10 ** 18);
        //1000%
        vm.assume(realisedDebt <= type(uint128).max / (10 ** 5));
        //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816
        vm.assume(realisedDebt > 0);
        vm.assume(realisedDebt <= realisedLiquidity);

        // And: the users.accountOwner takes realisedDebt debt
        depositTokenInAccount(proxyAccount, mockERC20.stable1, realisedDebt);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(realisedLiquidity, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(realisedDebt, address(proxyAccount), address(proxyAccount), emptyBytes3);

        // And: deltaTimestamp have passed
        uint256 start_timestamp = block.timestamp;
        vm.warp(start_timestamp + deltaTimestamp);

        // When: Interests are synced
        vm.prank(users.creatorAddress);
        pool.setInterestRate(interestRate);
        pool.syncInterests();

        uint256 interests = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);

        // Then: Total redeemable interest of LP providers and total open debt of borrowers should increase with interests
        assertEq(pool.totalLiquidity(), realisedLiquidity + interests);
        assertEq(debt.maxWithdraw(address(proxyAccount)), realisedDebt + interests);
        assertEq(debt.maxRedeem(address(proxyAccount)), realisedDebt);
        assertEq(debt.totalAssets(), realisedDebt + interests);
        assertEq(pool.getLastSyncedTimestamp(), start_timestamp + deltaTimestamp);
    }
}

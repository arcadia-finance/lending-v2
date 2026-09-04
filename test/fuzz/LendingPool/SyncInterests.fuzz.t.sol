/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { AssetValuationLib } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "syncInterests" of contract "LendingPool".
 */
// forge-lint: disable-next-item(unsafe-typecast)
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
        // Highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816.
        realisedDebt = uint128(bound(realisedDebt, 1, type(uint128).max / (10 ** 5)));
        // Given: deltaTimestamp than 5 years, realisedDebt than 3402823669209384912995114146594816 and bigger than 0
        //5 year
        interestRate = uint80(bound(interestRate, 0, 10 * 10 ** 18));
        //1000%
        realisedLiquidity = uint120(bound(realisedLiquidity, realisedDebt, type(uint120).max));

        // And: the users.accountOwner takes realisedDebt debt
        depositErc20InAccount(account, mockERC20.stable1, realisedDebt);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(realisedLiquidity, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(realisedDebt, address(account), address(account), emptyBytes3);

        // And: deltaTimestamp have passed
        uint256 startTimestamp = block.timestamp;
        vm.warp(startTimestamp + deltaTimestamp);

        // When: Interests are synced
        vm.prank(users.owner);
        pool.setInterestRate(interestRate);
        pool.syncInterests();

        uint256 interests = calcUnrealisedDebtChecked(interestRate, deltaTimestamp, realisedDebt);

        // Then: Total redeemable interest of LP providers and total open debt of borrowers should increase with interests
        assertEq(pool.totalLiquidity(), realisedLiquidity + interests);
        assertEq(debt.maxWithdraw(address(account)), realisedDebt + interests);
        assertEq(debt.maxRedeem(address(account)), realisedDebt);
        assertEq(debt.totalAssets(), realisedDebt + interests);
        assertEq(pool.getLastSyncedTimestamp(), startTimestamp + deltaTimestamp);
    }
}

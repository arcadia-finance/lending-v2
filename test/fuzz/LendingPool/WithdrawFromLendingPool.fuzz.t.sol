/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "withdrawFromLendingPool" of contract "LendingPool".
 */
contract WithdrawFromLendingPool_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_withdrawFromLendingPool_Unauthorised(
        uint128 assetsWithdrawn,
        address receiver,
        address unprivilegedAddress
    ) public {
        vm.assume(unprivilegedAddress != address(srTranche));
        vm.assume(assetsWithdrawn > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(assetsWithdrawn, users.liquidityProvider);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(AmountExceedsBalance.selector);
        pool.withdrawFromLendingPool(assetsWithdrawn, receiver);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdrawFromLendingPool_InsufficientAssets(
        uint128 assetsDeposited,
        uint128 assetsWithdrawn,
        address receiver
    ) public {
        vm.assume(assetsDeposited < assetsWithdrawn);

        vm.startPrank(address(srTranche));
        pool.depositInLendingPool(assetsDeposited, users.liquidityProvider);

        vm.expectRevert(AmountExceedsBalance.selector);
        pool.withdrawFromLendingPool(assetsWithdrawn, receiver);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdrawFromLendingPool_Paused(
        uint128 assetsDeposited,
        uint128 assetsWithdrawn,
        address receiver
    ) public {
        vm.assume(receiver != address(pool));
        vm.assume(receiver != users.liquidityProvider);
        vm.assume(assetsDeposited >= assetsWithdrawn);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(assetsDeposited, users.liquidityProvider);

        vm.warp(35 days);
        vm.prank(users.guardian);
        pool.pause();

        vm.expectRevert(FunctionIsPaused.selector);
        vm.prank(address(srTranche));
        pool.withdrawFromLendingPool(assetsWithdrawn, receiver);
    }

    function testFuzz_Success_withdrawFromLendingPool(
        uint128 assetsDeposited,
        uint128 assetsWithdrawn,
        address receiver
    ) public {
        vm.assume(receiver != address(pool));
        vm.assume(receiver != users.liquidityProvider);
        vm.assume(assetsDeposited >= assetsWithdrawn);

        vm.startPrank(address(srTranche));
        pool.depositInLendingPool(assetsDeposited, users.liquidityProvider);

        pool.withdrawFromLendingPool(assetsWithdrawn, receiver);
        vm.stopPrank();

        assertEq(pool.liquidityOf(address(srTranche)), assetsDeposited - assetsWithdrawn);
        assertEq(pool.totalLiquidity(), assetsDeposited - assetsWithdrawn);
        assertEq(mockERC20.stable1.balanceOf(address(pool)), assetsDeposited - assetsWithdrawn);
        assertEq(mockERC20.stable1.balanceOf(receiver), assetsWithdrawn);
    }
}

/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "depositInLendingPool" of contract "LendingPool".
 */
contract DepositInLendingPool_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_depositInLendingPool_NonTranche(address unprivilegedAddress, uint128 assets, address from)
        public
    {
        vm.assume(unprivilegedAddress != address(jrTranche));
        vm.assume(unprivilegedAddress != address(srTranche));

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(Unauthorized.selector);
        pool.depositInLendingPool(assets, from);
        vm.stopPrank();
    }

    function testFuzz_Revert_depositInLendingPool_NotApproved(uint128 amount) public {
        vm.assume(amount > 0);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), 0);

        vm.startPrank(address(srTranche));
        vm.expectRevert("TRANSFER_FROM_FAILED");
        pool.depositInLendingPool(amount, users.liquidityProvider);
        vm.stopPrank();
    }

    function testFuzz_Revert_depositInLendingPool_Paused(uint128 amount0, uint128 amount1) public {
        vm.assume(amount0 <= type(uint128).max - amount1);

        vm.warp(35 days);
        vm.prank(users.guardian);
        pool.pause();

        vm.expectRevert(FunctionIsPaused.selector);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amount0, users.liquidityProvider);

        vm.expectRevert(FunctionIsPaused.selector);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(amount1, users.liquidityProvider);
    }

    function testFuzz_Success_depositInLendingPool_FirstDepositByTranche(uint256 amount) public {
        vm.assume(amount <= type(uint128).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amount, users.liquidityProvider);

        assertEq(pool.liquidityOf(address(srTranche)), amount);
        assertEq(pool.totalLiquidity(), amount);
        assertEq(mockERC20.stable1.balanceOf(address(pool)), amount);
    }

    function testFuzz_Success_depositInLendingPool_MultipleDepositsByTranches(uint128 amount0, uint128 amount1)
        public
    {
        vm.assume(amount0 <= type(uint128).max - amount1);

        uint256 totalAmount = uint256(amount0) + uint256(amount1);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amount0, users.liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(amount1, users.liquidityProvider);

        assertEq(pool.liquidityOf(address(jrTranche)), amount1);
        assertEq(pool.totalLiquidity(), totalAmount);
        assertEq(mockERC20.stable1.balanceOf(address(pool)), totalAmount);
    }
}

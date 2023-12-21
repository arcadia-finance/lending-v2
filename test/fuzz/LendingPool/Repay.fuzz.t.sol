/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { AssetValuationLib } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "repay" of contract "LendingPool".
 */
contract Repay_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_repay_InsufficientFunds(uint112 amountLoaned, uint256 availableFunds, address sender)
        public
    {
        // Given: collateralValue is smaller than maxExposure.
        amountLoaned = uint112(bound(amountLoaned, 0, type(uint112).max - 1));

        vm.assume(amountLoaned > availableFunds);
        vm.assume(amountLoaned <= type(uint256).max / AssetValuationLib.ONE_4); // No overflow Risk Module
        vm.assume(availableFunds > 0);
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(proxyAccount));

        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(sender, availableFunds);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.startPrank(sender);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        pool.repay(amountLoaned, address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Revert_repay_Paused(uint112 amountLoaned, uint256 availableFunds, address sender) public {
        // Given: collateralValue is smaller than maxExposure.
        amountLoaned = uint112(bound(amountLoaned, 0, type(uint112).max - 1));

        vm.assume(amountLoaned > availableFunds);
        vm.assume(amountLoaned <= type(uint256).max / AssetValuationLib.ONE_4); // No overflow Risk Module
        vm.assume(availableFunds > 0);
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(proxyAccount));
        vm.warp(35 days);

        // Update oracle to avoid InactiveOracle().
        vm.prank(users.defaultTransmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));

        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(sender, availableFunds);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.prank(users.guardian);
        pool.pause();

        vm.startPrank(sender);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.expectRevert(FunctionIsPaused.selector);
        pool.repay(amountLoaned, address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Revert_repay_NonAccount(
        uint128 availableFunds,
        uint256 amountRepaid,
        address sender,
        address nonAccount
    ) public {
        vm.assume(nonAccount != address(proxyAccount));
        vm.assume(availableFunds > amountRepaid);
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != address(proxyAccount));
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(sender, availableFunds);

        vm.startPrank(sender);
        vm.expectRevert(ZeroShares.selector);
        pool.repay(amountRepaid, nonAccount);
        vm.stopPrank();
    }

    function testFuzz_Success_repay_AmountInferiorLoan(uint112 amountLoaned, uint256 amountRepaid, address sender)
        public
    {
        // Given: collateralValue is smaller than maxExposure.
        amountLoaned = uint112(bound(amountLoaned, 0, type(uint112).max - 1));

        vm.assume(amountLoaned > amountRepaid);
        vm.assume(amountRepaid > 0);
        vm.assume(amountLoaned <= type(uint256).max / AssetValuationLib.ONE_4); // No overflow Risk Module
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(pool));
        vm.assume(sender != address(proxyAccount));

        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(sender, amountRepaid);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.startPrank(sender);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit Repay(address(proxyAccount), sender, amountRepaid);
        pool.repay(amountRepaid, address(proxyAccount));
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), amountRepaid);
        assertEq(mockERC20.stable1.balanceOf(sender), 0);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned - amountRepaid);
    }

    function testFuzz_Success_Repay_ExactAmount(uint112 amountLoaned, address sender) public {
        // Given: collateralValue is smaller than maxExposure.
        amountLoaned = uint112(bound(amountLoaned, 0, type(uint112).max - 1));

        vm.assume(amountLoaned > 0);
        vm.assume(amountLoaned <= type(uint256).max / AssetValuationLib.ONE_4); // No overflow Risk Module
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(pool));
        vm.assume(sender != address(proxyAccount));

        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(sender, amountLoaned);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.startPrank(sender);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit Repay(address(proxyAccount), sender, amountLoaned);
        pool.repay(amountLoaned, address(proxyAccount));
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(sender), 0);
        assertEq(debt.balanceOf(address(proxyAccount)), 0);
    }

    function testFuzz_Success_repay_AmountExceedingLoan(uint112 amountLoaned, uint128 availableFunds, address sender)
        public
    {
        // Given: collateralValue is smaller than maxExposure.
        amountLoaned = uint112(bound(amountLoaned, 0, type(uint112).max - 1));

        vm.assume(availableFunds > amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(amountLoaned <= type(uint256).max / AssetValuationLib.ONE_4); // No overflow Risk Module
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(pool));
        vm.assume(sender != address(proxyAccount));

        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(sender, availableFunds);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.startPrank(sender);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit Repay(address(proxyAccount), sender, amountLoaned);
        pool.repay(availableFunds, address(proxyAccount));
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(sender), availableFunds - amountLoaned);
        assertEq(debt.balanceOf(address(proxyAccount)), 0);
    }
}

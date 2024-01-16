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
contract AuctionRepay_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_AuctionRepay_Unauthorised(address unprivilegedAddress_, address bidder, uint256 amount)
        public
    {
        // Given: unprivilegedAddress is not the liquidator
        vm.assume(unprivilegedAddress_ != address(liquidator));

        // When: unprivilegedAddress settles a liquidation
        // Then: settleLiquidation should revert with "UNAUTHORIZED"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(Unauthorized.selector);
        pool.auctionRepay(0, 0, amount, address(proxyAccount), bidder);
        vm.stopPrank();
    }

    function testFuzz_Revert_AuctionRepay_InsufficientFunds(
        uint112 amountLoaned,
        uint256 availableFunds,
        address sender
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        amountLoaned = uint112(bound(amountLoaned, 0, type(uint112).max - 1));

        vm.assume(amountLoaned > availableFunds);
        vm.assume(amountLoaned <= type(uint256).max / AssetValuationLib.ONE_4); // No overflow Risk Module
        vm.assume(availableFunds > 0);
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(sender, availableFunds);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.startPrank(sender);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.startPrank(address(liquidator));
        vm.expectRevert("TRANSFER_FROM_FAILED");
        pool.auctionRepay(amountLoaned, 0, amountLoaned, address(proxyAccount), sender);
        vm.stopPrank();
    }

    function testFuzz_Revert_auctionRepay_Paused(uint112 amountLoaned, uint256 availableFunds, address sender) public {
        // Given: collateralValue is smaller than maxExposure.
        amountLoaned = uint112(bound(amountLoaned, 0, type(uint112).max - 1));

        vm.assume(amountLoaned > availableFunds);
        vm.assume(amountLoaned <= type(uint256).max / AssetValuationLib.ONE_4); // No overflow Risk Module
        vm.assume(availableFunds > 0);
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
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
        vm.startPrank(address(liquidator));
        vm.expectRevert(FunctionIsPaused.selector);
        pool.auctionRepay(amountLoaned, 0, amountLoaned, address(proxyAccount), sender);
        vm.stopPrank();
    }

    function testFuzz_Revert_auctionRepay_NonAccount(
        uint128 availableFunds,
        uint256 amountRepaid,
        address sender,
        address nonAccount
    ) public {
        vm.assume(nonAccount != address(proxyAccount));
        vm.assume(availableFunds > amountRepaid);
        vm.assume(sender != users.liquidityProvider);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(sender, availableFunds);

        vm.startPrank(sender);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.startPrank(address(liquidator));
        vm.expectRevert(IsNotAnAccountWithDebt.selector);
        pool.auctionRepay(amountRepaid, 0, amountRepaid, nonAccount, sender);
        vm.stopPrank();
    }

    function testFuzz_Revert_auctionRepay_ZeroAmount(uint112 amountLoaned, address sender) public {
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(pool));
        vm.assume(sender != address(proxyAccount));

        // Given: collateralValue is smaller than maxExposure.
        // And: amountLoaned is bigger than as 0.
        amountLoaned = uint112(bound(amountLoaned, 1, type(uint112).max - 1));

        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.prank(address(liquidator));
        vm.expectRevert(ZeroShares.selector);
        pool.auctionRepay(amountLoaned, 0, 0, address(proxyAccount), sender);
    }

    function testFuzz_Success_auctionRepay_AmountInferiorLoan(
        uint112 amountLoaned,
        uint256 amountRepaid,
        address sender
    ) public {
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(pool));
        vm.assume(sender != address(proxyAccount));

        // Given: collateralValue is smaller than maxExposure.
        // And: amountLoaned is bigger than amountRepaid, which is bigger than 0.
        amountLoaned = uint112(bound(amountLoaned, 2, type(uint112).max - 1));
        amountRepaid = bound(amountRepaid, 1, amountLoaned - 1);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(sender, amountRepaid);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.startPrank(sender);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.startPrank(address(liquidator));
        vm.expectEmit(true, true, true, true);
        emit Repay(address(proxyAccount), sender, amountRepaid);
        bool earlyTerminate = pool.auctionRepay(amountLoaned, 0, amountRepaid, address(proxyAccount), sender);
        vm.stopPrank();

        assertFalse(earlyTerminate);
        assertEq(mockERC20.stable1.balanceOf(address(pool)), amountRepaid);
        assertEq(mockERC20.stable1.balanceOf(sender), 0);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned - amountRepaid);
    }

    function testFuzz_Success_auctionRepay_ExactAmount(uint112 amountLoaned, address sender) public {
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(pool));
        vm.assume(sender != address(proxyAccount));

        // Given: collateralValue is smaller than maxExposure.
        // And: amountLoaned is bigger than 0
        amountLoaned = uint112(bound(amountLoaned, 1, type(uint112).max - 1));

        vm.startPrank(users.creatorAddress);
        pool.setLiquidationParameters(0, 0, 0, 0, 0);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.transfer(sender, amountLoaned);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.startPrank(sender);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.startPrank(address(liquidator));
        vm.expectEmit(true, true, true, true);
        emit Repay(address(proxyAccount), sender, amountLoaned);
        bool earlyTerminate = pool.auctionRepay(amountLoaned, 0, amountLoaned, address(proxyAccount), sender);
        vm.stopPrank();

        assertTrue(earlyTerminate);
        assertEq(mockERC20.stable1.balanceOf(address(pool)), amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(sender), 0);
        assertEq(debt.balanceOf(address(proxyAccount)), 0);
    }

    function testFuzz_Success_auctionRepay_AmountExceedingLoan(
        uint112 amountLoaned,
        uint256 amountRepaid,
        address sender
    ) public {
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(pool));
        vm.assume(sender != address(proxyAccount));

        // Given: collateralValue is smaller than maxExposure.
        // And: amountLoaned is bigger than 0.
        amountLoaned = uint112(bound(amountLoaned, 1, type(uint112).max - 1));

        // And: "totalRealisedLiquidity" in "_settleLiquidationHappyFlow" does not overflow.
        // And: "balanceOf" the "liquidityProvider" does not underflow.
        amountRepaid = bound(amountRepaid, amountLoaned + 1, type(uint128).max - amountLoaned);

        vm.startPrank(users.creatorAddress);
        pool.setLiquidationParameters(2, 5, 2, 0, type(uint80).max);

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
        emit Repay(address(proxyAccount), sender, amountLoaned);
        vm.startPrank(address(liquidator));
        bool earlyTerminate = pool.auctionRepay(amountLoaned, 0, amountRepaid, address(proxyAccount), sender);
        vm.stopPrank();

        assertTrue(earlyTerminate);
        assertEq(mockERC20.stable1.balanceOf(address(pool)), amountRepaid);
        assertEq(mockERC20.stable1.balanceOf(sender), 0);
        assertEq(debt.balanceOf(address(proxyAccount)), 0);
    }
}

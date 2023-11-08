/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { RiskConstants } from "../../../lib/accounts-v2/src/libraries/RiskConstants.sol";

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
        vm.expectRevert(LendingPool_OnlyLiquidator.selector);
        pool.auctionRepay(amount, address(proxyAccount), bidder);
        vm.stopPrank();
    }

    function testFuzz_Revert_AuctionRepay_InsufficientFunds(
        uint128 amountLoaned,
        uint256 availableFunds,
        address sender
    ) public {
        vm.assume(amountLoaned > availableFunds);
        vm.assume(amountLoaned <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
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
        pool.auctionRepay(amountLoaned, address(proxyAccount), sender);
        vm.stopPrank();
    }

    function testFuzz_Revert_auctionRepay_Paused(uint128 amountLoaned, uint256 availableFunds, address sender) public {
        vm.assume(amountLoaned > availableFunds);
        vm.assume(amountLoaned <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(availableFunds > 0);
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.warp(35 days);

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
        vm.expectRevert(LendingPoolGuardian_FunctionIsPaused.selector);
        pool.auctionRepay(amountLoaned, address(proxyAccount), sender);
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
        vm.expectRevert(DebtToken_ZeroShares.selector);
        pool.auctionRepay(amountRepaid, nonAccount, sender);
        vm.stopPrank();
    }

    function testFuzz_Success_auctionRepay_AmountInferiorLoan(
        uint128 amountLoaned,
        uint256 amountRepaid,
        address sender
    ) public {
        vm.assume(amountLoaned > amountRepaid);
        vm.assume(amountRepaid > 0);
        vm.assume(amountLoaned <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(pool));

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
        pool.auctionRepay(amountRepaid, address(proxyAccount), sender);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), amountRepaid);
        assertEq(mockERC20.stable1.balanceOf(sender), 0);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned - amountRepaid);
    }

    function testFuzz_Success_auctionRepay_ExactAmount(uint128 amountLoaned, address sender) public {
        vm.assume(amountLoaned > 0);
        vm.assume(amountLoaned <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(pool));

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
        pool.auctionRepay(amountLoaned, address(proxyAccount), sender);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(sender), 0);
        assertEq(debt.balanceOf(address(proxyAccount)), 0);
    }

    function testFuzz_Success_auctionRepay_AmountExceedingLoan(
        uint128 amountLoaned,
        uint128 availableFunds,
        address sender
    ) public {
        vm.assume(availableFunds > amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(amountLoaned <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(sender != address(0));
        vm.assume(sender != users.liquidityProvider);
        vm.assume(sender != users.accountOwner);
        vm.assume(sender != address(pool));

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
        emit Repay(address(proxyAccount), sender, availableFunds);
        vm.startPrank(address(liquidator));
        pool.auctionRepay(availableFunds, address(proxyAccount), sender);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), availableFunds);
        assertEq(mockERC20.stable1.balanceOf(sender), 0);
        assertEq(debt.balanceOf(address(proxyAccount)), 0);
    }
}

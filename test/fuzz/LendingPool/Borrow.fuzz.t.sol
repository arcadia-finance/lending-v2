/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { stdError } from "../../../lib/forge-std/src/StdError.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

import { LendingPool } from "../../../src/LendingPool.sol";
import { RiskConstants } from "../../../lib/accounts-v2/src/libraries/RiskConstants.sol";

/**
 * @notice Fuzz tests for the function "borrow" of contract "LendingPool".
 */
contract Borrow_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
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
    function testFuzz_Revert_borrow_NonAccount(uint256 amount, address nonAccount, address to) public {
        vm.assume(nonAccount != address(proxyAccount));
        vm.expectRevert(LendingPool_IsNotAnAccount.selector);
        pool.borrow(amount, nonAccount, to, emptyBytes3);
    }

    function testFuzz_Revert_borrow_Unauthorised(uint256 amount, address beneficiary, address to) public {
        vm.assume(beneficiary != users.accountOwner);

        vm.assume(amount > 0);
        vm.startPrank(beneficiary);
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amount, address(proxyAccount), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_InsufficientApproval(
        uint256 amountAllowed,
        uint256 amountLoaned,
        address beneficiary,
        address to
    ) public {
        vm.assume(beneficiary != users.accountOwner);
        vm.assume(amountAllowed < amountLoaned);

        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, amountAllowed, address(proxyAccount));

        vm.startPrank(beneficiary);
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_InsufficientApprovalAfterTransfer(
        uint256 amountLoaned,
        address beneficiary,
        address to,
        address newOwner
    ) public {
        vm.assume(beneficiary != newOwner);
        vm.assume(newOwner != users.accountOwner);
        vm.assume(newOwner != address(0));
        vm.assume(amountLoaned > 0);

        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, type(uint256).max, address(proxyAccount));

        vm.prank(users.accountOwner);
        uint256 accountIndex = factory.accountIndex(address(proxyAccount));
        stdstore.target(address(factory)).sig(factory.ownerOf.selector).with_key(accountIndex).checked_write(newOwner);

        vm.startPrank(beneficiary);
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_InsufficientCollateral(uint128 amountLoaned, uint256 collateralValue, address to)
        public
    {
        vm.assume(collateralValue < amountLoaned);
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.startPrank(users.accountOwner);
        vm.expectRevert(LendingPool_Reverted.selector);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_DifferentTrustedCreditor(
        uint128 amountLoaned,
        uint256 collateralValue,
        address to,
        address trustedCreditor_
    ) public {
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(trustedCreditor_ != address(pool));

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.startPrank(users.creatorAddress);
        LendingPool pool_ =
            new LendingPool(ERC20(address(mockERC20.stable1)), treasury, address(factory), address(liquidator));
        pool_.setAccountVersion(1, true);
        vm.stopPrank();

        vm.startPrank(users.accountOwner);
        proxyAccount.closeTrustedMarginAccount();
        proxyAccount.openTrustedMarginAccount(address(pool_));
        vm.stopPrank();

        vm.startPrank(users.accountOwner);
        vm.expectRevert(LendingPool_Reverted.selector);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_BadAccountVersion(uint128 amountLoaned, uint256 collateralValue, address to)
        public
    {
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.prank(users.creatorAddress);
        pool.setAccountVersion(1, false);

        vm.startPrank(users.accountOwner);
        vm.expectRevert(LendingPool_Reverted.selector);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_InsufficientLiquidity(
        uint128 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to
    ) public {
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(liquidity < amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.startPrank(users.accountOwner);
        vm.expectRevert("TRANSFER_FAILED");
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_Paused(uint128 amountLoaned, uint256 collateralValue, uint128 liquidity, address to)
        public
    {
        vm.assume(collateralValue <= amountLoaned);
        vm.assume(liquidity > amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));

        vm.warp(35 days);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.prank(users.guardian);
        pool.pause();

        vm.expectRevert(LendingPoolGuardian_FunctionIsPaused.selector);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
    }

    function testFuzz_Revert_borrow_BorrowCap(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to,
        uint128 borrowCap
    ) public {
        vm.assume(amountLoaned > 1);
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity > amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));
        vm.assume(borrowCap > 0);
        vm.assume(borrowCap < amountLoaned);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.prank(users.creatorAddress);
        pool.setBorrowCap(borrowCap);

        vm.expectRevert(DebtToken_BorrowCapExceeded.selector);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
    }

    function testFuzz_Success_borrow_BorrowCapSetToZeroAgain(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to
    ) public {
        vm.assume(amountLoaned > 1);
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(liquidity > amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        // When: borrow cap is set to 1
        vm.prank(users.creatorAddress);
        pool.setBorrowCap(1);

        // Then: borrow should revert with "LP_B: Borrow cap reached"
        vm.expectRevert(DebtToken_BorrowCapExceeded.selector);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);

        // When: borrow cap is set to 0
        vm.prank(users.creatorAddress);
        pool.setBorrowCap(0);

        // Then: borrow should succeed
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned);
    }

    function testFuzz_Success_borrow_BorrowCapNotReached(
        uint256 amountLoaned,
        uint256 amountLoanedToFail,
        uint256 collateralValue,
        uint128 liquidity,
        address to
    ) public {
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned < 100);
        vm.assume(amountLoanedToFail > 100);
        vm.assume(collateralValue >= amountLoanedToFail);
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(liquidity > amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        // When: borrow cap is set to 1
        vm.prank(users.creatorAddress);
        pool.setBorrowCap(1);

        // Then: borrow should revert with "LP_B: Borrow cap reached"
        vm.expectRevert(DebtToken_BorrowCapExceeded.selector);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);

        // When: borrow cap is set to 100 which is lower than the amountLoaned
        vm.prank(users.creatorAddress);
        pool.setBorrowCap(100);

        // Then: borrow should still fail with exceeding amount
        vm.expectRevert(DebtToken_BorrowCapExceeded.selector);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoanedToFail, address(proxyAccount), to, emptyBytes3);

        // When: right amount is used
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);

        // Then: borrow should succeed
        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned);
    }

    function testFuzz_Success_borrow_ByAccountOwner(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to
    ) public {
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(liquidity >= amountLoaned);
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.startPrank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned);
    }

    function testFuzz_Success_borrow_ByLimitedAuthorisedAddress(
        uint256 amountAllowed,
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address beneficiary,
        address to
    ) public {
        vm.assume(amountAllowed >= amountLoaned);
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountAllowed < type(uint256).max);
        vm.assume(beneficiary != users.accountOwner);
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, amountAllowed, address(proxyAccount));

        vm.startPrank(beneficiary);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned);
        assertEq(
            pool.creditAllowance(address(proxyAccount), users.accountOwner, beneficiary), amountAllowed - amountLoaned
        );
    }

    function testFuzz_Success_borrow_ByMaxAuthorisedAddress(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address beneficiary,
        address to
    ) public {
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(liquidity >= amountLoaned);
        vm.assume(beneficiary != users.accountOwner);
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, type(uint256).max, address(proxyAccount));

        vm.startPrank(beneficiary);
        pool.borrow(amountLoaned, address(proxyAccount), to, emptyBytes3);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned);
        assertEq(pool.creditAllowance(address(proxyAccount), users.accountOwner, beneficiary), type(uint256).max);
    }

    function testFuzz_Success_borrow_originationFeeAvailable(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to,
        uint8 originationFee,
        bytes3 ref
    ) public {
        vm.assume(amountLoaned <= type(uint256).max / (uint256(originationFee) + 1));
        vm.assume(amountLoaned <= type(uint256).max - (amountLoaned * originationFee / 10_000));
        vm.assume(collateralValue >= amountLoaned + (amountLoaned * originationFee / 10_000));
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(liquidity >= amountLoaned);
        vm.assume(liquidity <= type(uint128).max - (amountLoaned * originationFee / 10_000));
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));

        vm.prank(users.creatorAddress);
        pool.setOriginationFee(originationFee);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        uint256 treasuryBalancePre = pool.realisedLiquidityOf(treasury);
        uint256 totalRealisedLiquidityPre = pool.totalRealisedLiquidity();

        vm.startPrank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), to, ref);
        vm.stopPrank();

        uint256 treasuryBalancePost = pool.realisedLiquidityOf(treasury);
        uint256 totalRealisedLiquidityPost = pool.totalRealisedLiquidity();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(to), amountLoaned);

        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned + (amountLoaned * originationFee / 10_000));
        assertEq(treasuryBalancePre + (amountLoaned * originationFee / 10_000), treasuryBalancePost);
        assertEq(totalRealisedLiquidityPre + (amountLoaned * originationFee / 10_000), totalRealisedLiquidityPost);
    }

    function testFuzz_Success_borrow_EmitReferralEvent(
        uint256 amountLoaned,
        uint256 collateralValue,
        uint128 liquidity,
        address to,
        uint8 originationFee,
        bytes3 ref
    ) public {
        vm.assume(amountLoaned <= type(uint256).max / (uint256(originationFee) + 1));
        vm.assume(amountLoaned <= type(uint256).max - (amountLoaned * originationFee / 10_000));
        vm.assume(collateralValue >= amountLoaned + (amountLoaned * originationFee / 10_000));
        vm.assume(collateralValue <= type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT); // No overflow Risk Module
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));

        uint256 fee = amountLoaned * originationFee / 10_000;

        vm.prank(users.creatorAddress);
        pool.setOriginationFee(originationFee);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit Borrow(address(proxyAccount), users.accountOwner, to, amountLoaned, fee, ref);
        pool.borrow(amountLoaned, address(proxyAccount), to, ref);
        vm.stopPrank();
    }
}

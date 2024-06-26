/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { AccountErrors } from "../../../lib/accounts-v2/src/libraries/Errors.sol";
import { ERC20 } from "../../../lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../../../lib/accounts-v2/lib/solmate/src/utils/FixedPointMathLib.sol";
import { GuardianErrors } from "../../../lib/accounts-v2/src/libraries/Errors.sol";
import { LendingPool } from "../../../src/LendingPool.sol";
import { LendingPoolErrors } from "../../../src/libraries/Errors.sol";
import { stdError } from "../../../lib/accounts-v2/lib/forge-std/src/StdError.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "borrow" of contract "LendingPool".
 */
contract Borrow_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    using stdStorage for StdStorage;
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_borrow_ZeroAmount(address account, address to) public {
        vm.expectRevert(LendingPoolErrors.ZeroAmount.selector);
        pool.borrow(0, account, to, emptyBytes3);
    }

    function testFuzz_Revert_borrow_NonAccount(uint256 amount, address nonAccount, address to) public {
        vm.assume(amount > 0);

        vm.assume(nonAccount != address(account));
        vm.expectRevert(LendingPoolErrors.IsNotAnAccount.selector);
        pool.borrow(amount, nonAccount, to, emptyBytes3);
    }

    function testFuzz_Revert_borrow_Unauthorised(uint256 amount, address beneficiary, address to) public {
        vm.assume(amount > 0);
        vm.assume(beneficiary != users.accountOwner);

        vm.assume(amount > 0);
        vm.startPrank(beneficiary);
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amount, address(account), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_InsufficientApproval(
        uint256 amountAllowed,
        uint256 amountLoaned,
        address beneficiary,
        address to
    ) public {
        vm.assume(beneficiary != users.accountOwner);
        vm.assume(amountLoaned > 0);
        vm.assume(amountAllowed < amountLoaned);

        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, amountAllowed, address(account));

        vm.startPrank(beneficiary);
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amountLoaned, address(account), to, emptyBytes3);
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
        pool.approveBeneficiary(beneficiary, type(uint256).max, address(account));

        vm.prank(users.accountOwner);
        uint256 accountIndex = factory.accountIndex(address(account));
        stdstore.target(address(factory)).sig(factory.ownerOf.selector).with_key(accountIndex).checked_write(newOwner);

        vm.startPrank(beneficiary);
        vm.expectRevert(stdError.arithmeticError);
        pool.borrow(amountLoaned, address(account), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_InsufficientCollateral(uint128 amountLoaned, uint112 collateralValue, address to)
        public
    {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue < amountLoaned);
        vm.assume(amountLoaned > 0);

        depositERC20InAccount(account, mockERC20.stable1, collateralValue);

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        pool.borrow(amountLoaned, address(account), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_DifferentCreditor(
        uint128 amountLoaned,
        uint112 collateralValue,
        address to,
        address trustedCreditor_
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(trustedCreditor_ != address(pool));

        depositERC20InAccount(account, mockERC20.stable1, collateralValue);

        vm.startPrank(users.owner);
        LendingPool pool_ = new LendingPool(
            users.riskManager, ERC20(address(mockERC20.stable1)), users.treasury, address(factory), address(liquidator)
        );
        pool_.setAccountVersion(1, true);
        vm.stopPrank();

        vm.startPrank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(pool_), address(mockERC20.stable1), 0, type(uint112).max, 100, 100
        );
        registry.setRiskParameters(address(pool_), 0, 15 minutes, type(uint64).max);
        vm.stopPrank();

        vm.startPrank(users.accountOwner);
        account.closeMarginAccount();
        account.openMarginAccount(address(pool_));
        vm.stopPrank();

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.OnlyCreditor.selector);
        pool.borrow(amountLoaned, address(account), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_BadAccountVersion(uint128 amountLoaned, uint112 collateralValue, address to)
        public
    {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= amountLoaned);
        vm.assume(amountLoaned > 0);

        depositERC20InAccount(account, mockERC20.stable1, collateralValue);

        vm.prank(users.owner);
        pool.setAccountVersion(1, false);

        vm.startPrank(users.accountOwner);
        vm.expectRevert(LendingPoolErrors.InvalidVersion.selector);
        pool.borrow(amountLoaned, address(account), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_InsufficientLiquidity(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity,
        address to
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(liquidity < amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        depositERC20InAccount(account, mockERC20.stable1, collateralValue);

        vm.startPrank(users.accountOwner);
        vm.expectRevert("TRANSFER_FAILED");
        pool.borrow(amountLoaned, address(account), to, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_borrow_Paused(uint128 amountLoaned, uint112 collateralValue, uint128 liquidity, address to)
        public
    {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue <= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(liquidity > amountLoaned);
        vm.assume(liquidity > 0);
        vm.assume(to != address(0));

        vm.warp(35 days);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        depositERC20InAccount(account, mockERC20.stable1, collateralValue);

        vm.prank(users.guardian);
        pool.pause();

        vm.expectRevert(GuardianErrors.FunctionIsPaused.selector);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), to, emptyBytes3);
    }

    function testFuzz_Success_borrow_ByAccountOwner(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity,
        address to
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));
        vm.assume(to != address(account));

        depositERC20InAccount(account, mockERC20.stable1, collateralValue);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.startPrank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), to, emptyBytes3);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(account)), amountLoaned);
    }

    function testFuzz_Success_borrow_ByLimitedAuthorisedAddress(
        uint128 amountAllowed,
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity,
        address beneficiary,
        address to
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(amountAllowed >= amountLoaned);
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountAllowed < type(uint256).max);
        vm.assume(beneficiary != users.accountOwner);
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));
        vm.assume(to != address(account));

        depositERC20InAccount(account, mockERC20.stable1, collateralValue);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, amountAllowed, address(account));

        vm.startPrank(beneficiary);
        pool.borrow(amountLoaned, address(account), to, emptyBytes3);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(account)), amountLoaned);
        assertEq(pool.creditAllowance(address(account), users.accountOwner, beneficiary), amountAllowed - amountLoaned);
    }

    function testFuzz_Success_borrow_ByMaxAuthorisedAddress(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity,
        address beneficiary,
        address to
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(beneficiary != users.accountOwner);
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));
        vm.assume(to != address(account));

        depositERC20InAccount(account, mockERC20.stable1, collateralValue);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, type(uint256).max, address(account));

        vm.startPrank(beneficiary);
        pool.borrow(amountLoaned, address(account), to, emptyBytes3);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(to), amountLoaned);
        assertEq(debt.balanceOf(address(account)), amountLoaned);
        assertEq(pool.creditAllowance(address(account), users.accountOwner, beneficiary), type(uint256).max);
    }

    function testFuzz_Success_borrow_originationFeeAvailable(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity,
        address to,
        uint8 originationFee,
        bytes3 ref
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, type(uint96).max, type(uint112).max - 1));

        vm.assume(collateralValue >= uint256(amountLoaned) + (uint256(amountLoaned).mulDivDown(originationFee, 10_000)));
        vm.assume(amountLoaned > 0);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(liquidity <= type(uint128).max - (uint256(amountLoaned).mulDivUp(originationFee, 10_000)));
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));
        vm.assume(to != address(account));

        vm.prank(users.owner);
        pool.setOriginationFee(originationFee);

        depositERC20InAccount(account, mockERC20.stable1, collateralValue);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        uint256 treasuryBalancePre = pool.liquidityOf(users.treasury);
        uint256 totalRealisedLiquidityPre = pool.totalLiquidity();

        vm.startPrank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), to, ref);
        vm.stopPrank();

        uint256 treasuryBalancePost = pool.liquidityOf(users.treasury);
        uint256 totalRealisedLiquidityPost = pool.totalLiquidity();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(to), amountLoaned);

        assertEq(
            debt.balanceOf(address(account)),
            uint256(amountLoaned) + (uint256(amountLoaned).mulDivUp(originationFee, 10_000))
        );
        assertEq(treasuryBalancePre + (uint256(amountLoaned).mulDivUp(originationFee, 10_000)), treasuryBalancePost);
        assertEq(
            totalRealisedLiquidityPre + (uint256(amountLoaned).mulDivUp(originationFee, 10_000)),
            totalRealisedLiquidityPost
        );
    }

    function testFuzz_Success_borrow_EmitReferralEvent(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity,
        address to,
        uint8 originationFee,
        bytes3 ref
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= uint256(amountLoaned) + (uint256(amountLoaned) * originationFee / 10_000));
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(to != address(0));
        vm.assume(to != users.liquidityProvider);
        vm.assume(to != address(pool));
        vm.assume(to != address(account));

        vm.prank(users.owner);
        pool.setOriginationFee(0);

        depositERC20InAccount(account, mockERC20.stable1, collateralValue);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit LendingPool.Borrow(address(account), users.accountOwner, to, amountLoaned, 0, ref);
        pool.borrow(amountLoaned, address(account), to, ref);
        vm.stopPrank();
    }
}

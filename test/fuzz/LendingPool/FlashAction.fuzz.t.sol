/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ActionData } from "../../../lib/accounts-v2/src/interfaces/IActionBase.sol";
import { ActionTargetMock } from "../../../lib/accounts-v2/test/utils/mocks/action-targets/ActionTargetMock.sol";
import { FixedPointMathLib } from "../../../lib/accounts-v2/lib/solmate/src/utils/FixedPointMathLib.sol";
import { IPermit2 } from "../../../lib/accounts-v2/src/interfaces/IPermit2.sol";
import { LendingPool } from "../../../src/LendingPool.sol";
import { LendingPoolErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "flashAction" of contract "LendingPool".
 */
contract FlashAction_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ActionTargetMock internal actionHandler;
    bytes internal callData;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();

        vm.prank(users.owner);
        actionHandler = new ActionTargetMock();

        ActionData memory emptyActionData;
        address[] memory to;
        bytes[] memory data;
        bytes memory actionTargetData = abi.encode(emptyActionData, to, data);
        IPermit2.PermitBatchTransferFrom memory permit;
        bytes memory signature;
        callData = abi.encode(emptyActionData, emptyActionData, permit, signature, actionTargetData);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_flashAction_NonAccount(
        uint256 amount,
        address nonAccount,
        address actionHandler_,
        bytes calldata actionData
    ) public {
        vm.assume(nonAccount != address(account));
        vm.expectRevert(LendingPoolErrors.IsNotAnAccount.selector);
        pool.flashAction(amount, nonAccount, actionHandler_, actionData, emptyBytes3);
    }

    function testFuzz_Revert_flashAction_Unauthorised(
        uint256 amount,
        address beneficiary,
        address actionHandler_,
        bytes calldata actionData
    ) public {
        vm.assume(beneficiary != users.accountOwner);

        vm.startPrank(beneficiary);
        vm.expectRevert(LendingPoolErrors.Unauthorized.selector);
        pool.flashAction(amount, address(account), actionHandler_, actionData, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_ByLimitedAuthorisedAddress(
        uint256 amountAllowed,
        uint256 amountLoaned,
        address beneficiary,
        address actionHandler_,
        bytes calldata actionData
    ) public {
        vm.assume(beneficiary != users.accountOwner);
        vm.assume(amountAllowed < type(uint256).max);

        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, amountAllowed, address(account));

        vm.startPrank(beneficiary);
        vm.expectRevert(LendingPoolErrors.Unauthorized.selector);
        pool.flashAction(amountLoaned, address(account), actionHandler_, actionData, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_InsufficientLiquidity(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity < amountLoaned);
        vm.assume(liquidity > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        depositErc20InAccount(account, mockERC20.stable1, collateralValue);

        vm.startPrank(users.accountOwner);
        vm.expectRevert("TRANSFER_FAILED");
        pool.flashAction(amountLoaned, address(account), address(actionHandler), callData, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Success_flashAction_ByAccountOwner(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);

        depositErc20InAccount(account, mockERC20.stable1, collateralValue);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.flashAction(amountLoaned, address(account), address(actionHandler), callData, emptyBytes3);

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(address(actionHandler)), amountLoaned);
        assertEq(debt.balanceOf(address(account)), amountLoaned);
    }

    function testFuzz_Success_flashAction_ByMaxAuthorisedAddress(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity,
        address beneficiary
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);
        vm.assume(beneficiary != users.accountOwner);

        depositErc20InAccount(account, mockERC20.stable1, collateralValue);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, type(uint256).max, address(account));

        vm.prank(beneficiary);
        pool.flashAction(amountLoaned, address(account), address(actionHandler), callData, emptyBytes3);

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(address(actionHandler)), amountLoaned);
        assertEq(debt.balanceOf(address(account)), amountLoaned);
        assertEq(pool.creditAllowance(address(account), users.accountOwner, beneficiary), type(uint256).max);
    }

    function testFuzz_Success_flashAction_originationFeeAvailable(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity,
        uint8 originationFee
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, type(uint96).max, type(uint112).max - 1));

        vm.assume(collateralValue >= uint256(amountLoaned) + (uint256(amountLoaned).mulDivDown(originationFee, 10_000)));
        vm.assume(liquidity >= amountLoaned);
        vm.assume(liquidity <= type(uint128).max - (uint256(amountLoaned).mulDivUp(originationFee, 10_000)));
        vm.assume(amountLoaned > 0);

        vm.prank(users.owner);
        pool.setOriginationFee(originationFee);

        depositErc20InAccount(account, mockERC20.stable1, collateralValue);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        uint256 treasuryBalancePre = pool.liquidityOf(users.treasury);
        uint256 totalRealisedLiquidityPre = pool.totalLiquidity();

        vm.startPrank(users.accountOwner);
        pool.flashAction(amountLoaned, address(account), address(actionHandler), callData, emptyBytes3);
        vm.stopPrank();

        uint256 treasuryBalancePost = pool.liquidityOf(users.treasury);
        uint256 totalRealisedLiquidityPost = pool.totalLiquidity();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(address(actionHandler)), amountLoaned);
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

    function testFuzz_Success_flashAction_EmitReferralEvent(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity,
        uint8 originationFee,
        bytes3 ref
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= uint256(amountLoaned) + (uint256(amountLoaned) * originationFee / 10_000));
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);

        vm.prank(users.owner);
        pool.setOriginationFee(0);

        depositErc20InAccount(account, mockERC20.stable1, collateralValue);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit LendingPool.Borrow(address(account), users.accountOwner, address(actionHandler), amountLoaned, 0, ref);
        pool.flashAction(amountLoaned, address(account), address(actionHandler), callData, ref);
        vm.stopPrank();
    }
}

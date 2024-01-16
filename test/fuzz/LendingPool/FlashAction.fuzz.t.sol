/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { ActionData } from "../../../lib/accounts-v2/src/interfaces/IActionBase.sol";
import { ActionMultiCall } from "../../../lib/accounts-v2/src/actions/MultiCall.sol";
import { IPermit2 } from "../../../lib/accounts-v2/src/interfaces/IPermit2.sol";

/**
 * @notice Fuzz tests for the function "flashAction" of contract "LendingPool".
 */
contract FlashAction_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ActionMultiCall internal actionHandler;
    bytes internal callData;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        actionHandler = new ActionMultiCall();

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
        vm.assume(nonAccount != address(proxyAccount));
        vm.expectRevert(IsNotAnAccount.selector);
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
        vm.expectRevert(Unauthorized.selector);
        pool.flashAction(amount, address(proxyAccount), actionHandler_, actionData, emptyBytes3);
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
        pool.approveBeneficiary(beneficiary, amountAllowed, address(proxyAccount));

        vm.startPrank(beneficiary);
        vm.expectRevert(Unauthorized.selector);
        pool.flashAction(amountLoaned, address(proxyAccount), actionHandler_, actionData, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_flashAction_InsufficientLiquidity(
        uint128 amountLoaned,
        uint112 collateralValue,
        uint128 liquidity,
        bytes calldata actionData
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity < amountLoaned);
        vm.assume(liquidity > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.startPrank(users.accountOwner);
        vm.expectRevert("TRANSFER_FAILED");
        pool.flashAction(amountLoaned, address(proxyAccount), address(actionHandler), actionData, emptyBytes3);
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

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.flashAction(amountLoaned, address(proxyAccount), address(actionHandler), callData, emptyBytes3);

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(address(actionHandler)), amountLoaned);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned);
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

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, type(uint256).max, address(proxyAccount));

        vm.prank(beneficiary);
        pool.flashAction(amountLoaned, address(proxyAccount), address(actionHandler), callData, emptyBytes3);

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(address(actionHandler)), amountLoaned);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned);
        assertEq(pool.creditAllowance(address(proxyAccount), users.accountOwner, beneficiary), type(uint256).max);
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

        vm.prank(users.creatorAddress);
        pool.setOriginationFee(originationFee);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        uint256 treasuryBalancePre = pool.liquidityOf(treasury);
        uint256 totalRealisedLiquidityPre = pool.totalLiquidity();

        vm.startPrank(users.accountOwner);
        pool.flashAction(amountLoaned, address(proxyAccount), address(actionHandler), callData, emptyBytes3);
        vm.stopPrank();

        uint256 treasuryBalancePost = pool.liquidityOf(treasury);
        uint256 totalRealisedLiquidityPost = pool.totalLiquidity();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(address(actionHandler)), amountLoaned);
        assertEq(
            debt.balanceOf(address(proxyAccount)),
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

        vm.prank(users.creatorAddress);
        pool.setOriginationFee(0);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit Borrow(address(proxyAccount), users.accountOwner, address(actionHandler), amountLoaned, 0, ref);
        pool.flashAction(amountLoaned, address(proxyAccount), address(actionHandler), callData, ref);
        vm.stopPrank();
    }
}

/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ActionData } from "../../../lib/accounts-v2/src/actions/utils/ActionData.sol";
import { ActionMultiCallV2 } from "../../../lib/accounts-v2/src/actions/MultiCallV2.sol";
import { IPermit2 } from "../../../lib/accounts-v2/test/utils/Interfaces.sol";
import { RiskConstants } from "../../../lib/accounts-v2/src/libraries/RiskConstants.sol";

/**
 * @notice Fuzz tests for the function "doActionWithLeverage" of contract "LendingPool".
 */
contract DoActionWithLeverage_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ActionMultiCallV2 internal actionHandler;
    bytes internal callData;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        actionHandler = new ActionMultiCallV2();
        mainRegistryExtension.setAllowedAction(address(actionHandler), true);
        vm.stopPrank();

        ActionData memory emptyActionData;
        address[] memory to;
        bytes[] memory data;
        bytes memory signature;
        callData = abi.encode(emptyActionData, emptyActionData, signature, emptyActionData, to, data);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_doActionWithLeverage_NonAccount(
        uint256 amount,
        address nonAccount,
        address actionHandler_,
        bytes calldata actionData,
        bytes calldata signature
    ) public {
        vm.assume(nonAccount != address(proxyAccount));
        vm.expectRevert(LendingPool_IsNotAnAccount.selector);
        pool.doActionWithLeverage(amount, nonAccount, actionHandler_, actionData, signature, emptyBytes3);
    }

    function testFuzz_Revert_doActionWithLeverage_Unauthorised(
        uint256 amount,
        address beneficiary,
        address actionHandler_,
        bytes calldata actionData,
        bytes calldata signature
    ) public {
        vm.assume(beneficiary != users.accountOwner);

        vm.startPrank(beneficiary);
        vm.expectRevert(LendingPool_Unauthorized.selector);
        pool.doActionWithLeverage(amount, address(proxyAccount), actionHandler_, actionData, signature, emptyBytes3);
        vm.stopPrank();
    }

    function testFuzz_Revert_doActionWithLeverage_ByLimitedAuthorisedAddress(
        uint256 amountAllowed,
        uint256 amountLoaned,
        address beneficiary,
        address actionHandler_,
        bytes calldata actionData,
        bytes calldata signature
    ) public {
        vm.assume(beneficiary != users.accountOwner);
        vm.assume(amountAllowed < type(uint256).max);

        vm.prank(users.accountOwner);
        pool.approveBeneficiary(beneficiary, amountAllowed, address(proxyAccount));

        vm.startPrank(beneficiary);
        vm.expectRevert(LendingPool_Unauthorized.selector);
        pool.doActionWithLeverage(
            amountLoaned, address(proxyAccount), actionHandler_, actionData, signature, emptyBytes3
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_doActionWithLeverage_InsufficientLiquidity(
        uint128 amountLoaned,
        uint128 collateralValue,
        uint128 liquidity,
        bytes calldata actionData,
        bytes calldata signature
    ) public {
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity < amountLoaned);
        vm.assume(liquidity > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.startPrank(users.accountOwner);
        vm.expectRevert("TRANSFER_FAILED");
        pool.doActionWithLeverage(
            amountLoaned, address(proxyAccount), address(actionHandler), actionData, signature, emptyBytes3
        );
        vm.stopPrank();
    }

    function testFuzz_Success_doActionWithLeverage_ByAccountOwner(
        uint128 amountLoaned,
        uint128 collateralValue,
        uint128 liquidity
    ) public {
        vm.assume(collateralValue >= amountLoaned);
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.prank(users.accountOwner);
        pool.doActionWithLeverage(
            amountLoaned, address(proxyAccount), address(actionHandler), callData, new bytes(0), emptyBytes3
        );

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(address(actionHandler)), amountLoaned);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned);
    }

    function testFuzz_Success_doActionWithLeverage_ByMaxAuthorisedAddress(
        uint128 amountLoaned,
        uint128 collateralValue,
        uint128 liquidity,
        address beneficiary
    ) public {
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
        pool.doActionWithLeverage(
            amountLoaned, address(proxyAccount), address(actionHandler), callData, new bytes(0), emptyBytes3
        );

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(address(actionHandler)), amountLoaned);
        assertEq(debt.balanceOf(address(proxyAccount)), amountLoaned);
        assertEq(pool.creditAllowance(address(proxyAccount), users.accountOwner, beneficiary), type(uint256).max);
    }

    function testFuzz_Success_doActionWithLeverage_originationFeeAvailable(
        uint128 amountLoaned,
        uint128 collateralValue,
        uint128 liquidity,
        uint8 originationFee
    ) public {
        vm.assume(collateralValue >= uint256(amountLoaned) + (uint256(amountLoaned) * originationFee / 10_000));
        vm.assume(liquidity >= amountLoaned);
        vm.assume(liquidity <= type(uint128).max - (uint256(amountLoaned) * originationFee / 10_000));
        vm.assume(amountLoaned > 0);

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
        pool.doActionWithLeverage(
            amountLoaned, address(proxyAccount), address(actionHandler), callData, new bytes(0), emptyBytes3
        );
        vm.stopPrank();

        uint256 treasuryBalancePost = pool.realisedLiquidityOf(treasury);
        uint256 totalRealisedLiquidityPost = pool.totalRealisedLiquidity();

        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(address(actionHandler)), amountLoaned);
        assertEq(
            debt.balanceOf(address(proxyAccount)),
            uint256(amountLoaned) + (uint256(amountLoaned) * originationFee / 10_000)
        );
        assertEq(treasuryBalancePre + (uint256(amountLoaned) * originationFee / 10_000), treasuryBalancePost);
        assertEq(
            totalRealisedLiquidityPre + (uint256(amountLoaned) * originationFee / 10_000), totalRealisedLiquidityPost
        );
    }

    function testFuzz_Success_doActionWithLeverage_EmitReferralEvent(
        uint128 amountLoaned,
        uint128 collateralValue,
        uint128 liquidity,
        uint8 originationFee,
        bytes3 ref
    ) public {
        vm.assume(collateralValue >= uint256(amountLoaned) + (uint256(amountLoaned) * originationFee / 10_000));
        vm.assume(liquidity >= amountLoaned);
        vm.assume(amountLoaned > 0);

        uint256 fee = uint256(amountLoaned) * originationFee / 10_000;

        vm.prank(users.creatorAddress);
        pool.setOriginationFee(originationFee);

        depositTokenInAccount(proxyAccount, mockERC20.stable1, collateralValue);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit Borrow(address(proxyAccount), users.accountOwner, address(actionHandler), amountLoaned, fee, ref);
        pool.doActionWithLeverage(
            amountLoaned, address(proxyAccount), address(actionHandler), callData, new bytes(0), ref
        );
        vm.stopPrank();
    }
}

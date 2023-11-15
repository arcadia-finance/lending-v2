/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "startLiquidation" of contract "LendingPool".
 */
contract StartLiquidation_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_StartLiquidation_NonAccount(address account, address nonAccount) public {
        // Given: unprivilegedAddress is not the liquidator
        vm.assume(nonAccount != address(liquidator));
        vm.assume(nonAccount != address(proxyAccount));

        // When: unprivilegedAddress settles a liquidation
        // Then: startLiquidation should revert with error LendingPool_OnlyLiquidator
        vm.startPrank(nonAccount);
        vm.expectRevert(LendingPool_IsNotAnAccountWithDebt.selector);
        pool.startLiquidation(account);
        vm.stopPrank();
    }

    function testFuzz_Revert_StartLiquidation_NotAnAccountWithDebt() public {
        vm.startPrank(address(proxyAccount));
        vm.expectRevert(LendingPool_IsNotAnAccountWithDebt.selector);
        pool.startLiquidation(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Revert_StartLiquidation_Paused(address account_, uint128 amountLoaned) public {
        // Given: Account has debt
        bytes3 emptyBytes4;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 300) * 100); // No overflow when debt is increased
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes4);

        // And: guardian soft start has passed
        vm.warp(35 days);
        vm.startPrank(users.guardian);
        pool.pause();

        vm.expectRevert(LendingPoolGuardian_FunctionIsPaused.selector);
        vm.startPrank(address(proxyAccount));
        pool.startLiquidation(account_);
        vm.stopPrank();
    }

    function testFuzz_Success_startLiquidation_NoOngoingAuctions(
        uint128 amountLoaned,
        uint8 initiatorRewardWeight,
        uint8 penaltyWeight,
        uint8 closingRewardWeight,
        uint80 maxInitiatorFee,
        uint80 maxClosingFee
    ) public {
        // Given: Account has debt
        bytes3 emptyBytes4;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 300) * 100); // No overflow when debt is increased
        vm.assume(uint16(initiatorRewardWeight) + penaltyWeight + closingRewardWeight <= 11);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes4);
        vm.prank(users.creatorAddress);
        pool.setMaxLiquidationFees(maxInitiatorFee, maxClosingFee);

        // And: Weights are set
        vm.prank(users.creatorAddress);
        pool.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidator calls startLiquidation()
        vm.prank(address(proxyAccount));
        pool.startLiquidation(address(proxyAccount));

        // Avoid stack too deep
        uint8 initiatorRewardWeightStack = initiatorRewardWeight;
        uint8 penaltyWeightStack = penaltyWeight;
        uint8 closingRewardWeightStack = closingRewardWeight;
        uint128 amountLoanedStack = amountLoaned;

        // Then: 1 auction should be in progress in LendingPool
        // And: auctionInProgress should be set to true in specific tranche (Junior as first impacted)
        assertEq(pool.getAuctionsInProgress(), 1);
        assertEq(jrTranche.auctionInProgress(), true);

        // And : Liquidation incentives should have been added to openDebt of Account
        uint256 liquidationInitiatorReward = uint256(amountLoanedStack + 1) * initiatorRewardWeightStack / 100;
        liquidationInitiatorReward =
            liquidationInitiatorReward > maxInitiatorFee ? maxInitiatorFee : liquidationInitiatorReward;
        uint256 liquidationPenalty = (uint256(amountLoanedStack + 1) * penaltyWeightStack) / 100;
        uint256 closingReward = (uint256(amountLoanedStack + 1) * closingRewardWeightStack) / 100;
        closingReward = closingReward > maxClosingFee ? maxClosingFee : closingReward;

        // And: Returned amount should be equal to maxInitiatorFee
        //        assertEq(liquidationInitiatorReward_, liquidationInitiatorReward);
        //        assertEq(closingReward_, closingReward);

        assertEq(
            pool.getOpenPosition(address(proxyAccount)),
            (amountLoanedStack + 1) + liquidationInitiatorReward + liquidationPenalty + closingReward
        );
    }

    function testFuzz_Success_startLiquidation_OngoingAuctions(
        uint128 amountLoaned,
        uint8 initiatorRewardWeight,
        uint8 penaltyWeight,
        uint8 closingRewardWeight,
        uint80 maxInitiatorFee,
        uint80 maxClosingFee,
        uint16 auctionsInProgress
    ) public {
        // Given: Account has debt
        bytes3 emptyBytes4;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 150) * 100); // No overflow when debt is increased
        vm.assume(uint16(initiatorRewardWeight) + penaltyWeight + closingRewardWeight <= 11);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes4);
        vm.prank(users.creatorAddress);
        pool.setMaxLiquidationFees(maxInitiatorFee, maxClosingFee);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        //And: an auction is ongoing
        vm.assume(auctionsInProgress > 0);
        vm.assume(auctionsInProgress < type(uint16).max);
        pool.setAuctionsInProgress(auctionsInProgress);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator calls startLiquidation()
        vm.prank(address(proxyAccount));
        pool.startLiquidation(address(proxyAccount));

        // Then: auctionsInProgress should increase
        assertEq(pool.getAuctionsInProgress(), auctionsInProgress + 1);
        // and the most junior tranche should be locked
        assertTrue(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }
}
